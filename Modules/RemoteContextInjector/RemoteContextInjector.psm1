using module CapabilityProvider

function RemoteContextInjector {
    param (
        [Parameter(Mandatory)][object]$Context
    )

    $CapabilityRegistry = [CapabilityRegistry]::new($Context.Registry)
    $dependencies = @('DetectModulesBasePath','PlaceholderCallbacks','ProxyPlaceholderResolver','UserProfileUtilities')
    $Capabilities = $CapabilityRegistry.GetCapabilities($dependencies)
    $Context.DependencyInjector = DependencyInjector -Capabilities $Capabilities 
    
    $ScriptBlock = {
        param (
            [Parameter(Mandatory)][object]$Context
        )
        try{
            & $Context.DependencyInjector 'DetectModulesBasePath'
            & $Context.DependencyInjector 'UserProfileUtilities'
            & $Context.DependencyInjector 'ProxyPlaceholderResolver'
            $RemoteCtx = [pscustomobject]@{}
            $RemoteCtx | Add-Member -NotePropertyName 'RawCode' -NotePropertyValue @{}
            $Resolver = [ProxyPlaceholderResolver]::new()
            $RemoteCtx | Add-Member -NotePropertyName 'Resolver' -NotePropertyValue $Resolver
            $callbacks = & $Context.DependencyInjector 'PlaceholderCallbacks'
            $Resolver.RegisterCallbacks($callbacks)
            $Resolver.RegisterSource('CONFIG', $Context.CfgPsd)
            $Config = $Resolver.CreateProxy('CONFIG', $RemoteCtx, @('AsHashtable','GetKeys'))
            $RemoteCtx | Add-Member -NotePropertyName 'Config' -NotePropertyValue $Config
            $RegPsd = Import-PowerShellDataFile $Config.PsRegistryConfig.source
            $Resolver.RegisterSource('REGISTRY', $RegPsd)
            $Registry = $Resolver.CreateProxy('REGISTRY', $RemoteCtx, @('AsHashtable','Filter','GetKeys','GetRecords'))
            $RemoteCtx | Add-Member -NotePropertyName 'Registry' -NotePropertyValue $Registry
            return $RemoteCtx
        } catch {
            throw "Fatal error in RemoteContextInjector module`: $_"
        } 
    }.GetNewClosure()

    return @{
        ScriptBlock = $ScriptBlock
        ArgumentList = $Context
    }
}
Export-ModuleMember -Function RemoteContextInjector
