function CredentialProvider {
    param (
        [Parameter(Mandatory)][object]$Context
    )

    $Context.DependencyInjector = DependencyInjector -Context $Context -Modules @('CredentialManager')

    $credXml = Get-Content -Path $Context.Config.ClientsCredPath -Raw
    $Context.credBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($credXml))

    $ScriptBlock = {
        param (
            [Parameter(Mandatory)][object]$Context
        )

        try {
            $credXml = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Context.credBase64))
            # Ensure CredentialManager is loaded
            $DI = & ([scriptblock]::Create($Context.DependencyProvider))
            Invoke-Expression (& $DI.GetContent 'CredentialManager')
            return CredentialManager -Key $Context.Config.CredentialKey -XmlString $credXml
        } catch {
            throw "CredentialProvider: Fatal error`: $_"
        }        
    }.GetNewClosure()

    return @{
        ScriptBlock = $ScriptBlock
        ArgumentList = $Context
    }
}
Export-ModuleMember -Function CredentialProvider
