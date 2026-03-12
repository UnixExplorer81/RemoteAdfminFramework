function RemoteContextProvider {
    param (
        [Parameter(Mandatory)][object]$Context
    )

    $Context.DependencyInjector = DependencyInjector $Context -Modules @('ProxyResolver')

    $ScriptBlock = {
        param (
            [Parameter(Mandatory)][object]$Context
        )
        try{
            $DI = & ([scriptblock]::Create($Context.DependencyProvider))
            Invoke-Expression (& $DI.GetContent 'ProxyResolver')
            $RemoteCtx = [pscustomobject]@{}
            $Resolver = ProxyResolver $RemoteCtx
            $RemoteCtx | Add-Member -NotePropertyName 'Resolver' -NotePropertyValue $Resolver
            $Resolver.RegisterCallbacks((& $Context.Registry.PlaceholderCallbacks.source))
            $Resolver.RegisterSource('CONFIG', (Import-PowerShellDataFile $Context.Registry.RemoteAdminConfig.source))
            $Config = $Resolver.CreateProxy('CONFIG', @('AsHashtable','GetKeys'))
            $RemoteCtx | Add-Member -NotePropertyName 'Config' -NotePropertyValue $Config
            $Resolver.RegisterSource('REGISTRY', (Import-PowerShellDataFile $Context.Registry.PsRegistryConfig.source))
            $Registry = $Resolver.CreateProxy('REGISTRY', @('AsHashtable','Filter','GetKeys','GetRecords'))
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
