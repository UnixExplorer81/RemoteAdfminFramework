using module CapabilityProvider

function RemoteModuleDeployment {
    param (
        [Parameter(Mandatory)][object]$Context,
        [Parameter(Mandatory)][string[]]$TaskRequires
    )

    # Inject Credential
    Import-Module CredentialInjector -Force
    $CredentialInjector = CredentialInjector -Context $Context

    $CapabilityRegistry = [CapabilityRegistry]::new($Context.Registry)
    $dependencies = @('CredentialManager','Debugger','MountPsDrive')
    $Capabilities = $CapabilityRegistry.GetScriptBlocks($dependencies)
    $Capabilities.CredentialInjector = $CredentialInjector
    $CapabilityInjector = CapabilityInjector -Capabilities $Capabilities 

    $ScriptBlock = {
        param(
            [Parameter(Mandatory)][hashtable]$Context
        )
        try {
            # Ensure MountPsDrive is loaded
            if (-not ([System.Management.Automation.PSTypeName]'MountPsDrive').Type) {
                & $Context.CapabilityInjector 'MountPsDrive'
            }
            if ($Context.Registry.PsRegistryConfig.source.ToUpper() -match '^\\\\(?<Server>[^\\]+)\\(?<Share>[^\\]+)(\\.*)?$') {
                $uncPath = "\\$($matches.Server)\$($matches.Share)"
                try {
                    # Receive Credential
                    $credential = & $Context.CapabilityInjector 'CredentialInjector'
                } catch {
                    throw "Error while receiving credential of CredentialInjector module`: $_"
                }
                $null = [MountPsDrive]::new(@{
                    UNCPath = $uncPath
                    Credential = $credential
                })
            } else{
                throw "Could not detect a server and/or share name in $($Context.Registry.PsRegistryConfig.source)"
            }
        } catch {
            return "Fatal error on $env:COMPUTERNAME`: $_"
        }
        return $true
    }.GetNewClosure()

    return @{
        ScriptBlock = $ScriptBlock
        ArgumentList = @(@{
            CapabilityInjector = $CapabilityInjector
        })
    }
}