using module RawCode
function InjectPsRegistry {
    param (
        [Parameter(Mandatory)][object]$Context
    )

    $dependencies = @('CredentialManager','NetUseAuthentification','PlaceholderCallbacks','ProxyPlaceholderResolver')
    $Raw = [RawCode]::new([hashtable]$Context.Registry)
    $Context.rawCode = $Raw.GetCode($dependencies)

    $ScriptBlock = {
        param (
            [Parameter(Mandatory)][hashtable]$Context
        )
        # Ensure PsRegistry is loaded
        if (-not (Get-Command PsRegistry -ErrorAction SilentlyContinue)) {
            # Invoke-Expression (Get-Content $Context.Registry.PsRegistry.source -Raw) # previous smb authentification necessary
            Invoke-Expression $Context.RawCode.PsRegistry
        }
        
        # Reinitialize Registry (ensures paths match to the remote computer)
        return [PsRegistry]::new($Context.Registry.PsRegistryConfig)
    }.GetNewClosure()
    return @{
        ScriptBlock = $ScriptBlock
        ArgumentsList = $Context
    }
}