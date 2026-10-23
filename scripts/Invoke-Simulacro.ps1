#Requires -Version 7.0
<#
.SYNOPSIS
    Simulacro de ransomware sobre los documentos FALSOS de la gestoría, con medición de tiempos.

.DESCRIPTION
    Fases:
      1. Copia: snapshot de cada share (antes de tocar nada).
      2. Antes: se descargan los documentos y se calcula su SHA-256 (línea base).
      3. Ataque: sobrescribe cada documento con texto aleatorio, lo renombra a .bloqueado,
         borra el original y deja un LEEME_RESCATE.txt de broma. Solo toca los documentos falsos.
      4. Detección: un bucle sondea los shares hasta ver todos los .bloqueado.
      5. Restauración: copia cada documento desde el snapshot y borra los .bloqueado y el LEEME.
      6. Verificación: vuelve a descargar todo y compara SHA-256 con la línea base.

    Todo se guarda en resultados/simulacro.json. Las imágenes se generan después con
    scripts/generar_imagenes.py a partir de ese fichero.

    Requiere Azure CLI y las variables de entorno AZURE_STORAGE_ACCOUNT y AZURE_STORAGE_KEY.
    La clave la pone el workflow en el momento; nunca se escribe en el repo.

.PARAMETER Resultados
    Ruta del JSON de salida.
#>
[CmdletBinding()]
param(
    [string]$Resultados = (Join-Path $PSScriptRoot '..' 'resultados' 'simulacro.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$shares     = @('contabilidad', 'laboral', 'direccion')
$vistaShare = 'contabilidad'
$trabajo    = Join-Path ([System.IO.Path]::GetTempPath()) ('simulacro-' + [guid]::NewGuid().ToString('N'))
$null       = New-Item -ItemType Directory -Force -Path $trabajo
$alfabeto   = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
$textoRescate = @(
    'TUS ARCHIVOS ESTÁN BLOQUEADOS (SIMULACRO).'
    'Esto es una prueba: los documentos son FALSOS y pertenecen a una gestoría ficticia.'
    'No hay nada que pagar. Restaurando desde la copia...'
) -join [Environment]::NewLine

# Llama a Azure CLI y para si falla. Los argumentos van tal cual a az.
function Invoke-Az {
    $salida = & az @args --only-show-errors
    if ($LASTEXITCODE -ne 0) { throw "az falló: $($args -join ' ')" }
    $salida
}

function Get-Inventario {
    param([string]$Share)
    Invoke-Az storage file list --share-name $Share --query '[].{nombre:name, tamanio:properties.contentLength}' -o json |
        ConvertFrom-Json
}

# Texto aleatorio de la misma longitud que el original (el "cifrado" del simulacro).
function Get-Texto {
    param([int]$Longitud)
    $sb = [System.Text.StringBuilder]::new()
    for ($i = 0; $i -lt [math]::Max(1, $Longitud); $i++) {
        $pos = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32($alfabeto.Length)
        [void]$sb.Append($alfabeto[$pos])
    }
    $sb.ToString()
}

$hashes  = @{}
$sw      = [System.Diagnostics.Stopwatch]::new()
$inicio  = Get-Date
$eventos = [System.Collections.Generic.List[object]]::new()

try {
    # 1. Copia: snapshot de cada share antes de tocar nada.
    $snapshots = @{}
    foreach ($share in $shares) {
        $snapshots[$share] = (Invoke-Az storage share snapshot --name $share --query snapshot -o tsv).Trim()
    }

    # 2. Antes: inventario y línea base (hash de cada documento original).
    $antes = @{}
    foreach ($share in $shares) {
        $antes[$share] = @(Get-Inventario -Share $share)
        $destino = Join-Path $trabajo 'antes' $share
        $null = New-Item -ItemType Directory -Force -Path $destino
        foreach ($f in $antes[$share]) {
            $local = Join-Path $destino $f.nombre
            Invoke-Az storage file download --share-name $share --path $f.nombre --dest $local | Out-Null
            $hashes["$share|$($f.nombre)"] = (Get-FileHash -Algorithm SHA256 -LiteralPath $local).Hash
        }
    }
    $totalArchivos = @($antes.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
    $vistaAntes    = @($antes[$vistaShare] | ForEach-Object { [pscustomobject]@{ nombre = $_.nombre; tamanio = $_.tamanio } })

    # 3. Ataque (cronometrado). Sobrescribe, renombra a .bloqueado y borra el original.
    $sw.Restart()
    foreach ($share in $shares) {
        $tmp = Join-Path $trabajo 'ruido' $share
        $null = New-Item -ItemType Directory -Force -Path $tmp
        foreach ($f in $antes[$share]) {
            $ruido = Join-Path $tmp $f.nombre
            Set-Content -LiteralPath $ruido -Value (Get-Texto -Longitud $f.tamanio) -NoNewline -Encoding utf8
            Invoke-Az storage file upload --share-name $share --source $ruido --path $f.nombre | Out-Null
            Invoke-Az storage file upload --share-name $share --source $ruido --path "$($f.nombre).bloqueado" | Out-Null
            Invoke-Az storage file delete --share-name $share --path $f.nombre | Out-Null
        }
        $rescate = Join-Path $tmp 'LEEME_RESCATE.txt'
        Set-Content -LiteralPath $rescate -Value $textoRescate -Encoding utf8
        Invoke-Az storage file upload --share-name $share --source $rescate --path 'LEEME_RESCATE.txt' | Out-Null
    }
    $sw.Stop()
    $tAtaque = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    $eventos.Add([pscustomobject]@{ fase = 'ataque'; inicio_s = 0; fin_s = $tAtaque })

    # 4. Detección: sondea los shares hasta ver todos los .bloqueado (máximo 10 minutos).
    $sw.Restart()
    $detectados = 0
    while ($true) {
        $detectados = 0
        foreach ($share in $shares) {
            $detectados += @(Get-Inventario -Share $share | Where-Object { $_.nombre -like '*.bloqueado' }).Count
        }
        if ($detectados -ge $totalArchivos -or $sw.Elapsed.TotalSeconds -gt 600) { break }
        Start-Sleep -Seconds 5
    }
    $sw.Stop()
    $tDeteccion = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    if ($detectados -lt $totalArchivos) { throw "Detección incompleta: $detectados de $totalArchivos" }
    $eventos.Add([pscustomobject]@{ fase = 'deteccion'; inicio_s = $tAtaque; fin_s = $tAtaque + $tDeteccion })
    $vistaDurante = @(Get-Inventario -Share $vistaShare | ForEach-Object { [pscustomobject]@{ nombre = $_.nombre; tamanio = $_.tamanio } })

    # 5. Restauración (cronometrada): copia desde el snapshot y limpia .bloqueado y LEEME.
    $sw.Restart()
    foreach ($share in $shares) {
        foreach ($f in $antes[$share]) {
            Invoke-Az storage file copy start --source-share $share --source-path $f.nombre `
                --source-snapshot $snapshots[$share] --destination-share $share --destination-path $f.nombre | Out-Null
        }
        foreach ($f in $antes[$share]) {
            $intentos = 0
            do {
                Start-Sleep -Seconds 2
                $estado = (Invoke-Az storage file show --share-name $share --path $f.nombre --query 'properties.copy.status' -o tsv).Trim()
                $intentos++
            } while ($estado -eq 'pending' -and $intentos -lt 60)
        }
        $sobrantes = @(Get-Inventario -Share $share | Where-Object { $_.nombre -like '*.bloqueado' -or $_.nombre -eq 'LEEME_RESCATE.txt' })
        foreach ($s in $sobrantes) {
            Invoke-Az storage file delete --share-name $share --path $s.nombre | Out-Null
        }
    }
    $sw.Stop()
    $tRestauracion = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    $eventos.Add([pscustomobject]@{ fase = 'restauracion'; inicio_s = $tAtaque + $tDeteccion; fin_s = $tAtaque + $tDeteccion + $tRestauracion })

    # 6. Verificación (cronometrada): descarga todo y compara hashes con la línea base.
    $sw.Restart()
    $identicos  = 0
    $diferentes = [System.Collections.Generic.List[string]]::new()
    foreach ($share in $shares) {
        $destino = Join-Path $trabajo 'despues' $share
        $null = New-Item -ItemType Directory -Force -Path $destino
        foreach ($f in $antes[$share]) {
            $local = Join-Path $destino $f.nombre
            Invoke-Az storage file download --share-name $share --path $f.nombre --dest $local | Out-Null
            $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $local).Hash
            if ($hash -eq $hashes["$share|$($f.nombre)"]) { $identicos++ } else { $diferentes.Add("$share/$($f.nombre)") }
        }
    }
    $sw.Stop()
    $tVerificacion = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    $inicioVerif   = $tAtaque + $tDeteccion + $tRestauracion
    $eventos.Add([pscustomobject]@{ fase = 'verificacion'; inicio_s = $inicioVerif; fin_s = $inicioVerif + $tVerificacion })
    $vistaDespues = @(Get-Inventario -Share $vistaShare | ForEach-Object { [pscustomobject]@{ nombre = $_.nombre; tamanio = $_.tamanio } })

    # Tiempo de recuperación: desde que se detecta el ataque hasta que la verificación acaba.
    $recuperacionSeg = $tDeteccion + $tRestauracion + $tVerificacion
    $resultado = if ($diferentes.Count -eq 0 -and $identicos -eq $totalArchivos) { 'OK' } else { 'FALLO' }

    $salida = [ordered]@{
        empresa              = 'Gestoría Hortensia Demo S.L.'
        fecha_inicio         = $inicio.ToString('o')
        resultado            = $resultado
        archivos             = $totalArchivos
        identicos            = $identicos
        diferentes           = $diferentes.Count
        lista_diferentes     = @($diferentes)
        snapshots            = $snapshots
        fases_segundos       = [ordered]@{
            ataque       = $tAtaque
            deteccion    = $tDeteccion
            restauracion = $tRestauracion
            verificacion = $tVerificacion
        }
        recuperacion_minutos = [math]::Round($recuperacionSeg / 60, 2)
        linea_de_tiempo      = @($eventos)
        vista                = [ordered]@{
            carpeta = $vistaShare
            antes   = $vistaAntes
            durante = $vistaDurante
            despues = $vistaDespues
        }
    }

    $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Resultados)
    $salida | ConvertTo-Json -Depth 8 | Set-Content -Path $Resultados -Encoding utf8
    Write-Output "Resultado: $resultado. Recuperación: $($salida.recuperacion_minutos) min. Idénticos: $identicos/$totalArchivos."
    if ($resultado -ne 'OK') { exit 1 }
}
finally {
    Remove-Item -LiteralPath $trabajo -Recurse -Force -ErrorAction SilentlyContinue
}
