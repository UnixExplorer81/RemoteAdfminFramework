[CmdletBinding(DefaultParameterSetName = 'Interactive')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'ApiMode', Position = 0)]
    [object]$InvokeApi,

    [switch]$LinkExecuted,
    [switch]$VolatileDI,

    [string]$BootstrapRoot = "\\topcall.inc\shares\PowerShell_Framework$",
    [string]$ProgramDataBaseDir = "C:\ProgramData\PowerShell",
    [string]$ProgramData = (Join-Path $ProgramDataBaseDir "PsRemoteAdminFramework"),
    [string]$ConfigPath = (Join-Path $ProgramData "Config.psd1"),
    [string]$LogPath = (Join-Path $ProgramData "Progress.log"),

    [bool]$EnableDebugLogging = $true
)

function FallbackLog {
    param($msg, [switch]$w, [switch]$e, [switch]$f)
    $force = $e -or $f
    if (-not $EnableDebugLogging -and -not $force) { return }
    if ($null -ne $Logger) {
        if ($e) { $Logger.Error($msg)  }
        elseif ($w) { $Logger.Warn($msg)  }
        else { $Logger.Info($msg)  }                       
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $line = "[$timestamp] $msg"
        $line | Out-File -FilePath $LogPath -Encoding UTF8 -Append -Force
    }
    if($EnableDebugLogging){
        if ($e) { Write-Error $msg }
        elseif ($w) { Write-Warning $msg }
        else { Write-Host $msg }
    }
}

$script:ApiPath = $PSCommandPath
$IsApiMode      = $PSCmdlet.ParameterSetName -eq 'ApiMode'
try {
    if ($IsApiMode) {
        if (-not $InvokeApi.Path -or $InvokeApi.Path.Count -eq 0) {
            FallbackLog "ApiMode requires 'Path' to be a non-empty string array" -e
            exit 1
        }
        if ($null -ne $InvokeApi.Memory -and $InvokeApi.Memory -isnot [object]) {
            FallbackLog "InvokeApi.Memory must be a hashtable if provided" -e
            exit 1
        }
        $Memory = if ($null -ne $InvokeApi.Memory) { $InvokeApi.Memory } else { @{} }
    } else {
        $Memory = @{}
    }
    $Context = [pscustomobject]@{}
    $Resolver = ProxyResolver $Context
    $Context | Add-Member -NotePropertyName 'Resolver' -NotePropertyValue $Resolver
    $ConfigPsd = Import-PowerShellDataFile $ConfigPath
    $Resolver.RegisterCallbacks((& (Join-Path $ProgramData $ConfigPsd.PsCallbacks)))
    $Resolver.RegisterSource('CONFIG', $ConfigPsd)
    $Config = $Resolver.CreateProxy('CONFIG', @('AsHashtable','GetKeys'))
    if($VolatileDI){ $Config.VolatileDI = $true }
    $Context | Add-Member -NotePropertyName 'Config' -NotePropertyValue $Config
    $Logger = Logger @{
        LogInfo         = $Config.LogProgress
        LogErrors       = $Config.LogErrors
        UseConsole      = if ($IsApiMode) { $true } else { $false }
        # CatchOutputs    = if ($IsApiMode) { $false } else { $true }
        CatchOutputs    = $false
    }
    $Logger.Info("--- 🖥️ $($env:COMPUTERNAME) - Running as: 👤 $(whoami) ---")
    $Context | Add-Member -NotePropertyName 'Logger' -NotePropertyValue $Logger -Force
    $Resolver.RegisterSource('REGISTRY', (Import-PowerShellDataFile $Config.PsRegistryConfig.target))
    $Registry = $Resolver.CreateProxy('REGISTRY', @('AsHashtable','Filter','GetKeys','GetRecords'))
    $Context | Add-Member -NotePropertyName 'Registry' -NotePropertyValue $Registry
    $Context | Add-Member -NotePropertyName 'DependencyInjector' -NotePropertyValue (DependencyInjector ($Resolver.ResolveProxyObjects(@('Registry'))))
    $Context | Add-Member -NotePropertyName 'DependencyProvider' -NotePropertyValue (DependencyProvider $Context)
    $Context | Add-Member -NotePropertyName 'DI' -NotePropertyValue (& $Context.DependencyProvider)

    $Context | Add-Member -NotePropertyName 'Memory' -NotePropertyValue $Memory
    $Node = & $Registry.RemoteAdminData.target # <--- menuestruktur, wenn man einen menuepunkt auswaehlt, ist $context bereits komplett!
    if ($IsApiMode) {
        ResolveApiRequestPath -Node $Node -Path $InvokeApi.Path -Context $Context
    } else {
        MultiDimensionalMenu -Node $Node -Context $Context -MenuName $Config.MenuName -DisplayIndex $Config.DisplayIndex
    }
} catch {
    
    if($null -eq $Config -or $Config.Verbose){
        $_.Exception.Message
        pause        
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
   
    $statusMessages = @{
        offline = @(
            "Fatal error while main program initialization`:",
            $_.Exception.Message,
            "Bootstrap repository not available: $BootstrapRoot"
        )
        checkingInstallation = "Checking your Installation..."
        installing = "Installation in progress..."
        updating = "Update in progress..."
        importRegisty = "Importing PowerShell Registry"
        importedRegistry = "PowerShell Registry imported from repository"
        resolveRegistry = "Resolving PowerShell Registry"
        resolvedRegistry = "PowerShell Registry resolved"
        evaluateRegistry = "Evaluating PowerShell Registry"
        evaluatedRegistry = "PowerShell Registry evaluated"
        importDependencyInjector = "Importing dependency injector"
        importedDependencyInjector = "Dependency Injector imported"
        importResolver = "Importing Proxy Resolver"
        importedResolver = "Proxy Resolver imported from repository"
        registerResolverCB = "Registering Proxy Resolver Callbacks"
        registeredResolverCB = "Proxy Resolver registered Callbacks"
        importConfig = "Importing general configuration"
        importedConfig = "General configuration imported from repository"
        registerConfig = "Registering general configuration"
        registeredConfig = "General configuration registered in Context"
        registerRegistyPR = "Registering PowerShell Registry in ProxyResolver"
        registeredRegistyPR = "PowerShell Registry registered in ProxyResolver"
        registerRegisty = "Register PowerShell registry"
        registeredRegisty = "PowerShell registry registered in Context"
        importApiExecuteable = "Importing API executeable"
        importedApiExecuteable = "API executeable imported"
        importRestApiExecuteable = "Importing REST API executeable"
        importedRestApiExecuteable = "REST API executeable imported"
        importRestApiWrapper = "Importing REST API Wrapper"
        importedRestApiWrapper = "REST API Wrapper imported"
        createStartFileLinks = "Creating start file links"
        createdStartFileLinks = "Start file links created"
        importApiRequestPathResolver = "Importing API request resolver"
        importedApiRequestPathResolver = "API request resolver imported"
        importMultiDimensionalMenu = "Importing MultiDimensionalMenu"
        importedMultiDimensionalMenu = "MultiDimensionalMenu imported"
        importRemoteAdminData = "Importing program menu structure"
        importedRemoteAdminData = "Program menu structure imported"
        importProgressBar = "Importing ProgressBar"
        importedProgressBar = "ProgressBar imported"
        importCredentialManager = "Importing CredentialManager"
        importedCredentialManager = "CredentialManager imported"
        importComputerActive = "Importing ComputerActive"
        importedComputerActive = "ComputerActive imported"
        importParamNormalizer = "Importing ParamNormalizer"
        importedParamNormalizer = "ParamNormalizer imported"
        importParallelRemotingJobs = "Importing ParallelRemoting"
        importedParallelRemotingJobs = "ParallelRemoting imported"
        importStationSelector = "Importing StationSelector"
        importedStationSelector = "StationSelector imported"
        importLogger = "Importing Logger"
        importedLogger = "Logger imported"
        terminating = "Remote Admin Framework terminated"
    }

    # Essencial callbacks to resolve PsRegistryConfig
    $callbacks = @{
        'REPOSITORY' = {
            $BootstrapRoot
        }
        'PROGRAMDATABASEDIR' = {
            $ProgramDataBaseDir
        }
        'MODULESBASE' = {
            $GlobalModulePath = @{
                PS5 = "C:\Program Files\WindowsPowerShell\Modules"
                PS7 = "C:\Program Files\PowerShell\Modules"
            }
            $globalPath = if($PSVersionTable.PSVersion.Major -eq 7) { $GlobalModulePath.PS7 } else { $GlobalModulePath.PS5 }
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

    $ProgressBar = {
        param(
            [string]$Activity,
            [string]$Status,
            [int]$Percent
        )
        if ($Host.Name -ne 'ConsoleHost') { return }
        if($Percent -le 100){
            Write-Progress -Activity $Activity -Status $Status -PercentComplete $Percent
        }else{
            Start-Sleep -Seconds 1
            Write-Progress -Activity $Activity -Completed
        }        
    }

    $totalSteps = if($LinkExecuted) {23} else {24}
    $currentStep = 1
    function calcPercentages {
        $percent = $global:currentStep / $totalSteps * 100
        $global:currentStep++
        return $percent
    }

    # Check repository availability
    if (-not (Test-Path $BootstrapRoot)) {
        Clear-Host
        offlineBanner
        FallbackLog $statusMessages.offline[0] -f
        FallbackLog $statusMessages.offline[1] -f
        FallbackLog $statusMessages.offline[2] -e
        if ($Host.Name -eq 'ConsoleHost') { Pause }
        exit 1
    } else {
        Clear-Host
        updateBanner
        FallbackLog $statusMessages.checkingInstallation -f
    }

    # Import PsRegistryConfig
    & $ProgressBar "Step $currentStep" $statusMessages.importRegisty (calcPercentages)
    $regPsdSource = Join-Path $BootstrapRoot "ConfigFiles\PsRegistryConfig.psd1"
    $regPsdContent = Get-Content $regPsdSource -Raw
    FallbackLog $statusMessages.importedRegistry -f

    # Resolve essencial hardcoded Callbacks (Search & Replace)
    & $ProgressBar "Step $currentStep" $statusMessages.resolveRegistry (calcPercentages)
    foreach ($key in $callbacks.Keys) {
        $placeholder = "{{$key}}"
        $value = $callbacks[$key].Invoke()
        $regPsdContent = $regPsdContent -replace [regex]::Escape($placeholder), $value
    }
    FallbackLog $statusMessages.resolvedRegistry -f

    # Register PsRegistryConfig in Context
    & $ProgressBar "Step $currentStep" $statusMessages.evaluateRegistry (calcPercentages)
    $Registry = [scriptblock]::Create($regPsdContent).InvokeReturnAsIs()
    $Context = [pscustomobject]@{}
    $DiContext = @{
        Config = @{VolatileDI = $VolatileDI}
        Registry = $Registry
    }
    # $Context | Add-Member -NotePropertyName 'Registry' -NotePropertyValue $Registry
    FallbackLog $statusMessages.evaluatedRegistry -f

    # Register DependencyInjector and DependencyProvider in Context
    & $ProgressBar "Step $currentStep" $statusMessages.importDependencyInjector (calcPercentages)
    Import-Module $Registry.DependencyInjector.source -Force
    $Context | Add-Member -NotePropertyName 'DependencyInjector' -NotePropertyValue (DependencyInjector $DiContext)
    $Context | Add-Member -NotePropertyName 'DependencyProvider' -NotePropertyValue (DependencyProvider $Context)
    $Context | Add-Member -NotePropertyName 'DI' -NotePropertyValue (& $Context.DependencyProvider)
    & $Context.DI.GetContent 'DependencyInjector' | Out-Null
    FallbackLog $statusMessages.importedDependencyInjector -f

    # Import ProxyResolver and register in Context
    & $ProgressBar "Step $currentStep" $statusMessages.importResolver (calcPercentages)
    & $Context.DI.ImportModule 'ProxyResolver'
    $Resolver = ProxyResolver $Context
    $Context | Add-Member -NotePropertyName 'Resolver' -NotePropertyValue $Resolver
    FallbackLog $statusMessages.importedResolver -f

    # Register PsCallbacks in ProxyResolver
    & $ProgressBar "Step $currentStep" $statusMessages.registerResolverCB (calcPercentages)
    $Resolver.RegisterCallbacks((Invoke-Expression (& $Context.DI.GetContent 'PsCallbacks')))
    FallbackLog $statusMessages.registeredResolverCB -f

    # Import RemoteAdminConfig and register in ProxyResolver 
    & $ProgressBar "Step $currentStep" $statusMessages.importConfig (calcPercentages)
    $Resolver.RegisterSource('CONFIG', (Invoke-Expression (& $Context.DI.GetContent 'RemoteAdminConfig')))
    FallbackLog $statusMessages.importedConfig -f

    # Register RemoteAdminConfig in Context
    & $ProgressBar "Step $currentStep" $statusMessages.registerConfig (calcPercentages)
    $Config = $Resolver.CreateProxy('CONFIG', @('AsHashtable','GetKeys'))
    $Context | Add-Member -NotePropertyName 'Config' -NotePropertyValue $Config
    FallbackLog $statusMessages.registeredConfig -f

    # Register PsRegistryConfig in ProxyResolver 
    & $ProgressBar "Step $currentStep" $statusMessages.registerRegistyPR (calcPercentages)
    $Resolver.RegisterSource('REGISTRY', (Invoke-Expression (& $Context.DI.GetContent 'PsRegistryConfig')))
    FallbackLog $statusMessages.registeredRegistyPR -f

    # Register PsRegistryConfig in Context
    & $ProgressBar "Step $currentStep" $statusMessages.registerRegisty (calcPercentages)
    $Registry = $Resolver.CreateProxy('REGISTRY', @('AsHashtable','Filter','GetKeys','GetRecords'))
    $Context | Add-Member -NotePropertyName 'Registry' -NotePropertyValue $Registry
    FallbackLog $statusMessages.registeredRegisty -f

    # Import PsRemoteAdminFramework
    & $ProgressBar "Step $currentStep" $statusMessages.importApiExecuteable (calcPercentages)
    & $Context.DI.GetContent 'PsRemoteAdminFramework' | Out-Null
    FallbackLog $statusMessages.importedApiExecuteable -f

    # Import RemoteAdminRestApi
    & $ProgressBar "Step $currentStep" $statusMessages.importRestApiExecuteable (calcPercentages)
    & $Context.DI.GetContent 'RemoteAdminRestApi' | Out-Null
    FallbackLog $statusMessages.importedRestApiExecuteable -f

    # Import RestApiWrapper
    & $ProgressBar "Step $currentStep" $statusMessages.importRestApiWrapper (calcPercentages)
    & $Context.DI.ImportModule 'RestApiWrapper'
    FallbackLog $statusMessages.importedRestApiWrapper -f

    if (-not $LinkExecuted) {
        # Import CreatePsStartFileLink
        & $ProgressBar "Step $currentStep" $statusMessages.createStartFileLinks (calcPercentages)
        & $Context.DI.ImportModule 'CreatePsStartFileLink'
        FallbackLog (CreatePsStartFileLink -TargetScript $Registry.PsRemoteAdminFramework.target).Message -f
        FallbackLog (CreatePsStartFileLink -TargetScript $Registry.PsRemoteAdminFramework.target -PsVersion 7).Message -f
        FallbackLog (CreatePsStartFileLink -TargetScript $Registry.RemoteAdminRestApi.target).Message -f
        FallbackLog (CreatePsStartFileLink -TargetScript $Registry.RemoteAdminRestApi.target -PsVersion 7).Message -f
        FallbackLog $statusMessages.createdStartFileLinks -f
    }

    # Import ResolveApiRequestPath
    & $ProgressBar "Step $currentStep" $statusMessages.importApiRequestPathResolver (calcPercentages)
    & $Context.DI.ImportModule 'ResolveApiRequestPath'
    FallbackLog $statusMessages.importedApiRequestPathResolver -f

    # Import MultiDimensionalMenu
    & $ProgressBar "Step $currentStep" $statusMessages.importMultiDimensionalMenu (calcPercentages)
    & $Context.DI.ImportModule 'MultiDimensionalMenu'
    FallbackLog $statusMessages.importedMultiDimensionalMenu -f

    # Import ProgressBar
    & $ProgressBar "Step $currentStep" $statusMessages.importProgressBar (calcPercentages)
    & $Context.DI.ImportModule 'ProgressBar'
    FallbackLog $statusMessages.importedProgressBar -f

    # Import CredentialManager
    & $ProgressBar "Step $currentStep" $statusMessages.importCredentialManager (calcPercentages)
    & $Context.DI.ImportModule 'CredentialManager'
    FallbackLog $statusMessages.importedCredentialManager -f

    # Import ParamNormalization
    & $ProgressBar "Step $currentStep" $statusMessages.importParamNormalizer (calcPercentages)
    & $Context.DI.ImportModule 'ParamNormalization'
    FallbackLog $statusMessages.importedParamNormalizer -f

    # Import ComputerActive
    & $ProgressBar "Step $currentStep" $statusMessages.importComputerActive (calcPercentages)
    & $Context.DI.ImportModule 'ComputerActive'
    FallbackLog $statusMessages.importedComputerActive -f

    # Import ParallelRemotingJobs
    & $ProgressBar "Step $currentStep" $statusMessages.importParallelRemotingJobs (calcPercentages)
    & $Context.DI.ImportModule 'ParallelRemotingJobs'
    FallbackLog $statusMessages.importedParallelRemotingJobs -f

    # Import StationSelector
    & $ProgressBar "Step $currentStep" $statusMessages.importStationSelector (calcPercentages)
    & $Context.DI.ImportModule 'StationSelector'
    FallbackLog $statusMessages.importedStationSelector -f

    # Import and register logger
    & $ProgressBar "Step $currentStep" $statusMessages.importLogger (calcPercentages)
    & $Context.DI.ImportModule 'Logger'
    $Logger = Logger @{
        LogInfo         = $Config.LogProgress
        LogErrors       = $Config.LogErrors
        UseConsole      = if ($IsApiMode) { $true } else { $false }
        # CatchOutputs    = if ($IsApiMode) { $false } else { $true }
        CatchOutputs    = $false
    }
    $Context | Add-Member -NotePropertyName 'Logger' -NotePropertyValue $Logger -Force
    FallbackLog $statusMessages.importedLogger -f

    # Import RemoteAdminData
    & $ProgressBar "Step $currentStep" $statusMessages.importRemoteAdminData (calcPercentages)
    $Node = Invoke-Expression (& $Context.DI.GetContent 'RemoteAdminData')
    FallbackLog $statusMessages.importedRemoteAdminData -f

    # Application installed / update complete 
    & $ProgressBar $statusMessages.processCompleted "" 101
    Clear-Host
    completeBanner
    Start-Sleep -Seconds 1

    $Context | Add-Member -NotePropertyName 'Memory' -NotePropertyValue $Memory
    $Logger.Info("--- 🖥️ $($env:COMPUTERNAME) - Running as: 👤 $(whoami) ---")

    if ($IsApiMode) {
        ResolveApiRequestPath -Node $Node -Path $InvokeApi.Path -Context $Context
    } else {
        MultiDimensionalMenu -Node $Node -Context $Context -MenuName $Config.MenuName -DisplayIndex $Config.DisplayIndex
    }

} finally {
    FallbackLog $statusMessages.terminating -f
    FallbackLog "-------------------------------------------------------------------------------------" -f
}
