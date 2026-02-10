param(
    [hashtable]$PsRegistryConfig = @{
        source = "\\dc-1\NAS\Scripts\PowerShell\ConfigFiles\PsRegistryConfig.psd1"
        target = "C:\ProgramData\PowerShell\PsRegistryConfig.psd1"
    },
    [string]$ComputerName = "192.168.1.8",
    [bool]$executeRemote = $true
)

# Initialisieren von PsRegistry
$PsRegistryPath = "\\dc-1\NAS\Scripts\PowerShell\PsRegistry\PsRegistry.psm1"
$PsRegistrySourceCode = Get-Content $PsRegistryPath -Raw
Invoke-Expression $PsRegistrySourceCode

$Registry = [PsRegistry]::new($PsRegistryConfig)
$Config   = Import-PowerShellDataFile $Registry.RemoteAdminConfig.source
$Context = @{ Config = $Config; Registry = $Registry }

# Modul-ScriptBlock abrufen
Import-Module RemoteModuleDeployment -Force
$scriptBlock = TestRemoteModuleDeployment -ModuleKeys @(
    'UpdateDeployment', 'UserProfileUtilities', 'RemoteDesktopProcess'
)

# Sicherstellen, dass der Rückgabewert ein ScriptBlock ist
if ($scriptBlock -is [scriptblock]) {
    Write-Host "✅ ScriptBlock returned successfully. Executing..." -ForegroundColor Green
}elseif ($scriptBlock -is [string]) {
    Write-Warning "⚠ Returned value was a string, attempting to convert to ScriptBlock..."
    $scriptBlock = [scriptblock]::Create($scriptBlock)
}else {
    throw "❌ Invalid return type: $($scriptBlock.GetType().FullName)"
}

if(-not $executeRemote){
    & $scriptBlock $Context
}else{
    $Key = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
    $CredentialFile = Join-Path $env:USERPROFILE "AppData\Local\PowerShell\CredentialManager\DomainClients.xml"
    Import-Module CredentialManager
    $Credential = CredentialManager -Key $Key -Path $CredentialFile
    $result = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock $scriptBlock -ArgumentList $Context
    Import-Module Debugger
    Inspect $result
}