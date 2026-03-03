function RemoteContextProvider {
    param (
        [Parameter(Mandatory)][object]$Context
    )

    $Context.DependencyInjector = DependencyInjector $Context -Modules @('ProxyPlaceholderResolver')

    $ScriptBlock = {
        param (
            [Parameter(Mandatory)][object]$Context
        )
        try{
            $DI = & ([scriptblock]::Create($Context.DependencyProvider))
            Invoke-Expression (& $DI.GetContent 'ProxyPlaceholderResolver')
            $RemoteCtx = [pscustomobject]@{}
            $Resolver = [ProxyPlaceholderResolver]::new()
            $RemoteCtx | Add-Member -NotePropertyName 'Resolver' -NotePropertyValue $Resolver
            $callbacks = & $Context.Registry.PlaceholderCallbacks.source
            $Resolver.RegisterCallbacks($callbacks)
            $CfgPsd = Import-PowerShellDataFile $Context.Registry.RemoteAdminConfig.source
            $Resolver.RegisterSource('CONFIG', $CfgPsd)
            $Config = $Resolver.CreateProxy('CONFIG', $RemoteCtx, @('AsHashtable','GetKeys'))
            $RemoteCtx | Add-Member -NotePropertyName 'Config' -NotePropertyValue $Config
            $RegPsd = Import-PowerShellDataFile $Context.Registry.PsRegistryConfig.source
            $Resolver.RegisterSource('REGISTRY', $RegPsd)
            $Registry = $Resolver.CreateProxy('REGISTRY', $RemoteCtx, @('AsHashtable','Filter','GetKeys','GetRecords'))
            $RemoteCtx | Add-Member -NotePropertyName 'Registry' -NotePropertyValue $Registry
            return $RemoteCtx
        } catch {
            throw "RemoteContextProvider: Fatal error`: $_"
        } 
    }.GetNewClosure()

    return @{
        ScriptBlock = $ScriptBlock
        ArgumentList = $Context
    }
}
Export-ModuleMember -Function RemoteContextProvider
