using module CapabilityProvider

function DependencyCollector {
    param (
        [Parameter(Mandatory)][object]$Context,
        [string[]]$JobDependencies
    )

    $CapabilityRegistry = [CapabilityRegistry]::new($Context.Registry)
    $Capabilities = $CapabilityRegistry.GetCapabilities($JobDependencies)
    $DependencyProvider = DependencyProvider $Context

    $ScriptBlock = {
        param($Context)
        try {
            try {
                $scriptBlock = if ($Context.DependencyProvider.ScriptBlock -is [scriptblock]) {
                    $Context.DependencyProvider.ScriptBlock
                } elseif ($Context.DependencyProvider.ScriptBlock -is [string]) {
                    [scriptblock]::Create($Context.DependencyProvider.ScriptBlock)
                }
                # Executeing DependencyProvider
                $DependencyProvider = & $scriptBlock $Context.DependencyProvider.ArgumentList
            } catch {
                # throw [System.Exception]::new(
                #     "Executing DependencyProvider failed.",
                #     $_.Exception
                # )
            }  
            foreach ($module in $Context.JobDependencies) {
                try {
                    & $DependencyProvider.ImportModule $module
                } catch {
                    # throw [System.Exception]::new(
                    #     "Executing DependencyProvider.ImportModule '$module' failed.",
                    #     $_.Exception
                    # )
                }                
            }
        } catch {
            # throw [System.Exception]::new(
            #     "DependencyProvider: Fatal error",
            #     $_.Exception
            # )
        }
    }.GetNewClosure()

    return @{
        ScriptBlock  = $ScriptBlock
        ArgumentList = @(@{
            Capabilities = $Capabilities
            JobDependencies = $JobDependencies
            DependencyProvider = $DependencyProvider
        })
    }
}

function DependencyCollector2 {
    param (
        [Parameter(Mandatory)][object]$Context,
        [string[]]$JobDependencies
    )

    $CapabilityRegistry = [CapabilityRegistry]::new($Context.Registry)
    $Capabilities = $CapabilityRegistry.GetCapabilities($JobDependencies)
    $DependencyInjector = DependencyInjector -Capabilities $Capabilities

    $ScriptBlock = {
        param($Context)
        foreach ($module in $Context.JobDependencies) {
            & $Context.DependencyInjector $module
        }
    }.GetNewClosure()

    return @{
        ScriptBlock  = $ScriptBlock
        ArgumentList = @(@{
            JobDependencies = $JobDependencies
            DependencyInjector = $DependencyInjector
        })
    }
}

Export-ModuleMember -Function DependencyCollector
