using module ProxyPlaceholderResolver
using module Logger

<#
    .\RemoteAdminTools.ps1 -InvokeApi @{
        Path   = @("Network", "Wake Clients (WoL)")
        Memory = @{
            StationSelector = @{
                selection = @("AI-086")
            }
        }
    }
    .\RemoteAdminTools.ps1 -InvokeApi @{ 
        Path = @("Soundboard", "Restart (if hotkey recognition fails)", "Specific stations")
        Memory = @{ StationSelector = @{ selection = @("AI-086") } }
    }
#>
[CmdletBinding(DefaultParameterSetName = 'Interactive')]
param(
    [Parameter(ParameterSetName = 'Interactive')]
    [switch]$ExecutedByShortcut,

    [Parameter(Mandatory = $true, ParameterSetName = 'ApiMode', Position = 0)]
    [object]$InvokeApi
)

try {
    $IsApiMode = $PSCmdlet.ParameterSetName -eq 'ApiMode'
    if ($IsApiMode) {
        if ($null -eq $InvokeApi.Path -or $InvokeApi.Path -isnot [array] -or $InvokeApi.Path.Count -eq 0) {
            Write-Error "ApiMode requires 'Path' to be a non-empty string array"
            exit 1
        }
        if ($null -ne $InvokeApi.Memory -and $InvokeApi.Memory -isnot [hashtable]) {
            Write-Error "InvokeApi.Memory must be a hashtable if provided"
            exit 1
        }
        $Memory = if ($null -ne $InvokeApi.Memory) { $InvokeApi.Memory } else { @{} }
    } else {
        Start-Sleep -Seconds 1
        if (-not $ExecutedByShortcut) {
            Import-Module CreatePsStartFileLink
            CreatePsStartFileLink -TargetScript $MyInvocation.MyCommand.Definition -PS7
            Start-Sleep -Seconds 1
        }
        $Memory = @{}
    }

    $Context = [pscustomobject]@{}
    $Resolver = [ProxyPlaceholderResolver]::new()
    $Context | Add-Member -NotePropertyName 'Resolver' -NotePropertyValue $Resolver
    $callbacks = & 'C:\ProgramData\PowerShell\PlaceholderCallbacks.ps1'
    $Resolver.RegisterCallbacks($callbacks)
    $CfgPsd = Import-PowerShellDataFile "C:\ProgramData\PowerShell\RemoteAdminTools\Config.psd1"
    $Resolver.RegisterSource('CONFIG', $CfgPsd)
    $Config = $Resolver.CreateProxy('CONFIG', $Context, @('AsHashtable','GetKeys'))
    $Context | Add-Member -NotePropertyName 'Config' -NotePropertyValue $Config
    $RegPsd = Import-PowerShellDataFile $Config.PsRegistryConfig.target
    $Resolver.RegisterSource('REGISTRY', $RegPsd)
    $Registry = $Resolver.CreateProxy('REGISTRY', $Context, @('AsHashtable','Filter','GetKeys','GetRecords'))
    $Context | Add-Member -NotePropertyName 'Registry' -NotePropertyValue $Registry
    $Context | Add-Member -NotePropertyName 'Memory' -NotePropertyValue $Memory
    $Logger = [Logger]::new(@{
        LogInfo         = $Config.LogProgress
        LogErrors       = $Config.LogErrors
        UseConsole      = if ($IsApiMode) { $true } else { $false }
        # CatchOutputs    = if ($IsApiMode) { $false } else { $true }
        CatchOutputs    = $false
    })
    $Context | Add-Member -NotePropertyName 'Logger' -NotePropertyValue $Logger -Force
    $Context.Logger.Info("--- 🖥️ $($env:COMPUTERNAME) - Running as: 👤 $(whoami) ---")
    $Node = & (Join-Path $Config.ProgramData $Config.ProgramNodes)
    if ($IsApiMode) {
        Import-Module ExecuteApiRequest
        ExecuteApiRequest -Node $Node -Path $InvokeApi.Path -Context $Context
    } else {
        Import-Module MultiDimensionalMenu
        ShowMenu -Node $Node -Context $Context -MenuName $Config.MenuName -DisplayIndex $Config.DisplayIndex
    }
} catch {

    # ──────────────────────────────────────────────────────────────
    # Phase 0 – Minimal Fallback-Logger und Banner
    # ──────────────────────────────────────────────────────────────

    $fallbackLogPath = "C:\ProgramData\PowerShell\RemoteAdminTools\Bootstrap.log"
    $global:EnableDebugLogging = $false

    function Write-FallbackLog {
        param($msg, [switch]$warning, [switch]$error, [switch]$force)
        $force = $error -or $force
        if (-not $EnableDebugLogging -and -not $force) { return }
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $line = "[$timestamp] $msg"
        $line | Out-File -FilePath $fallbackLogPath -Encoding UTF8 -Append -Force
        if ($error) { Write-Error $msg }
        elseif ($warning) { Write-Warning $msg }
        else { Write-Host $msg }
    }

    function updateBanner {
    return @"


╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║       Remote Admin Tools are not yet installed / uptodate    ║
║      Remote Admin Framework installation / update started.   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

"@
    }

    function completeBanner {
    return @"


╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     Remote Admin Framework installation / update complete    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

"@
    }
    function offlineBanner {
    return @"


╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║           Remote Admin Tools are not yet installed           ║
║          and the repositoy is currently unavailable.         ║
║    Installation cannot proceed. Please contact IT support.   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

"@
    }

    # ──────────────────────────────────────────────────────────────
    # Bootstraping/Fixing
    # ──────────────────────────────────────────────────────────────

    # Phase 1 – Bootstrap/Rollout
    $bootstrapRoot = "\\topcall.inc\shares\PowerShell_Framework$"

    if (-not (Test-Path $bootstrapRoot)) {
        Clear-Host
        offlineBanner
        Write-FallbackLog "Fatal error while main program initialization`:"
        Write-FallbackLog $_.Exception.Message
        Write-FallbackLog "Bootstrap-Root not reachable: $bootstrapRoot" -error
        if ($Host.Name -eq 'ConsoleHost') { Pause }
        exit 1
    } else {
        Clear-Host
        updateBanner
        Write-FallbackLog "Installation in progress..." -Force
    }

    # 2 Essencial callbacks to resolve PsRegistryConfig
    $callbacks = @{
        'REPOSITORY' = {
            "\\topcall.inc\shares\PowerShell_Framework$"
        }
        'PROGRAMDATABASEDIR' = {
            "C:\ProgramData\PowerShell"
        }
        'MODULESBASE' = {
            $globalPath = "C:\Program Files\PowerShell\Modules"
            $userPath   = "$env:USERPROFILE\Documents\PowerShell\Modules"

            if (Test-Path $globalPath) {
                try {
                    $testFile = Join-Path $globalPath ".test"
                    "test" | Out-File $testFile -Force -ErrorAction Stop
                    Remove-Item $testFile -Force -ErrorAction Stop
                    return $globalPath
                } catch {
                    return $userPath
                }
            } else {
                return $userPath
            }
        }
    }

    # Phase 3 – Loading PsRegistryConfig
    $RegPsdSource = Join-Path $bootstrapRoot "ConfigFiles\PsRegistryConfig.psd1"
    $regPsdContent = Get-Content $RegPsdSource -Raw
    Write-FallbackLog "PsRegistryConfig loaded from source"

    # Resolve hardcoded Callbacks (Search & Replace)
    foreach ($key in $callbacks.Keys) {
        $placeholder = "{{$key}}"
        $value = $callbacks[$key].Invoke()
        $regPsdContent = $regPsdContent -replace [regex]::Escape($placeholder), $value
    }
    Write-FallbackLog "PsRegistryConfig resolved"

    # Loading PsRegistryConfig as Hashtable
    $RegPsd = [scriptblock]::Create($regPsdContent).InvokeReturnAsIs()
    Write-FallbackLog "Content of PsRegistryConfig converted to hashtable"

    # Phase 4 – Loading other essencial dependencies
    # Loading ProxyPlaceholderResolver
    Invoke-Expression (Get-Content $RegPsd.ProxyPlaceholderResolver.source -Raw)
    $Resolver = [ProxyPlaceholderResolver]::new()
    Write-FallbackLog "ProxyPlaceholderResolver loaded from source"

    $Context = [pscustomobject]@{}
    $Context | Add-Member -NotePropertyName 'Resolver' -NotePropertyValue $Resolver
    Write-FallbackLog "ProxyPlaceholderResolver registered in Context"

    # Register PlaceholderCallbacks in ProxyPlaceholderResolver
    $callbacks = & $RegPsd.PlaceholderCallbacks.source
    $Resolver.RegisterCallbacks($callbacks)
    Write-FallbackLog "PlaceholderCallbacks loaded from source"

    # Loading RemoteAdminConfig
    $CfgPsd = Import-PowerShellDataFile $RegPsd.RemoteAdminConfig.source
    Write-FallbackLog "RemoteAdminConfig loaded from source"

    # Register RemoteAdminConfig
    $Resolver.RegisterSource('CONFIG', $CfgPsd)
    $Config = $Resolver.CreateProxy('CONFIG', $Context, $null)
    $Context | Add-Member -NotePropertyName 'Config' -NotePropertyValue $Config
    Write-FallbackLog "RemoteAdminConfig registered in ProxyPlaceholderResolver and Context"

    # Register PsRegistryConfig
    $Resolver.RegisterSource('REGISTRY', $RegPsd)
    $Registry = $Resolver.CreateProxy('REGISTRY', $Context, @('AsHashtable'))
    $Context | Add-Member -NotePropertyName 'Registry' -NotePropertyValue $Registry
    Write-FallbackLog "PsRegistryConfig registered in ProxyPlaceholderResolver and Context"

    # Phase 5 – Install all essencial dependencies
    $dependencies = @(
        'ProxyPlaceholderResolver',
        'PlaceholderCallbacks',
        'PsRegistryConfig',
        'RemoteAdminConfig',
        'RemoteAdminData',
        'ExecuteApiRequest',
        'MultiDimensionalMenu',
        'StationSelector',
        'ParallelRemotingJobs',
        'CreatePsStartFileLink',
        'Logger'
    )
    $deployments = $Registry.AsHashtable($dependencies)
    Import-Module $RegPsd.UpdateDeployment.source -Force
    [hashtable[]]$jobs = CreateJob -Deployments $deployments
    # UpdateDeployment -Jobs $jobs -EnableDebugLogging:$EnableDebugLogging
    Write-FallbackLog "UpdateDeployment complete"
    completeBanner

    # Application restart 
    Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy Bypass",  "-File `"$PSCommandPath`""
    exit 1

} finally {
    if ($Context -and $Context.Logger) {
        $Context.Logger.Info("Remote Admin Framework terminated")
        $Context.Logger.Info("-------------------------------------------------------")
    } else {
        Write-FallbackLog "Remote Admin Framework terminated"
        Write-FallbackLog "-------------------------------------------------------"
    }
}