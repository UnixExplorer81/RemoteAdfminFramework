function RemoteModuleDeployment {
    param (
        [Parameter(Mandatory)][object]$Context,
        [Parameter(Mandatory)][string[]]$Installable
    )

    $Context.DependencyInjector = DependencyInjector $Context -Modules @('NetUseAuthentification', 'UpdateDeployment') -Providers @('CredentialProvider', 'RemoteContextProvider')

    $ScriptBlock = {
        param(
            [Parameter(Mandatory)][object]$Context
        )
        try {
            # using NetUseAuthentification to ensure UpdateDeployment can access UNC paths of the registry
            $source = $Context.Registry.PsRegistryConfig.source
            if ($null -eq $source){
                throw "Invalid or missing PsRegistryConfig.source: $source"
            }
            if ($source -notmatch '^\\\\(?<Server>[^\\]+)\\(?<Share>[^\\]+)(\\.*)?$') {
                throw "Could not detect a server and/or share name in $source"
            }
            try {
                $DI = & ([scriptblock]::Create($Context.DependencyProvider))
            } catch {
                throw "Error while receiving DependencyProvider`: $_"
            }
            try {
                # Receive Credential
                $credential = & $DI.GetProvider 'CredentialProvider'
            } catch {
                throw "Error while receiving credential of CredentialProvider`: $_"
            }
            try {
                # Ensure NetUseAuthentification is loaded
                Invoke-Expression (& $DI.GetContent 'NetUseAuthentification')
                # SMB authentification via NetUseAuthentification
                $uncPath = "\\$($matches.Server)\$($matches.Share)"
                NetUseAuthentification -UncPath $uncPath -Credential $credential -EnableDebugging:$Context.Config.Verbose
            } catch {
                throw "Could not load module NetUseAuthentification module`: $_"
            }    
            try {
                # Receive RemoteContext
                $RemoteCtx = & $DI.GetProvider 'RemoteContextProvider'
                $Registry = $RemoteCtx.Registry.AsHashtable($Context.Installable)
            } catch {
                throw "Error while receiving RemoteContext of RemoteContextProvider`: $_"
            }
            try {
                # Ensure UpdateDeployment is loaded
                Invoke-Expression (& $DI.GetContent 'UpdateDeployment')
                [array]$job = CreateJob -Deployments $Registry
                # Trigger deployment
                UpdateDeployment -Jobs $job -EnableDebugLogging:$Context.Config.Verbose
            } catch {
                throw "Error while execution of UpdateDeployment`: $_"
            }
        } catch {
            $message = "RemoteModuleDeployment: Fatal error on $env:COMPUTERNAME`: $_"
            return @{
                Success = $false
                Message = $message
            }
        }
        $message = "Deployment on $env:COMPUTERNAME complete"
        return @{
            Success = $true
            Message = $message
        }
    }.GetNewClosure()

    return @{
        ScriptBlock = $ScriptBlock
        ArgumentList = @(@{
            Installable = $Installable
        })
    }
}
Export-ModuleMember -Function RemoteModuleDeployment
