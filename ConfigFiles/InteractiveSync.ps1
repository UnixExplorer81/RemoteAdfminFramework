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
    $Context = [pscustomobject]@{}
    $Resolver = ProxyResolver $Context
    $Context | Add-Member -NotePropertyName 'Resolver' -NotePropertyValue $Resolver
    $Resolver.RegisterCallbacks((& 'C:\ProgramData\PowerShell\PsRemoteAdminFramework\PsCallbacks.ps1'))
    $Resolver.RegisterSource('CONFIG', (Import-PowerShellDataFile "C:\ProgramData\PowerShell\PsRemoteAdminFramework\Config.psd1"))
    $Config = $Resolver.CreateProxy('CONFIG', @('AsHashtable'))
    $Context | Add-Member -NotePropertyName 'Config' -NotePropertyValue $Config
    $Resolver.RegisterSource('REGISTRY', (Import-PowerShellDataFile $Config.PsRegistryConfig.target))
    $Registry = $Resolver.CreateProxy('REGISTRY', $null)
    Sync -FileMap @{
        # Starter
        PsRemoteAdminFramework = $Registry.PsRemoteAdminFramework
        RemoteAdminRestApi = $Registry.RemoteAdminRestApi
        # Configs
        PsCallbacks = $Registry.PsCallbacks
        InteractiveSync = $Registry.InteractiveSync
        RemoteAdminData = $Registry.RemoteAdminData
        PsRegistryConfig = $Registry.PsRegistryConfig
        RemoteAdminConfig = $Registry.RemoteAdminConfig
        DomainAccountsApiConfig = $Registry.DomainAccountsApiConfig
    } -Verbose
}
