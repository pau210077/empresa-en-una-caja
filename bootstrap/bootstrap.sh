#!/usr/bin/env bash
# Se ejecuta UNA vez en Azure Cloud Shell (Bash). Hace tres cosas:
#   1. Crea el almacenamiento donde Terraform guarda su estado.
#   2. Crea la identidad que usa GitHub Actions (OIDC: sin contraseñas ni secretos).
#   3. Imprime las variables exactas que hay que poner en GitHub.
#
# Uso:  bash bootstrap.sh
set -euo pipefail

REPO="pau210077/empresa-en-una-caja"
UBICACION="spaincentral"
APP="gh-empresa-en-una-caja"
RG_ESTADO="rg-tfstate-ehc"
CONTENEDOR="tfstate"
SUFIJO="$(tr -dc 'a-z0-9' </dev/urandom | head -c 6)"
SA_ESTADO="sttfstate${SUFIJO}"
FICHERO_SALIDA="$HOME/empresa-caja-variables.txt"

read -rp "Email para alertas y presupuesto: " EMAIL_ALERTAS
if [[ ! "$EMAIL_ALERTAS" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
  echo "Email no válido." >&2
  exit 1
fi

SUB="$(az account show --query id -o tsv)"
TENANT="$(az account show --query tenantId -o tsv)"
echo "Suscripción: $SUB"

# 1. Backend de Terraform (estado remoto en una cuenta de almacenamiento propia).
echo "Creando almacenamiento de estado..."
az group create -n "$RG_ESTADO" -l "$UBICACION" -o none
az storage account create -n "$SA_ESTADO" -g "$RG_ESTADO" -l "$UBICACION" \
  --sku Standard_LRS --min-tls-version TLS1_2 --allow-blob-public-access false -o none
az storage container create -n "$CONTENEDOR" --account-name "$SA_ESTADO" -o none

# 2. Identidad para GitHub Actions con OIDC.
echo "Creando identidad para GitHub..."
APP_ID="$(az ad app create --display-name "$APP" --query appId -o tsv)"
az ad sp create --id "$APP_ID" -o none
SP_OID="$(az ad sp show --id "$APP_ID" --query id -o tsv)"
sleep 20  # Azure tarda un poco en propagar la identidad nueva.

# Confianza: solo los workflows de la rama main de este repo pueden pedir token.
az ad app federated-credential create --id "$APP_ID" --parameters "{
  \"name\": \"github-main\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:${REPO}:ref:refs/heads/main\",
  \"audiences\": [\"api://AzureADTokenExchange\"]
}" -o none

# Permisos de Azure. Owner en la suscripción es lo más simple para este proyecto de prueba
# (Terraform crea el grupo de recursos, las políticas y las asignaciones RBAC).
# En una empresa real se acotaría al grupo de recursos y a los roles justos.
az role assignment create --assignee-object-id "$SP_OID" --assignee-principal-type ServicePrincipal \
  --role Owner --scope "/subscriptions/$SUB" -o none

SA_ID="$(az storage account show -n "$SA_ESTADO" -g "$RG_ESTADO" --query id -o tsv)"
az role assignment create --assignee-object-id "$SP_OID" --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" --scope "$SA_ID" -o none

# Permisos de Microsoft Graph para crear usuarios y grupos de prueba en Entra ID.
# 741f803b... = User.ReadWrite.All   62a82d76... = Group.ReadWrite.All
az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 \
  --api-permissions 741f803b-c850-494e-b5df-cde7c675a1ca=Role 62a82d76-70ea-41e2-9197-370581804d09=Role
if ! az ad app permission admin-consent --id "$APP_ID" -o none 2>/dev/null; then
  echo "AVISO: no he podido dar el consentimiento de administrador automáticamente."
  echo "       Hazlo a mano: Entra ID > Registros de aplicaciones > $APP > Permisos de API >"
  echo "       Conceder consentimiento de administrador."
fi

# 3. Lo que hay que poner en GitHub.
SALIDA="$(cat <<EOF
AZURE_CLIENT_ID        = $APP_ID
AZURE_TENANT_ID        = $TENANT
AZURE_SUBSCRIPTION_ID  = $SUB
TFSTATE_RG             = $RG_ESTADO
TFSTATE_SA             = $SA_ESTADO
TFSTATE_CONTAINER      = $CONTENEDOR
ALERT_EMAIL            = $EMAIL_ALERTAS
EOF
)"
printf '%s\n' "$SALIDA" > "$FICHERO_SALIDA"

echo
echo "Listo. Pon estas VARIABLES en GitHub (Settings > Secrets and variables > Actions > Variables):"
echo
echo "$SALIDA"
echo
echo "Estas mismas líneas están guardadas en $FICHERO_SALIDA"

# Si el gh de Cloud Shell está logueado, las pone él directamente.
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  echo "Configurando variables con gh..."
  while IFS='=' read -r clave valor; do
    clave="$(echo "$clave" | xargs)"
    valor="$(echo "$valor" | xargs)"
    gh variable set "$clave" --repo "$REPO" --body "$valor"
  done <<< "$SALIDA"
  echo "Variables configuradas en $REPO."
fi

echo
echo "Siguiente paso: en GitHub, pestaña Actions > '1 · Desplegar' > Run workflow."
echo "Si el primer despliegue falla por permisos, espera 5 minutos (Azure tarda en propagarlos) y relánzalo."
