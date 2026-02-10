using module ProxyPlaceholderResolver
using module InteractiveSync

$serverModules = "\\topcall.inc\shares\PowerShell_Framework$\Modules"
$localModules = "$($env:USERPROFILE)\Documents\PowerShell\Modules"

function InteractiveSyncWaitingForEnter {
    InteractiveSync -ServerPath $serverModules -LocalPath $localModules -OnlyLocalModules -Verbose
}

function SyncModulesOnDemand {
    Sync -ServerPath $serverModules -LocalPath $localModules -OnlyLocalModules -Verbose
}

function SyncAppDataOnDemand {
    $Resolver = [ProxyPlaceholderResolver]::new()
    $Context = [pscustomobject]@{
        Resolver = $Resolver
    }
    $callbacks = & 'C:\ProgramData\PowerShell\PlaceholderCallbacks.ps1'
    $Resolver.RegisterCallbacks($callbacks)
    $CfgPsd = Import-PowerShellDataFile "C:\ProgramData\PowerShell\RemoteAdminTools\Config.psd1"
    $Resolver.RegisterSource('CONFIG', $CfgPsd)
    $Config = $Resolver.CreateProxy('CONFIG', $Context, @('AsHashtable'))
    $Context | Add-Member -NotePropertyName 'Config' -NotePropertyValue $Config
    $RegPsd = Import-PowerShellDataFile $Config.PsRegistryConfig.target
    $Resolver.RegisterSource('REGISTRY', $RegPsd)
    $Registry = $Resolver.CreateProxy('REGISTRY', $Context, $null)
    Sync -FileMap @{
        # Starter
        RemoteAdminBootstrapping = $Registry.RemoteAdminBootstrapping
        RemoteAdminRestApi = $Registry.RemoteAdminRestApi
        RemoteAdminTools = $Registry.RemoteAdminTools
        # Configs
        InteractiveSync = $Registry.InteractiveSync
        RemoteAdminData = $Registry.RemoteAdminData
        PsRegistryConfig = $Registry.PsRegistryConfig
        RemoteAdminConfig = $Registry.RemoteAdminConfig
        PlaceholderCallbacks = $Registry.PlaceholderCallbacks
        DomainAccountsApiConfig = $Registry.DomainAccountsApiConfig
    } -Verbose
}
