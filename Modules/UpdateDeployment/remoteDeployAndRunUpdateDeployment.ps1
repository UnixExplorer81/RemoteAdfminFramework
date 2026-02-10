using module "CredentialManager"
using module "UserProfileUtilities"

# Konfiguration
$csv = 'E:\NAS\Documents\CSV Lists\Computers_all.csv'
$delimiter = ';'
$CredentialFileRelative = "AppData\Local\CredentialManager\credential.xml"

# Dateipfade
$deployScriptPath = "\\dc-1\NAS\Scripts\PowerShell\UpdateDeployment\deployUpdateDeployment.ps1"
$runScriptPath    = "\\dc-1\NAS\Scripts\PowerShell\UpdateDeployment\runUpdateDeployment.ps1"

# CSV einlesen
$stations = Import-Csv -Path $csv -Delimiter $delimiter -Header 'hostname', 'ip'

# Profilpfad des Benutzers mit laufendem Explorer-Prozess ermitteln
$profilePath = Get-UserProfilePath

if (-not $profilePath) {
    Write-Warning "❌ Could not determine profile path on $ComputerName"
    continue
}

$credentialPath = Join-Path $profilePath $CredentialFileRelative
$credential = getCredential -Path $credentialPath

foreach ($station in $stations) {
    $ComputerName = $station.ip.Trim()
    Write-Host "🚀 Processing $ComputerName..."

    # 1. deployUpdateDeployment.ps1 lesen & in ScriptBlock umwandeln
    $deployCode = Get-Content $deployScriptPath -Raw
    $deployBlock = [ScriptBlock]::Create($deployCode)

    # 2. runUpdateDeployment.ps1 lesen & in ScriptBlock umwandeln
    $runCode = Get-Content $runScriptPath -Raw
    $runBlock = [ScriptBlock]::Create($runCode)

    try {
        # === 1. Deployment vorbereiten ===
        Invoke-Command -ComputerName $ComputerName -Credential $credential -ScriptBlock $deployBlock
        Write-Host "✅ Deployment script deployed on $ComputerName"

        # === 2. Deployment ausführen ===
        Invoke-Command -ComputerName $ComputerName -Credential $credential -ScriptBlock $runBlock
        Write-Host "🎉 Deployment executed on $ComputerName"
    }
    catch {
        Write-Warning "⚠️ Error on $ComputerName`: $($_.Exception.Message)"
    }
}
