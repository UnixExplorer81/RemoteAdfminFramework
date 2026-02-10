using module CapabilityProvider

function RemoteModuleDeployment {
    param (
        [Parameter(Mandatory)][object]$Context,
        [Parameter(Mandatory)][string[]]$TaskRequires
    )

    # Inject Credential
    # diese imports koennen jetzt bereits durch DependencyCollector durchgefuehrt werden
    Import-Module CredentialInjector -Force
    $CredentialInjector = CredentialInjector -Context $Context

    # Inject RemoteContext
    Import-Module RemoteContextInjector -Force
    $RemoteContextInjector = RemoteContextInjector -Context $Context

    $dependencies = @('CredentialManager','NetUseAuthentification','UpdateDeployment')
    $CapabilityRegistry = [CapabilityRegistry]::new($Context.Registry)
    $Capabilities = $CapabilityRegistry.GetCapabilities($dependencies)
    $Capabilities.CredentialInjector = $CredentialInjector
    $Capabilities.RemoteContextInjector = $RemoteContextInjector
    # foreach ($k in @('CredentialInjector','RemoteContextInjector')) {
    #     $Capabilities[$k] = Get-Variable $k -ValueOnly
    # }
    $DependencyInjector = DependencyInjector -Capabilities $Capabilities 

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
                # hier vor der verwendung von CredentialInjector im RemoteContext koennte ich dynamisch diverse imports mithilfe von $Context.dependencies durchfuehren, genau wie im scriptblockk von DependencyCollector
                # Receive Credential
                $credential = & $Context.DependencyInjector 'CredentialInjector'
            } catch {
                throw "Error while receiving credential of CredentialInjector module`: $_"
            }
            try {
                # Ensure NetUseAuthentification is loaded
                & $Context.DependencyInjector 'NetUseAuthentification'
                # SMB authentification via NetUseAuthentification
                $uncPath = "\\$($matches.Server)\$($matches.Share)"
                NetUseAuthentification -UncPath $uncPath -Credential $credential -EnableDebugging:$Context.Config.Verbose
            } catch {
                throw "Could not load module NetUseAuthentification module`: $_"
            }    
            try {
                # Receive RemoteContext
                $RemoteCtx = & $Context.DependencyInjector 'RemoteContextInjector'
                $Registry = $RemoteCtx.Registry.AsHashtable($Context.TaskRequires)
            } catch {
                throw "Error while receiving RemoteContext of RemoteContextInjector module`: $_"
            }
            try {
                # Ensure UpdateDeployment is loaded
                & $Context.DependencyInjector 'UpdateDeployment'
                # Trigger deployment
                UpdateDeployment -Jobs (,(CreateJob -Deployments $Registry)) -EnableDebugLogging:$Context.Config.Verbose
            } catch {
                throw "Error while execution of UpdateDeployment module`: $_"
            }
        } catch {
            $message = "Fatal error on $env:COMPUTERNAME`: $_"
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
            TaskRequires = $TaskRequires
            DependencyInjector = $DependencyInjector
        })
    }
}
Export-ModuleMember -Function RemoteModuleDeployment
