using module CredentialManager

# Konfiguration
$csv = '\\topcall.inc\Scripts\PowerShell\ConfigFiles\AgentsStations.csv'
$delimiter = ';'

# Dateipfade
$CredentialFile = Join-Path %USERPROFILE% "AppData\Local\CredentialManager\DomainClients.xml"
$deployScriptPath = "\\dc-1\NAS\Scripts\PowerShell\UpdateDeployment\deployUpdateDeployment.ps1"
$runScriptPath    = "\\dc-1\NAS\Scripts\PowerShell\UpdateDeployment\runUpdateDeployment.ps1"

# Authentifizierungsdaten entschluesseln
$Key = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
$credential = CredentialManager -Key $Key -Path $CredentialFile

# 1. deployUpdateDeployment.ps1 lesen & in ScriptBlock umwandeln
$deployCode = Get-Content $deployScriptPath -Raw
$deployBlock = [ScriptBlock]::Create($deployCode)

# 2. runUpdateDeployment.ps1 lesen & in ScriptBlock umwandeln
$runCode = Get-Content $runScriptPath -Raw
$runBlock = [ScriptBlock]::Create($runCode)

# CSV einlesen
$stations = Import-Csv -Path $csv -Delimiter $delimiter -Header 'hostname', 'ip'

foreach ($station in $stations) {
    $ComputerName = $station.ip.Trim()
    Write-Host "🚀 Processing $ComputerName..."
    try {
        # === 1. Deployment vorbereiten ===
        Invoke-Command -ComputerName $ComputerName -Credential $credential -ScriptBlock $deployBlock
        Write-Host "✅ Deployment script deployed on $ComputerName"

        # === 2. Deployment ausführen ===
        Invoke-Command -ComputerName $ComputerName -Credential $credential -ScriptBlock $runBlock
        Write-Host "🎉 Deployment executed on $ComputerName"
    } catch {
        Write-Warning "⚠️ Error on $ComputerName`: $($_.Exception.Message)"
    }
}
