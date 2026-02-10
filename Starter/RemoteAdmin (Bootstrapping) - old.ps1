param(
    [string]$LoggingPhase = "",
    [switch]$SkipUpdateCheck,
    [bool]$global:EnableDebugLogging = $true,
    [string]$logPath = "C:\ProgramData\PowerShell\RemoteAdminTools\Progress.log",
    [hashtable]$PsRegistryConfig = @{
        source = "\\dc-1\NAS\Scripts\PowerShell\ConfigFiles\PsRegistryConfig.psd1"
        target = "C:\ProgramData\PowerShell\PsRegistryConfig.psd1"
    }
)

function Banner {
    return @"


╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║           Remote Admin Tools are not yet installed           ║
║  and the domain controller 'DC-1' is currently unavailable.  ║
║    Installation cannot proceed. Please contact IT support.   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"@
}
function Write-Log($msg, [switch]$warning, [switch]$error, [switch]$force) {
    $force = if($error){$error}else{$force}
    if (-not $EnableDebugLogging -and -not $force) { return }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $msg"
    $line | Out-File -FilePath $logPath -Encoding UTF8 -Append
    if($error){
        Write-Error $line
    }elseif($warning){
        Write-Warning $line
    }else{
        Write-Host $line
    }
}
  
if(-not $LoggingPhase) {
    Write-Log "🖥️ $env:COMPUTERNAME - Running as: 👤 $(whoami)" -force
    Write-Log "────────────────────────────────────────────" -force
}

if (-not (Test-Path $PsRegistryConfig.source)) {
    $SkipUpdateCheck = $true
}

if (-not $SkipUpdateCheck) {
    $PsRegistry = "\\dc-1\NAS\Scripts\PowerShell\PsRegistry\PsRegistry.psm1"
    $PsRegistrySourceCode = Get-Content $PsRegistry -Raw
    Invoke-Expression $PsRegistrySourceCode
    $Registry = [PsRegistry]::new($PsRegistryConfig)

    $UpdateDeploymentStatus = & {
        Write-Log "🔄 Update check for UpdateDeployment in progress..."
        Invoke-Command -ScriptBlock ([ScriptBlock]::Create((Get-Content $Registry.BootstrapUpdateDeployment.source -Raw)))
    }

    if ($UpdateDeploymentStatus -gt 0) {
        if ($UpdateDeploymentStatus -eq 1) {
            Write-Log "✅ UpdateDeployment has already been up to date"
        }elseif ($UpdateDeploymentStatus -eq 2) {
            Write-Log "✅ UpdateDeployment has been installed"
        }elseif($UpdateDeploymentStatus -eq 3) {
            Write-Log "✅ UpdateDeployment has been updated"
        }
        Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy Bypass", "-File `"$PSCommandPath`"", "-LoggingPhase continue"
        exit
    }else{
        Write-Log "⚠️ UpdateDeployment failed: $($UpdateDeploymentStatus.Exception.Message)" -error
    }

    if ($UpdateDeploymentStatus -eq 1) {
        Write-Log "ℹ️ UpdateDeployment is already up to date"
        Write-Log "🔄 Update check for Remote Admin Tools in progress..."
        try {
            $deployments = $Registry.GetRecords(@(
                'PsRegistry',
                'PsRegistryConfig',
                'MultiDimensionalMenu',
                'RemoteAdminConfig',
                'RemoteAdminData',
                'StationSelector',
                'ParallelRemoting',
                'RemoteModuleDeployment'
            ))
            Write-Host $($deployments.Count)            
            Import-Module "UpdateDeployment"
            $Jobs = CreateJobs -Deployments $deployments
            UpdateDeployment -Jobs (,(CreateJob -Deployments $deployments)) -EnableDebugLogging:$EnableDebugLogging
            Write-Log "✅ Updating Remote Admin Tools complete" -force
        } catch {
            Write-Log "⚠️ UpdateDeployment failed: $($_.Exception.Message)" -error
            Pause
        }
        Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy Bypass", "-File `"$PSCommandPath`"", "-SkipUpdateCheck", "-LoggingPhase finalize"
        exit
    }
}

if ($LoggingPhase -eq "finalize") {
    Write-Log "────────────────────────────────────────────" -force
    Write-Log "✅ All update checks complete`n" -force
}

if (-not (Test-Path $PsRegistryConfig.target)) {
    $Banner = Banner
    Write-Log $Banner -force
    Clear-Host
    Write-Host $Banner -ForegroundColor Cyan
    Pause
}

try {
    # ──────────────── Main Program Start ────────────────
    $Config    = Import-PowerShellDataFile "C:\ProgramData\PowerShell\RemoteAdminTools\RemoteAdminConfig.psd1"
    $Data = & "C:\ProgramData\PowerShell\RemoteAdminTools\RemoteAdminData.ps1" -Config $Config -PsRegistryConfig $PsRegistryConfig
    Import-Module "MultiDimensionalMenu"
    Show-Menu -MenuName $Config.MenuName -Node $Data -DisplayIndex $Config.DisplayIndex
} catch {
    Write-Log "⚠️ Fatal error: $($_)" -error
    exit
}


<#
$Config = Import-PowerShellDataFile "\\dc-1\NAS\Scripts\PowerShell\ConfigFiles\RemoteAdminConfig.psd1"
$Config.CredentialKey = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
$PsRegistryConfig = @{
    source = "\\dc-1\NAS\Scripts\PowerShell\ConfigFiles\PsRegistryConfig.psd1"
    target = "C:\ProgramData\PowerShell\PsRegistryConfig.psd1"
}
$Data = & "\\dc-1\NAS\Scripts\PowerShell\ConfigFiles\RemoteAdminData.ps1" -Config $Config -PsRegistryConfig $PsRegistryConfig

Import-Module "MultiDimensionalMenu"
Show-Menu -MenuName $Config.MenuName -Node $Data -DisplayIndex $Config.DisplayIndex
#>