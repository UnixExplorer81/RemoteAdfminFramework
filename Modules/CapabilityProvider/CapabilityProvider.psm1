class CapabilityRegistry {

    hidden [object]$Registry
    hidden [hashtable]$Cache = @{}

    CapabilityRegistry([object]$Registry) {
        $this.Registry = $Registry
    }

    [string] GetSourceCode([string] $key) {
        if (-not $this.Registry.Keys -contains $key) {
            throw "Unknown capability key '$key'"
        }
        if(-not $this.Cache.Keys -contains $key) {
            $this.Cache[$key] = Get-Content -Path ($this.Registry[$key].source) -Raw -Encoding UTF8
        }
        return $this.Cache[$key]
    }

    [hashtable] GetCapabilities([string[]] $keys) {
        $c = @{}
        foreach ($key in $keys) {
            $c[$key] = $this.GetSourceCode($key)
        }
        return $c
    }
}

function DependencyProvider {
    param (
        [Parameter(Mandatory)][object]$Context
    )
    $Scriptblock = {
        param($Context)
        $CapabilityRegistry = [CapabilityRegistry]::new($Context.Registry)
        return @{
            DependencyInjector = {                
                $scriptBlock = if ($Context.DependencyProvider.ScriptBlock -is [scriptblock]) {
                    $Context.DependencyProvider.ScriptBlock
                } elseif ($Context.DependencyProvider.ScriptBlock -is [string]) {
                    [scriptblock]::Create($Context.DependencyProvider.ScriptBlock)
                }
                return & $scriptBlock $Context.DependencyProvider.ArgumentList
            }
            ImportModule = {
                param($Name)
                try {
                    if(-not $Context.Keys -contains 'Capabilities') {
                        $Context.Capabilities = @{}
                    }
                    if (-not $Context.Capabilities.Keys -contains $Name) {
                        $Context.Capabilities.$Name = $CapabilityRegistry.GetSourceCode($Name)
                    }
                    $c = $Context.Capabilities.$Name
                    if ($c -is [string]) {
                        & ([scriptblock]::Create($c))
                    } else {
                        throw "Invalid capability type: $($c.GetType().FullName)"
                    }
                } catch {
                    throw [System.Exception]::new(
                        "CapabilityProvider->DependencyProvider->ImportModule: Fatal error while importing module '$Name': " ,
                        $_.Exception
                    )
                }
            }
            InjectProvider = {
                param($Name)
                try {
                    if(-not $Context.Keys -contains 'Providers') {
                        $Context.Providers = @{}
                    }
                    if (-not $Context.Providers.Keys -contains $Name) {
                        $c = $CapabilityRegistry.GetSourceCode($Name)
                        if ($c -is [string]) {
                            $Context.Providers.$Name = & ([scriptblock]::Create($c)) $Context
                        } else {
                            throw "Invalid capability type: $($c.GetType().FullName)"
                        }
                    }
                    $p = $Context.Providers.$Name
                    if ($p -is [hashtable] -and $p.Keys -contains 'ScriptBlock' -and $p.Keys -contains 'ArgumentList') {
                        $scriptBlock =
                            if ($p.ScriptBlock -is [scriptblock]) {
                                $p.ScriptBlock
                            } elseif ($p.ScriptBlock -is [string]) {
                                [scriptblock]::Create($p.ScriptBlock)
                            }
                        return & $scriptBlock $p.ArgumentList
                    } else {
                        throw "Invalid provider type: $($p.GetType().FullName)"
                    }
                } catch {
                    $innerMsg = if ($_.Exception) { $_.Exception.Message } else { $Error[0].ToString() }
                    throw [System.Exception]::new(
                        "CapabilityProvider->DependencyProvider->InjectProvider: Fatal error while invoking provider '$Name': $innerMsg",
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

function DependencyInjector {
    param (
        [Parameter(Mandatory)][object]$Capabilities
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
# function DependencyProvider {
#     param (
#         [Parameter(Mandatory)][object]$Context
#     )
#     $CapabilityRegistry = [CapabilityRegistry]::new($Context.Registry)
#     return @{
#         ImportModule = {
#             param($Name)
#             try {
#                 if(-not $Context.Keys -contains 'Capabilities') {
#                     $Context.Capabilities = @{}
#                 }
#                 if (-not $Context.Capabilities.Keys -contains $Name) {
#                     $Context.Capabilities.$Name = $CapabilityRegistry.GetSourceCode($Name)
#                 }
#                 $c = $Context.Capabilities.$Name
#                 Import-Module Debugger
#                 Inspect $c
#                 if ($c -is [string]) {
#                     & ([scriptblock]::Create($c))
#                     return $c
#                 } else {
#                     throw "Invalid capability type: $($c.GetType().FullName)"
#                 }
#             } catch {
#                 throw [System.Exception]::new(
#                     "CapabilityProvider->DependencyProvider->ImportModule: Fatal error while importing module '$Name': " ,
#                     $_.Exception
#                 )
#             }
#         }
#         InjectProvider = {
#             param($Name)
#             try {
#                 if(-not $Context.Keys -contains 'Providers') {
#                     $Context.Providers = @{}
#                 }
#                 if (-not $Context.Providers.Keys -contains $Name) {
#                     $c = $CapabilityRegistry.GetSourceCode($Name)
#                     if ($c -is [string]) {
#                         $Context.Providers.$Name = & ([scriptblock]::Create($c)) $Context
#                     } else {
#                         throw "Invalid capability type: $($c.GetType().FullName)"
#                     }
#                 }
#                 $p = $Context.Providers.$Name
#                 if ($p -is [hashtable] -and $p.Keys -contains 'ScriptBlock' -and $p.Keys -contains 'ArgumentList') {
#                     $scriptBlock =
#                         if ($p.ScriptBlock -is [scriptblock]) {
#                             $p.ScriptBlock
#                         } elseif ($p.ScriptBlock -is [string]) {
#                             [scriptblock]::Create($p.ScriptBlock)
#                         }
#                     return & $scriptBlock $p.ArgumentList
#                 } else {
#                     throw "Invalid provider type: $($p.GetType().FullName)"
#                 }
#             } catch {
#                 $innerMsg = if ($_.Exception) { $_.Exception.Message } else { $Error[0].ToString() }
#                 throw [System.Exception]::new(
#                     "CapabilityProvider->DependencyProvider->InjectProvider: Fatal error while invoking provider '$Name': $innerMsg",
#                     $_.Exception
#                 )
#             }
#         }
#     }
# }

# Export-ModuleMember -TypeName CapabilityRegistry
# Export-ModuleMember -Function DependencyProvider, DependencyInjector
