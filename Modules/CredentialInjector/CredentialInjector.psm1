using module CapabilityProvider

function CredentialInjector {
    param (
        [Parameter(Mandatory)][object]$Context
    )

    $CapabilityRegistry = [CapabilityRegistry]::new($Context.Registry)
    $dependencies = @('CredentialManager')
    $Context.Capabilities = $CapabilityRegistry.GetCapabilities($dependencies)
    $Context.DependencyProvider = DependencyProvider $Context 
    
    $credXml = Get-Content -Path $Context.Config.ClientsCredPath -Raw
    $Context.credBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($credXml))

    $ScriptBlock = {
        param (
            [Parameter(Mandatory)][object]$Context
        )
        try {
            $scriptBlock = if ($Context.DependencyProvider.ScriptBlock -is [scriptblock]) {
                $Context.DependencyProvider.ScriptBlock
            } elseif ($Context.DependencyProvider.ScriptBlock -is [string]) {
                [scriptblock]::Create($Context.DependencyProvider.ScriptBlock)
            }
            $DependencyProvider = & $scriptBlock $Context.DependencyProvider.ArgumentList

            Invoke-Expression (& $DependencyProvider.ImportModule 'CredentialManager')
            return CredentialManager -Key $Context.Config.CredentialKey -XmlString $credXml
        } catch {
            throw "CredentialInjector: Fatal error: $_"
        }        
    }.GetNewClosure()

    return @{
        ScriptBlock = $ScriptBlock
        ArgumentList = $Context
    }
}
function CredentialInjector2 {
    param (
        [Parameter(Mandatory)][object]$Context
    )

    $credXml = Get-Content -Path $Context.Config.ClientsCredPath -Raw
    $Context.credBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($credXml))

    $ScriptBlock = {
        param (
            [Parameter(Mandatory)][object]$Context
        )
        try {
            $credXml = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Context.credBase64))
            # Ensure CredentialManager is loaded
            & $Context.DependencyInjector 'CredentialManager'
            return CredentialManager -Key $Context.Config.CredentialKey -XmlString $credXml
        } catch {
            throw "CredentialInjector: Fatal error`: $_"
        }        
    }.GetNewClosure()

    return @{
        ScriptBlock = $ScriptBlock
        ArgumentList = $Context
    }
}
Export-ModuleMember -Function CredentialInjector
