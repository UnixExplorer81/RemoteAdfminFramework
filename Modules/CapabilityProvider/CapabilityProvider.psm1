class CapabilityRegistry {
    [hashtable]$Registry

    CapabilityRegistry([hashtable]$registry) {
        $this.Registry = $registry
    }

    hidden [string] GetSourceCode([string] $key) {
        if (-not $this.Registry.ContainsKey($key)) {
            throw "Unknown capability key '$key'"
        }
        return Get-Content -Path ($this.Registry[$key].source) -Raw -Encoding UTF8
    }

    [hashtable] GetCapabilities([string[]] $keys) {
        $c = @{}
        foreach ($key in $keys) {
            $c[$key] = $this.GetSourceCode($key)
        }
        return $c
    }
}

function DependencyInjector {
    param (
        [Parameter(Mandatory)][hashtable]$Capabilities
    )
    $cache = @{}
    $ScriptBlock = {
        param($Name, $ArgumentList = @())
        if (-not $Capabilities.ContainsKey($Name)) {
            throw "Capability '$Name' not found"
        }
        if (-not $cache.ContainsKey($Name)) {
            $cache[$Name] = $Capabilities[$Name]
        }
        $d = $cache[$Name]
        if ($d -is [hashtable]) {
            $sb = if ($d.ScriptBlock -is [scriptblock]) {
                $d.ScriptBlock
            } elseif ($d.ScriptBlock -is [string]) {
                [scriptblock]::Create($d.ScriptBlock)
            } else {
                throw "DependencyProvider->DependencyInjector: Unexpected type $($d.GetType().Name)"
            }
            return & $sb $d.ArgumentList
        } elseif ($d -is [string]) {
            & ([scriptblock]::Create($d)) @($ArgumentList)
            return $d
        } else {
            throw "DependencyProvider->DependencyInjector: Unexpected type $($d.GetType().Name)"
        }
    }.GetNewClosure()

    return $ScriptBlock
}

function DependencyProvider {
    param (
        [Parameter(Mandatory)][hashtable]$Context
    )
    Import-Module Debugger
    Inspect $Context.Capabilities
    $Scriptblock = {
        param($Context)
        return @{
            ImportModule = {
                param($Name, $ArgumentList = @())
                try {
                    if (-not $Context.Capabilities.ContainsKey($Name)) {
                        throw "Capability '$Name' not found"
                    }
                    $c = $Context.Capabilities[$Name]
                    if ($c -is [string]) {
                        & ([scriptblock]::Create($c)) @($ArgumentList)
                        return $c
                    } else {
                        throw "Invalid capability type: $($c.GetType().Name)"
                    }
                } catch {
                    throw [System.Exception]::new(
                        "CapabilityProvider->DependencyProvider->ImportModule: Fatal error while importing module '$name': " ,
                        $_.Exception
                    )
                }
            }
            InjectProvider = {
                param($Name)
                try {
                    if (-not $Context.Providers.ContainsKey($Name)) {
                        throw "Capability '$Name' not found"
                    }
                    $p = $Context.Providers.$Name
                    if ($p -is [hashtable] -and $p.ContainsKey('ScriptBlock') -and $p.ContainsKey('ArgumentList')) {
                        $scriptBlock =
                            if ($p.ScriptBlock -is [scriptblock]) {
                                $p.ScriptBlock
                            } elseif ($p.ScriptBlock -is [string]) {
                                [scriptblock]::Create($p.ScriptBlock)
                            }
                        return & $scriptBlock $p.ArgumentList
                    } else {
                        throw "Invalid provider type: $($p.GetType().Name)"
                    }
                } catch {
                    $innerMsg = if ($_.Exception) { $_.Exception.Message } else { $Error[0].ToString() }
                    throw [System.Exception]::new(
                        "CapabilityProvider->DependencyProvider->InjectProvider: Fatal error while invoking provider '$name': $innerMsg",
                        $_.Exception
                    )
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

# Export-ModuleMember -TypeName CapabilityRegistry
# Export-ModuleMember -Function DependencyProvider, DependencyInjector
