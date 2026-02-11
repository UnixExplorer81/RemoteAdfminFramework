@{
<#
    Starter
#>
    AgentsFaq = @{
        source = "{{TRUSTEDSITE}}\FAQ\Start-FAQ.ps1"
        target = "{{PROGRAMDATA}}\AgentsFaq\Start-FAQ.ps1"
    }
    BootstrapUpdateDeployment = @{
        source = "{{REPOSITORY}}\Modules\UpdateDeployment\bootstrapUpdateDeployment.ps1"
        target = "{{PROGRAMDATABASEDIR}}\UpdateDeployment\bootstrapUpdateDeployment.ps1"
    }
    DeployUpdateDeployment = @{
        source = "{{REPOSITORY}}\Modules\UpdateDeployment\deployUpdateDeployment.ps1"
        target = "{{PROGRAMDATABASEDIR}}\UpdateDeployment\deployUpdateDeployment.ps1"
    }
    RemoteAdminRestApi = @{
        source = "{{REPOSITORY}}\Starter\RemoteAdminRestApi.ps1"
        target = "{{PROGRAMDATABASEDIR}}\RemoteAdminTools\RemoteAdminRestApi.ps1"
    }
    RemoteAdminTools = @{
        source = "{{REPOSITORY}}\Starter\RemoteAdminTools.ps1"
        target = "{{PROGRAMDATABASEDIR}}\RemoteAdminTools\RemoteAdminTools.ps1"
    }
<#
    Configs
#>
    DomainAccountsApiConfig = @{
        source = "{{REPOSITORY}}\ConfigFiles\DomainAccountsApiConfig.json"
        target = "{{PROGRAMDATABASEDIR}}\DomainAccountsApiConfig.json"
    }
    InteractiveSync = @{
        source = "{{REPOSITORY}}\ConfigFiles\InteractiveSync.ps1"
        target = "{{PROGRAMDATABASEDIR}}\InteractiveSync.ps1"
    }
    PlaceholderCallbacks = @{
        source = "{{REPOSITORY}}\ConfigFiles\PlaceholderCallbacks.ps1"
        target = "{{PROGRAMDATABASEDIR}}\PlaceholderCallbacks.ps1"
    }
    PsRegistryConfig = @{
        source = "{{REPOSITORY}}\ConfigFiles\PsRegistryConfig.psd1"
        target = "{{PROGRAMDATABASEDIR}}\PsRegistryConfig.psd1"
    }
    RemoteAdminConfig = @{
        source = "{{REPOSITORY}}\ConfigFiles\RemoteAdminConfig.psd1"
        target = "{{PROGRAMDATABASEDIR}}\RemoteAdminTools\Config.psd1"
    }
    RemoteAdminData = @{
        source = "{{REPOSITORY}}\ConfigFiles\RemoteAdminNodeData.ps1"
        target = "{{PROGRAMDATABASEDIR}}\RemoteAdminTools\NodeData.ps1"
    }
<#
    Modules
#>
    ADUserSync = @{
        source = "{{REPOSITORY}}\Modules\ADUserSync\ADUserSync.psm1"
        target = "{{MODULESBASE}}\ADUserSync\ADUserSync.psm1"
    }
    ApiRequest = @{
        source = "{{REPOSITORY}}\Modules\ApiRequest\ApiRequest.psm1"
        target = "{{MODULESBASE}}\ApiRequest\ApiRequest.psm1"
    }
    CapabilityInjector = @{
        source = "{{REPOSITORY}}\Modules\CapabilityInjector\CapabilityInjector.psm1"
        target = "{{MODULESBASE}}\CapabilityInjector\CapabilityInjector.psm1"
    }
    CapabilityProvider = @{
        source = "{{REPOSITORY}}\Modules\CapabilityProvider\CapabilityProvider.psm1"
        target = "{{MODULESBASE}}\CapabilityProvider\CapabilityProvider.psm1"
    }
    ChangePassword = @{
        source = "{{REPOSITORY}}\Modules\ChangePassword\ChangePassword.psm1"
        target = "{{MODULESBASE}}\ChangePassword\ChangePassword.psm1"
    }
    ConvertToHashtable = @{
        source = "{{REPOSITORY}}\Modules\ConvertToHashtable\ConvertToHashtable.psm1"
        target = "{{MODULESBASE}}\ConvertToHashtable\ConvertToHashtable.psm1"
    }
    CreatePsStartFileLink = @{
        source = "{{REPOSITORY}}\Modules\CreatePsStartFileLink\CreatePsStartFileLink.psm1"
        target = "{{MODULESBASE}}\CreatePsStartFileLink\CreatePsStartFileLink.psm1"
    }
    CredentialInjector = @{
        source = "{{REPOSITORY}}\Modules\CredentialInjector\CredentialInjector.psm1"
        target = "{{MODULESBASE}}\CredentialInjector\CredentialInjector.psm1"
    }
    CredentialManager = @{
        source = "{{REPOSITORY}}\Modules\CredentialManager\CredentialManager.psm1"
        target = "{{MODULESBASE}}\CredentialManager\CredentialManager.psm1"
    }
    DcsbFixes = @{
        source = "{{REPOSITORY}}\Modules\DcsbFixes\DcsbFixes.psm1"
        target = "{{MODULESBASE}}\DcsbFixes\DcsbFixes.psm1"
    }
    Debugger = @{
        source = "{{REPOSITORY}}\Modules\Debugger\Debugger.psm1"
        target = "{{MODULESBASE}}\Debugger\Debugger.psm1"
    }
    DependencyCollector = @{
        source = "{{REPOSITORY}}\Modules\DependencyCollector\DependencyCollector.psm1"
        target = "{{MODULESBASE}}\DependencyCollector\DependencyCollector.psm1"
    }
    ExecuteApiRequest = @{
        source = "{{REPOSITORY}}\Modules\ExecuteApiRequest\ExecuteApiRequest.psm1"
        target = "{{MODULESBASE}}\ExecuteApiRequest\ExecuteApiRequest.psm1"
    }
    DetectModulesBasePath = @{
        source = "{{REPOSITORY}}\Modules\DetectModulesBasePath\DetectModulesBasePath.psm1"
        target = "{{MODULESBASE}}\DetectModulesBasePath\DetectModulesBasePath.psm1"
    }
    FileAndDirectoryOperations = @{
        source = "{{REPOSITORY}}\Modules\FileAndDirectoryOperations\FileAndDirectoryOperations.psm1"
        target = "{{MODULESBASE}}\FileAndDirectoryOperations\FileAndDirectoryOperations.psm1"
    }
    GrantRoamingProfilesAccess = @{
        source = "{{REPOSITORY}}\Modules\GrantRoamingProfilesAccess\GrantRoamingProfilesAccess.psm1"
        target = "{{MODULESBASE}}\GrantRoamingProfilesAccess\GrantRoamingProfilesAccess.psm1"
    }
    Logger = @{
        source = "{{REPOSITORY}}\Modules\Logger\Logger.psm1"
        target = "{{MODULESBASE}}\Logger\Logger.psm1"
    }
    MultiDimensionalMenu = @{
        source = "{{REPOSITORY}}\Modules\MultiDimensionalMenu\MultiDimensionalMenu.psm1"
        target = "{{MODULESBASE}}\MultiDimensionalMenu\MultiDimensionalMenu.psm1"
    }
    MultiPlaceholderResolver = @{
        source = "{{REPOSITORY}}\Modules\MultiPlaceholderResolver\MultiPlaceholderResolver.psm1"
        target = "{{MODULESBASE}}\MultiPlaceholderResolver\MultiPlaceholderResolver.psm1"
    }
    MountPsDrive = @{
        source = "{{REPOSITORY}}\Modules\MountPsDrive\MountPsDrive.psm1"
        target = "{{MODULESBASE}}\MountPsDrive\MountPsDrive.psm1"
    }
    NetConfigAssistant = @{
        source = "{{REPOSITORY}}\Modules\NetConfigAssistant\NetConfigAssistant.psm1"
        target = "{{MODULESBASE}}\NetConfigAssistant\NetConfigAssistant.psm1"
    }
    NetConfigurator = @{
        source = "{{REPOSITORY}}\Modules\NetConfigurator\NetConfigurator.psm1"
        target = "{{MODULESBASE}}\NetConfigurator\NetConfigurator.psm1"
    }
    NetUseAuthentification = @{
        source = "{{REPOSITORY}}\Modules\NetUseAuthentification\NetUseAuthentification.psm1"
        target = "{{MODULESBASE}}\NetUseAuthentification\NetUseAuthentification.psm1"
    }
    ParallelRemotingJobs = @{
        source = "{{REPOSITORY}}\Modules\ParallelRemoting\ParallelRemotingJobs.psm1"
        target = "{{MODULESBASE}}\ParallelRemoting\ParallelRemotingJobs.psm1"
    }
    ParallelRemotingRunspaces = @{
        source = "{{REPOSITORY}}\Modules\ParallelRemoting\ParallelRemotingRunspaces.psm1"
        target = "{{MODULESBASE}}\ParallelRemoting\ParallelRemotingRunspaces.psm1"
    }
    ParamNormalization = @{
        source = "{{REPOSITORY}}\Modules\ParamNormalization\ParamNormalization.psm1"
        target = "{{MODULESBASE}}\ParamNormalization\ParamNormalization.psm1"
    }
    PlaceholderResolver = @{
        source = "{{REPOSITORY}}\Modules\PlaceholderResolver\PlaceholderResolver.psm1"
        target = "{{MODULESBASE}}\PlaceholderResolver\PlaceholderResolver.psm1"
    }
    ProgressBar = @{
        source = "{{REPOSITORY}}\Modules\ProgressBar\ProgressBar.psm1"
        target = "{{MODULESBASE}}\ProgressBar\ProgressBar.psm1"
    }
    ProxyPlaceholderResolver = @{
        source = "{{REPOSITORY}}\Modules\ProxyPlaceholderResolver\ProxyPlaceholderResolver.psm1"
        target = "{{MODULESBASE}}\ProxyPlaceholderResolver\ProxyPlaceholderResolver.psm1"
    }
    ReadMacAddress = @{
        source = "{{REPOSITORY}}\Modules\ReadMacAddress\ReadMacAddress.psm1"
        target = "{{MODULESBASE}}\ReadMacAddress\ReadMacAddress.psm1"
    }
    RedirectAwareApiRequest = @{
        source = "{{REPOSITORY}}\Modules\RedirectAwareApiRequest\RedirectAwareApiRequest.psm1"
        target = "{{MODULESBASE}}\RedirectAwareApiRequest\RedirectAwareApiRequest.psm1"
    }
    RemoteContextInjector = @{
        source = "{{REPOSITORY}}\Modules\RemoteContextInjector\RemoteContextInjector.psm1"
        target = "{{MODULESBASE}}\RemoteContextInjector\RemoteContextInjector.psm1"
    }
    RemoteDesktopProcess = @{
        source = "{{REPOSITORY}}\Modules\RemoteDesktopProcess\RemoteDesktopProcess.psm1"
        target = "{{MODULESBASE}}\RemoteDesktopProcess\RemoteDesktopProcess.psm1"
    }
    RemoteModuleDeployment = @{
        source = "{{REPOSITORY}}\Modules\RemoteModuleDeployment\RemoteModuleDeployment.psm1"
        target = "{{MODULESBASE}}\RemoteModuleDeployment\RemoteModuleDeployment.psm1"
    }
    RemoteMountNetDrive = @{
        source = "{{REPOSITORY}}\Modules\RemoteMountNetDrive\RemoteMountNetDrive.psm1"
        target = "{{MODULESBASE}}\RemoteMountNetDrive\RemoteMountNetDrive.psm1"
    }
    RemoveZoneIdentifier = @{
        source = "{{REPOSITORY}}\Modules\RemoveZoneIdentifier\RemoveZoneIdentifier.psm1"
        target = "{{MODULESBASE}}\RemoveZoneIdentifier\RemoveZoneIdentifier.psm1"
    }
    RestApiWrapper = @{
        source = "{{REPOSITORY}}\Modules\RestApiWrapper\RestApiWrapper.psm1"
        target = "{{MODULESBASE}}\RestApiWrapper\RestApiWrapper.psm1"
    }
    RunspaceJob = @{
        source = "{{REPOSITORY}}\Modules\RunspaceJob\RunspaceJob.psm1"
        target = "{{MODULESBASE}}\RunspaceJob\RunspaceJob.psm1"
    }
    ScriptVersionGuard = @{
        source = "{{REPOSITORY}}\Modules\ScriptVersionGuard\ScriptVersionGuard.psm1"
        target = "{{MODULESBASE}}\ScriptVersionGuard\ScriptVersionGuard.psm1"
    }
    StationSelector = @{
        source = "{{REPOSITORY}}\Modules\StationSelector\StationSelector.psm1"
        target = "{{MODULESBASE}}\StationSelector\StationSelector.psm1"
    }
    TerminateFixRestart = @{
        source = "{{REPOSITORY}}\Modules\TerminateFixRestart\TerminateFixRestart.psm1"
        target = "{{MODULESBASE}}\TerminateFixRestart\TerminateFixRestart.psm1"
    }
    ToggleComment = @{
        source = "{{REPOSITORY}}\Modules\ToggleComment\ToggleComment.psm1"
        target = "{{MODULESBASE}}\ToggleComment\ToggleComment.psm1"
    }
    UpdateDeployment = @{
        source = "{{REPOSITORY}}\Modules\UpdateDeployment\UpdateDeployment.psm1"
        target = "{{MODULESBASE}}\UpdateDeployment\UpdateDeployment.psm1"
    }
    UserProfileUtilities = @{
        source = "{{REPOSITORY}}\Modules\UserProfileUtilities\UserProfileUtilities.psm1"
        target = "{{MODULESBASE}}\UserProfileUtilities\UserProfileUtilities.psm1"
    }
    WakeOnLan = @{
        source = "{{REPOSITORY}}\Modules\WakeOnLan\WakeOnLan.psm1"
        target = "{{MODULESBASE}}\WakeOnLan\WakeOnLan.psm1"
    }
}