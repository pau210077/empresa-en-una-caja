#Requires -Version 7.0
<#
.SYNOPSIS
    Genera documentos FALSOS de una gestoría ficticia (facturas, nóminas, contratos, informes).

.DESCRIPTION
    Todo es inventado: nombres, empresas clientes con el sufijo DEMO y cantidades.
    Con la misma semilla siempre sale el mismo conjunto, así que el resultado es reproducible.
    Crea una carpeta por departamento dentro de -Destino.

.PARAMETER Destino
    Carpeta donde se crean las subcarpetas contabilidad, laboral y direccion.

.PARAMETER Semilla
    Semilla del generador aleatorio para que los documentos sean siempre iguales.
#>
[CmdletBinding()]
param(
    [string]$Destino = (Join-Path $PSScriptRoot '..' 'staging'),
    [int]$Semilla = 2026
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$empresa = 'Gestoría Hortensia Demo S.L.'
$rnd     = [System.Random]::new($Semilla)

$nombres   = @('Ana', 'Marc', 'Laura', 'Jordi', 'Marta', 'Pol', 'Clara', 'Joan', 'Irene', 'Oriol', 'Nuria', 'Xavi')
$apellidos = @('Ruiz', 'Puig', 'Vidal', 'Soler', 'Ferrer', 'Roca', 'Serra', 'Pons', 'Masip', 'Coll')
$clientes  = @('Transportes Vega DEMO S.L.', 'Panadería Lirio DEMO S.L.', 'Talleres Nébula DEMO S.L.',
               'Clínica Dental Alba DEMO', 'Reformas Cairo DEMO S.L.', 'Academia Brisa DEMO S.L.',
               'Distribuciones Tramo DEMO S.L.', 'Floristería Acacia DEMO')
$conceptos = @('Honorarios trimestrales', 'Asesoría fiscal', 'Gestión de nóminas', 'Declaración de IVA',
               'Alta en Seguridad Social', 'Revisión de cuentas anuales', 'Consultoría laboral')

function Get-Elegir {
    param([string[]]$Lista)
    $Lista[$rnd.Next(0, $Lista.Count)]
}

function Get-Importe {
    param([int]$Min, [int]$Max)
    [math]::Round($rnd.Next($Min * 100, $Max * 100) / 100, 2)
}

$carpetaContab = Join-Path $Destino 'contabilidad'
$carpetaLabor  = Join-Path $Destino 'laboral'
$carpetaDirec  = Join-Path $Destino 'direccion'
$null = New-Item -ItemType Directory -Force -Path $carpetaContab, $carpetaLabor, $carpetaDirec

# Contabilidad: 25 facturas en CSV.
for ($n = 1; $n -le 25; $n++) {
    $cliente = Get-Elegir -Lista $clientes
    $base    = Get-Importe -Min 120 -Max 4800
    $iva     = [math]::Round($base * 0.21, 2)
    $fecha   = [datetime]::new(2026, 1, 1).AddDays($rnd.Next(0, 300)).ToString('yyyy-MM-dd')
    $concepto = Get-Elegir -Lista $conceptos
    $lineas  = @(
        'numero;fecha;cliente;concepto;base_imponible;iva_21;total'
        ('FAC-2026-{0:0000};{1};{2};{3};{4};{5};{6}' -f $n, $fecha, $cliente, $concepto, $base, $iva, ($base + $iva))
    )
    Set-Content -Path (Join-Path $carpetaContab ('FAC-2026-{0:0000}.csv' -f $n)) -Value $lineas -Encoding utf8
}

# Laboral: 12 nóminas (3 meses x 4 empleados) y 6 contratos de trabajo.
$empleados = 1..4 | ForEach-Object { '{0} {1}' -f (Get-Elegir -Lista $nombres), (Get-Elegir -Lista $apellidos) }
foreach ($mes in 1..3) {
    foreach ($emp in $empleados) {
        $bruto = Get-Importe -Min 1400 -Max 2600
        $seg   = [math]::Round($bruto * 0.0648, 2)
        $neto  = [math]::Round($bruto - $seg - ($bruto * 0.12), 2)
        $texto = @(
            'NÓMINA (DOCUMENTO DE PRUEBA)'
            "Empresa: $empresa"
            "Trabajador: $emp"
            ('Periodo: {0:00}/2026' -f $mes)
            "Salario bruto: $bruto EUR"
            "Cotización SS (aprox.): $seg EUR"
            "Líquido a percibir: $neto EUR"
        )
        $nombreFichero = 'NOM-2026-{0:00}-{1}.txt' -f $mes, ($emp -replace ' ', '_')
        Set-Content -Path (Join-Path $carpetaLabor $nombreFichero) -Value $texto -Encoding utf8
    }
}
for ($n = 1; $n -le 6; $n++) {
    $persona = '{0} {1}' -f (Get-Elegir -Lista $nombres), (Get-Elegir -Lista $apellidos)
    $texto = @(
        'CONTRATO DE TRABAJO (DOCUMENTO DE PRUEBA)'
        "Empresa: $empresa"
        "Trabajador: $persona"
        'Jornada: completa, 40 horas semanales'
        'Puesto: Administrativo/a'
        ('Fecha de inicio: 2026-{0:00}-01' -f $rnd.Next(1, 10))
    )
    Set-Content -Path (Join-Path $carpetaLabor ('CONTRATO-EMP-{0:000}.txt' -f $n)) -Value $texto -Encoding utf8
}

# Dirección: 4 informes trimestrales y 10 contratos con clientes.
foreach ($q in 1..4) {
    $texto = @(
        "INFORME TRIMESTRAL Q$q 2026 (DOCUMENTO DE PRUEBA)"
        "Empresa: $empresa"
        ('Facturación del trimestre: {0} EUR' -f (Get-Importe -Min 25000 -Max 90000))
        ('Clientes activos: {0}' -f $rnd.Next(30, 60))
        ('Incidencias abiertas: {0}' -f $rnd.Next(0, 5))
    )
    Set-Content -Path (Join-Path $carpetaDirec ('INFORME-Q{0}-2026.txt' -f $q)) -Value $texto -Encoding utf8
}
for ($n = 1; $n -le 10; $n++) {
    $cliente = Get-Elegir -Lista $clientes
    $texto = @(
        'CONTRATO DE SERVICIOS CON CLIENTE (DOCUMENTO DE PRUEBA)'
        "Empresa: $empresa"
        "Cliente: $cliente"
        ('Cuota mensual: {0} EUR' -f (Get-Importe -Min 90 -Max 650))
        'Duración: 12 meses, renovable tácitamente'
    )
    Set-Content -Path (Join-Path $carpetaDirec ('CONTRATO-CLI-{0:000}.txt' -f $n)) -Value $texto -Encoding utf8
}

$total = (Get-ChildItem -Path $Destino -Recurse -File).Count
Write-Output "Documentos falsos generados: $total en $Destino"
