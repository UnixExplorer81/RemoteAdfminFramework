using module ProxyPlaceholderResolver
using module CapabilityProvider
Using Module Debugger
using module Logger

# API call examples
<#
    .\PsRemoteAdminFramework.ps1 -InvokeApi @{
        Path   = @("GPOs", "Task Scheduler", "Wake All Clients")
    }
    .\PsRemoteAdminFramework.ps1 -InvokeApi @{
        Path   = @("GPOs", "Wake up Clients", "Specific Clients")
        Memory = @{
            StationSelector = @{
                selection = @("PC-001", "PC-002", "PC-003")
            }
        }
    }
#>
[CmdletBinding(DefaultParameterSetName = 'Interactive')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'ApiMode', Position = 0)]
    [object]$InvokeApi,

    [Parameter(ParameterSetName = 'Interactive')]
    [switch]$ExecutedByShortcut,
    [switch]$SkipUpdateCheck,
    [bool]$EnableDebugLogging = $true,

    [string]$BootstrapRoot = "\\topcall.inc\shares\PowerShell_Framework$",
    [string]$ProgramDataBaseDir = "C:\ProgramData\PowerShell",
    [string]$ProgramData = "$ProgramDataBaseDir\PsRemoteAdminFramework",
    [string]$LogPath = "$ProgramData\Progress.log"
)

$script:ApiPath = $PSCommandPath

# Essencial callbacks to resolve PsRegistryConfig
$callbacks = @{
    'REPOSITORY' = {
        $BootstrapRoot
    }
    'PROGRAMDATABASEDIR' = {
        $ProgramDataBaseDir
    }
    'MODULESBASE' = {
        $globalPath = "C:\Program Files\PowerShell\Modules"
        $userPath   = Join-Path $env:USERPROFILE "Documents\PowerShell\Modules"

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

function FallbackLog {
    param($msg, [switch]$warning, [switch]$error, [switch]$force)
    $force = $error -or $force
    if (-not $EnableDebugLogging -and -not $force) { return }
    if ($null -ne $Logger) {
        if ($error) { $Logger.Error($msg)  }
        elseif ($warning) { $Logger.Warn($msg)  }
        else { $Logger.Info($msg)  }                       
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $line = "[$timestamp] $msg"
        $line | Out-File -FilePath $LogPath -Encoding UTF8 -Append -Force
    }
    if($EnableDebugLogging){
        if ($error) { Write-Error $msg }
        elseif ($warning) { Write-Warning $msg }
        else { Write-Host $msg }
    }
}

try {
    $IsApiMode = $PSCmdlet.ParameterSetName -eq 'ApiMode'
    if ($IsApiMode) {
        if (-not $InvokeApi.Path -or $InvokeApi.Path.Count -eq 0) {
            FallbackLog "ApiMode requires 'Path' to be a non-empty string array" -error
            exit 1
        }
        if ($null -ne $InvokeApi.Memory -and $InvokeApi.Memory -isnot [object]) {
            FallbackLog "InvokeApi.Memory must be a hashtable if provided" -error
            exit 1
        }
        $Memory = if ($null -ne $InvokeApi.Memory) { $InvokeApi.Memory } else { @{} }
    } else {
        # try {
        #     Import-Module ClassLoader -ErrorAction Stop
        # } catch {
        #     Invoke-Expression (Get-Content (Join-Path $BootstrapRoot "Modules\ClassLoader\ClassLoader.psm1") -Raw -Encoding UTF8 -ErrorAction Stop)
        # } finally {
        #     if(Get-Command ClassLoader -ErrorAction SilentlyContinue){
        #         $Modules = @(
        #             "FileAndDirectoryOperations",
        #             "ProxyPlaceholderResolver",
        #             "CreatePsStartFileLink",
        #             "CapabilityProvider"  
        #             "Debugger",
        #             "Logger"
        #         )
        #         ClassLoader -RootDirectory $BootstrapRoot -Modules $Modules
        #     }
        # }
        if (-not $ExecutedByShortcut) {
            if(Get-Command CreatePsStartFileLink -ErrorAction Stop) {
                Import-Module CreatePsStartFileLink
            }
            CreatePsStartFileLink -TargetScript $MyInvocation.MyCommand.Definition -PS7
            Start-Sleep -Seconds 1
        }
        $Memory = @{}
    }
    $Context = [pscustomobject]@{}
    $Resolver = [ProxyPlaceholderResolver]::new()
    $Context | Add-Member -NotePropertyName 'Resolver' -NotePropertyValue $Resolver
    $callbacks = & (Join-Path $ProgramData 'PlaceholderCallbacks.ps1')
    $Resolver.RegisterCallbacks($callbacks)
    $CfgPsd = Import-PowerShellDataFile (Join-Path $ProgramData "Config.psd1")
    $Resolver.RegisterSource('CONFIG', $CfgPsd)
    $Config = $Resolver.CreateProxy('CONFIG', $Context, @('AsHashtable','GetKeys'))
    $Context | Add-Member -NotePropertyName 'Config' -NotePropertyValue $Config
    # Start-Sleep -Seconds 1
    $Logger = [Logger]::new(@{
        LogInfo         = $Config.LogProgress
        LogErrors       = $Config.LogErrors
        UseConsole      = if ($IsApiMode) { $true } else { $false }
        # CatchOutputs    = if ($IsApiMode) { $false } else { $true }
        CatchOutputs    = $false
    })
    $Context | Add-Member -NotePropertyName 'Logger' -NotePropertyValue $Logger -Force
    $RegPsd = Import-PowerShellDataFile $Config.PsRegistryConfig.target
    $Resolver.RegisterSource('REGISTRY', $RegPsd)
    $Registry = $Resolver.CreateProxy('REGISTRY', $Context, @('AsHashtable','Filter','GetKeys','GetRecords'))
    $Context | Add-Member -NotePropertyName 'Registry' -NotePropertyValue $Registry
    $DependencyProvider = DependencyProvider $Context
    $DependencyInjector = & $DependencyProvider.ScriptBlock $DependencyProvider.ArgumentList
    $Context | Add-Member -NotePropertyName 'DependencyProvider' -NotePropertyValue $DependencyProvider
    $Context | Add-Member -NotePropertyName 'DependencyInjector' -NotePropertyValue $DependencyInjector
    $Context | Add-Member -NotePropertyName 'Memory' -NotePropertyValue $Memory
    $Context.Logger.Info("--- 🖥️ $($env:COMPUTERNAME) - Running as: 👤 $(whoami) ---")
    $Node = & (Join-Path $Config.ProgramData $Config.ProgramNodes)
    if ($IsApiMode) {
        ResolveApiRequestPath -Node $Node -Path $InvokeApi.Path -Context $Context
    } else {
        MultiDimensionalMenu -Node $Node -Context $Context -MenuName $Config.MenuName -DisplayIndex $Config.DisplayIndex
    }
} catch {
    $_.Exception.Message
    pause
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

    $statusMessages = @{
        offline = $(
            "Fatal error while main program initialization`:",
            $_.Exception.Message,
            "Bootstrap repository not available: $BootstrapRoot"
        )
        beginning = "Beginning installation"
        installing = "Installation in progress..."
        updating = "Update in progress..."
        loadedRegistry = "PsRegistryConfig loaded from repository"
        resolvedRegistry = "PsRegistryConfig resolved"
        convertedRegistry = "Content of PsRegistryConfig converted to hashtable"
        loadedResolver = "ProxyPlaceholderResolver loaded from repository"
        registeredResolver = "ProxyPlaceholderResolver registered in Context"
        loadedCallbacks = "PlaceholderCallbacks loaded from repository"
        loadedConfig = "RemoteAdminConfig loaded from repository"
        registeredConfig = "RemoteAdminConfig registered in Context"
        registeredRegisty = "PsRegistryConfig registered in ProxyPlaceholderResolver and Context"
        determiningDependencies = "Determining dependencies..."
        completedUpdate = "UpdateDeployment complete"
        processCompleted = "Completed"
        restarting = "Restarting application"
        terminating = "Remote Admin Framework terminated"
    }

    $ProgressBar = {
        param(
            [string]$Activity,
            [string]$Status,
            [int]$Percent
        )
        if ($Host.Name -ne 'ConsoleHost') { return }
        if($Percent -le 100){
            Start-Sleep -MilliSeconds 250
            Write-Progress -Activity $Activity -Status $Status -PercentComplete $Percent
        }else{
            Start-Sleep -Seconds 1
            Write-Progress -Activity $Activity -Completed
        }        
    }

    $totalSteps = 11
    $currentStep = 0
    function calcPercentages {
        $percent = $global:currentStep / $totalSteps * 100
        $global:currentStep++
        return $percent
    }

    # Check repository availability
    if (-not (Test-Path $BootstrapRoot)) {
        Clear-Host
        offlineBanner
        FallbackLog $statusMessages.offline[0] -Force
        FallbackLog $statusMessages.offline[1] -Force
        FallbackLog $statusMessages.offline[2] -error
        if ($Host.Name -eq 'ConsoleHost') { Pause }
        exit 1
    } else {
        Clear-Host
        updateBanner
        & $ProgressBar $statusMessages.beginning $statusMessages.updating (calcPercentages)
        FallbackLog $statusMessages.updating -Force
    }

    # Loading PsRegistryConfig
    $RegPsdSource = Join-Path $BootstrapRoot "ConfigFiles\PsRegistryConfig.psd1"
    $regPsdContent = Get-Content $RegPsdSource -Raw
    & $ProgressBar "Step $currentStep" $statusMessages.loadedRegistry (calcPercentages)
    FallbackLog $statusMessages.loadedRegistry -Force

    # Resolve hardcoded Callbacks (Search & Replace)
    foreach ($key in $callbacks.Keys) {
        $placeholder = "{{$key}}"
        $value = $callbacks[$key].Invoke()
        $regPsdContent = $regPsdContent -replace [regex]::Escape($placeholder), $value
    }
    & $ProgressBar "Step $currentStep" $statusMessages.resolvedRegistry (calcPercentages)
    FallbackLog $statusMessages.resolvedRegistry -Force

    # Loading PsRegistryConfig as Hashtable
    $RegPsd = [scriptblock]::Create($regPsdContent).InvokeReturnAsIs()
    & $ProgressBar "Step $currentStep" $statusMessages.convertedRegistry (calcPercentages)
    FallbackLog $statusMessages.convertedRegistry -Force

    # Loading ProxyPlaceholderResolver
    if (-not ('ProxyPlaceholderResolver' -as [Type])) {
        Invoke-Expression (Get-Content $RegPsd.ProxyPlaceholderResolver.source -Raw)
    }
    $Resolver = [ProxyPlaceholderResolver]::new()
    & $ProgressBar "Step $currentStep" $statusMessages.loadedResolver (calcPercentages)
    FallbackLog $statusMessages.loadedResolver -Force

    $Context = [pscustomobject]@{}
    $Context | Add-Member -NotePropertyName 'Resolver' -NotePropertyValue $Resolver
    & $ProgressBar "Step $currentStep" $statusMessages.registeredResolver (calcPercentages)
    FallbackLog $statusMessages.registeredResolver -Force

    # Register PlaceholderCallbacks in ProxyPlaceholderResolver
    $callbacks = & $RegPsd.PlaceholderCallbacks.source
    $Resolver.RegisterCallbacks($callbacks)
    & $ProgressBar "Step $currentStep" $statusMessages.loadedCallbacks (calcPercentages)
    FallbackLog $statusMessages.loadedCallbacks -Force

    # Loading RemoteAdminConfig
    $CfgPsd = Import-PowerShellDataFile $RegPsd.RemoteAdminConfig.source
    & $ProgressBar "Step $currentStep" $statusMessages.loadedConfig (calcPercentages)
    FallbackLog $statusMessages.loadedConfig -Force

    # Register RemoteAdminConfig
    $Resolver.RegisterSource('CONFIG', $CfgPsd)
    $Config = $Resolver.CreateProxy('CONFIG', $Context, $null)
    $Context | Add-Member -NotePropertyName 'Config' -NotePropertyValue $Config
    & $ProgressBar "Step $currentStep" $statusMessages.registeredConfig (calcPercentages)
    FallbackLog $statusMessages.registeredConfig -Force

    # Register PsRegistryConfig
    $Resolver.RegisterSource('REGISTRY', $RegPsd)
    $Registry = $Resolver.CreateProxy('REGISTRY', $Context, @('AsHashtable'))
    $Context | Add-Member -NotePropertyName 'Registry' -NotePropertyValue $Registry
    & $ProgressBar "Step $currentStep" $statusMessages.registeredRegisty (calcPercentages)
    FallbackLog $statusMessages.registeredRegisty -Force

    # Install all essencial dependencies
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
    [object[]]$jobs = CreateJob -Deployments $deployments
    & $ProgressBar "Step $currentStep" $statusMessages.determiningDependencies (calcPercentages)
    
    # UpdateDeployment -Jobs $jobs -EnableDebugLogging:$EnableDebugLogging
    & $ProgressBar "Step $currentStep" $statusMessages.completedUpdate (calcPercentages)
    FallbackLog $statusMessages.completedUpdate -Force

    # Application restart 
    & $ProgressBar $statusMessages.processCompleted "" 101
    Clear-Host
    completeBanner
    FallbackLog $statusMessages.restarting -Force
    Start-Sleep -Seconds 3
    # Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy Bypass",  "-File `"$PSCommandPath`""
    # exit 1

} finally {
    FallbackLog $statusMessages.terminating -Force
    FallbackLog "-------------------------------------------------------" -Force
}
