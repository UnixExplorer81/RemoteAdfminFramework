function CapabilityInjector {
    param (
        [Parameter(Mandatory)][object]$Context
    )

    $Scriptblock = {
        param($Context)
        return @{
            ProvideInMemory = {
                param($Provider)
                if (Get-Command $Provider -ErrorAction SilentlyContinue) {
                    Import-Module $Provider -Force
                    return
                }
                if (-not $Context.RawCode.ContainsKey($Provider)) {
                    throw "RawCode for provider '$Provider' not found"
                }                
                return $Context.RawCode.$Provider
            }
            InvokeCapabilityProvider = {
                param($Name)
                if (-not $Context.$Name) {
                    throw "Capability '$Name' not found in Context"
                }
                $provider = $Context.$Name
                if (-not $provider.ScriptBlock) {
                    throw "Capability '$Name' has no ScriptBlock"
                }
                try {
                    $scriptBlock =
                        if ($provider.ScriptBlock -is [scriptblock]) {
                            $provider.ScriptBlock
                        }
                        elseif ($provider.ScriptBlock -is [string]) {
                            [scriptblock]::Create($provider.ScriptBlock)
                        }
                        else {
                            throw "Invalid ScriptBlock type: $($provider.ScriptBlock.GetType().Name)"
                        }
                    return & $scriptBlock $provider.ArgumentList
                }
                catch {
                    throw "Error while invoking capability '$Name': $_"
                }
            }
        }
    }.GetNewClosure()

    return @{
        ScriptBlock = $ScriptBlock
        ArgumentList = @(@{
            Context = $Context
        })
    }
}