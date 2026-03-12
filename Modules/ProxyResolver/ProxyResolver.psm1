# ProxyResolver.psm1 - functionbased, instance like Implementation
function ProxyResolver {
    param([pscustomobject]$Context)

    # create resolver object that holds shared state and methods
    $resolver = [pscustomobject]@{
        Sources   = @{}
        Callbacks = @{}
        Context   = $null
    }

    $resolver.Context = if ($null -ne $Context) { $Context } else { $null }

    # -------------------------
    # Helper: CreateProxyRecursive (internal)
    # Implemented as ScriptMethod so it can use $this (the resolver) and call itself
    $createProxyRecursive = {
        param([string]$qualId, [hashtable]$entries, [scriptblock]$callback, [string[]]$AddMethods)

        # freeze locals for clarity (use $this for resolver state)
        $resolverThis = $this

        $proxy = New-Object PSObject
        $proxy | Add-Member -NotePropertyName '__proxy_sourceId' -NotePropertyValue $qualId -Force
        $proxy | Add-Member -NotePropertyName '__proxy_cache' -NotePropertyValue (New-Object System.Collections.Hashtable) -Force

        foreach ($k in $entries.Keys) {
            $val = $entries[$k]

            # --- nested hashtable -> lazy nested proxy ---
            if ($val -is [hashtable]) {
                # freeze iteration locals
                $iter_propName      = $k
                $iter_propVal       = $val
                $iter_callbackLocal = $callback
                $iter_qualId        = $qualId
                $iter_composedId    = "$iter_qualId.$iter_propName"

                $nestedGetter = {
                    param()
                    if (-not $this.__proxy_cache) { $this.__proxy_cache = @{} }
                    if ($this.__proxy_cache.ContainsKey($iter_propName)) { return $this.__proxy_cache[$iter_propName] }

                    # choose registered composed source or fallback to nested hashtable
                    $nestedEntries = $null
                    $nestedCb = $iter_callbackLocal
                    if ($this.PSObject.Properties.Match('__proxy_sourceId')) { } # noop to keep $this in closure

                    if ($resolverThis.Sources.ContainsKey($iter_composedId)) {
                        $nestedEntries = $resolverThis.Sources[$iter_composedId]
                        if ($resolverThis.Callbacks.ContainsKey($iter_composedId)) { $nestedCb = $resolverThis.Callbacks[$iter_composedId] }
                    } else {
                        $nestedEntries = $iter_propVal
                    }

                    # build nested proxy and cache it (pass live context)
                    $nestedProxy = $resolverThis._CreateProxyRecursive($iter_composedId, $nestedEntries, $nestedCb, $null)
                    $this.__proxy_cache[$iter_propName] = $nestedProxy
                    return $nestedProxy
                }.GetNewClosure()

                $scriptPropNested = New-Object System.Management.Automation.PSScriptProperty($k, $nestedGetter)
                $proxy.PSObject.Properties.Add($scriptPropNested) | Out-Null
                continue
            }

            # --- array handling ---
            if ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) {
                $iter_propName      = $k
                $iter_propVal       = $val
                $iter_callbackLocal = $callback
                $iter_qualId        = $qualId

                # $arrayGetter = {
                #     param()
                #     if (-not $this.__proxy_cache) { $this.__proxy_cache = @{} }
                #     if ($this.__proxy_cache.ContainsKey($iter_propName)) { return $this.__proxy_cache[$iter_propName] }

                #     # Lokaler, rekursiver Helfer (keine Proxy‑Property, direkte Rekursion)
                #     $resolveElement = {
                #         param($element)

                #         # String mit Platzhaltern
                #         if ($element -is [string]) {
                #             return $resolverThis.ResolveStringPlaceholders($element, $resolverThis.Context)
                #         }

                #         # Scriptblock ausführen (mit Context wenn möglich)
                #         if ($element -is [scriptblock]) {
                #             try { return & $element $resolverThis.Context } catch { try { return & $element } catch { return $null } }
                #         }

                #         # Hashtable oder PSCustomObject -> nested proxy erzeugen
                #         if ($element -is [hashtable] -or $element -is [System.Management.Automation.PSObject]) {
                #             $elemComposedId = "$iter_qualId.$iter_propName"
                #             if ($resolverThis.Sources.ContainsKey($elemComposedId)) {
                #                 $elemEntries = $resolverThis.Sources[$elemComposedId]
                #                 $elemCb = if ($resolverThis.Callbacks.ContainsKey($elemComposedId)) { $resolverThis.Callbacks[$elemComposedId] } else { $iter_callbackLocal }
                #                 return $resolverThis._CreateProxyRecursive($elemComposedId, $elemEntries, $elemCb, $null)
                #             } else {
                #                 return $resolverThis._CreateProxyRecursive("$iter_qualId.$iter_propName", $element, $iter_callbackLocal, $null)
                #             }
                #         }

                #         # Enumerable (mehrdimensionale Arrays) -> rekursiv Elemente auflösen
                #         if ($element -is [System.Collections.IEnumerable] -and -not ($element -is [string])) {
                #             $sub = @()
                #             foreach ($e in $element) {
                #                 $sub += & $resolveElement $e
                #             }
                #             return $sub
                #         }

                #         # Fallback: unverändert übernehmen
                #         return $element
                #     }.GetNewClosure()

                #     $outList = @()
                #     foreach ($item in $iter_propVal) {
                #         $outList += & $resolveElement $item
                #     }

                #     # cache array (store as plain array)
                #     $this.__proxy_cache[$iter_propName] = $outList
                #     return $outList
                # }.GetNewClosure()

                $arrayGetter = {
                    param()
                    if (-not $this.__proxy_cache) { $this.__proxy_cache = @{} }
                    if ($this.__proxy_cache.ContainsKey($iter_propName)) { return $this.__proxy_cache[$iter_propName] }

                    $outList = @()
                    foreach ($item in $iter_propVal) {
                        if ($item -is [string]) {
                            $outList += $resolverThis._ResolveStringPlaceholders($item, $resolverThis.Context)
                        } elseif ($item -is [hashtable]) {
                            $elemComposedId = "$iter_qualId.$iter_propName"
                            if ($resolverThis.Sources.ContainsKey($elemComposedId)) {
                                $elemEntries  = $resolverThis.Sources[$elemComposedId]
                                $elemCb = if ($resolverThis.Callbacks.ContainsKey($elemComposedId)) { $resolverThis.Callbacks[$elemComposedId] } else { $iter_callbackLocal }
                                $outList += $resolverThis._CreateProxyRecursive($elemComposedId, $elemEntries, $elemCb, $null)
                            } else {
                                $outList += $resolverThis._CreateProxyRecursive("$iter_qualId.$iter_propName", $item, $iter_callbackLocal, $null)
                            }
                        } else {
                            $outList += $item
                        }
                    }

                    $this.__proxy_cache[$iter_propName] = ,$outList
                    return ,$outList
                }.GetNewClosure()

                $scriptPropArray = New-Object System.Management.Automation.PSScriptProperty($k, $arrayGetter)
                $proxy.PSObject.Properties.Add($scriptPropArray) | Out-Null
                continue
            }

            # --- scalar / string / scriptblock property ---
            $propName      = $k
            $propVal       = $val
            $callbackLocal = $callback

            $get = {
                param()
                if (-not $this.__proxy_cache) { $this.__proxy_cache = @{} }
                if ($this.__proxy_cache.ContainsKey($propName)) { return $this.__proxy_cache[$propName] }

                $resolved = $null

                if ($propVal -is [string] -and $propVal -match '\{\{[^}]+\}\}') {
                    try { $resolved = $resolverThis._ResolveStringPlaceholders($propVal, $resolverThis.Context) } catch { $resolved = $null }
                }

                if (($null -eq $resolved -or $resolved -eq $propVal) -and $callbackLocal) {
                    try { $resolved = & $callbackLocal $propName $resolverThis.Context } catch {}
                    if (-not $resolved) { try { $resolved = & $callbackLocal $resolverThis.Context } catch {} }
                    if (-not $resolved) { try { $resolved = & $callbackLocal $propName } catch {} }
                    if (-not $resolved) { try { $resolved = & $callbackLocal } catch {} }
                }

                if ($null -eq $resolved) { $resolved = $propVal }

                # normalizer
                $convert = {
                    param($raw)
                    if ($raw -is [scriptblock]) {
                        try { $raw = & $raw $resolverThis.Context } catch { try { $raw = & $raw } catch { $raw = $null } }
                    }
                    if ($raw -is [System.Management.Automation.PSCustomObject] -or $raw -is [hashtable]) { return $raw }
                    if ($raw -is [bool] -or $raw -is [byte] -or $raw -is [int16] -or $raw -is [int] -or $raw -is [long] -or $raw -is [single] -or $raw -is [double] -or $raw -is [decimal]) { return $raw }
                    if ($raw -is [System.Collections.IEnumerable] -and -not ($raw -is [string])) {
                        $out = @()
                        foreach ($el in $raw) {
                            if ($el -is [scriptblock]) {
                                try { $val = & $el $resolverThis.Context } catch { try { $val = & $el } catch { $val = $null } }
                            } else { $val = $el }
                            $out += $val
                        }
                        return ,$out
                    }
                    try { return [string]$raw } catch { return $raw.ToString() }
                }.GetNewClosure()

                if (-not $this.PSObject.Members.Match('__normalize_element').Count) {
                    $normBlock = {
                        param($element)
                        if ($element -is [scriptblock]) {
                            try { $element = & $element $resolverThis.Context } catch { try { $element = & $element } catch { $element = $null } }
                        }
                        if ($element -is [System.Management.Automation.PSCustomObject] -or $element -is [hashtable]) { return $element }
                        if ($element -is [System.Collections.IEnumerable] -and -not ($element -is [string])) {
                            $arr = @()
                            foreach ($e2 in $element) { $arr += & $this.__normalize_element $e2 }
                            return ,$arr
                        }
                        try { return [string]$element } catch { return $element.ToString() }
                    }.GetNewClosure()
                    $scriptPropNorm = New-Object System.Management.Automation.PSScriptProperty('__normalize_element', $normBlock)
                    $this.PSObject.Properties.Add($scriptPropNorm) | Out-Null
                }

                $final = & $convert $resolved

                $this.__proxy_cache[$propName] = $final
                return $final
            }.GetNewClosure()

            $scriptProp = New-Object System.Management.Automation.PSScriptProperty($propName, $get)
            $proxy.PSObject.Properties.Add($scriptProp) | Out-Null
        }

        # add helper methods if requested
        $this._AddHelperMethods($proxy, $AddMethods)

        return $proxy
    }

    # -------------------------
    # ResolveStringPlaceholders helper (as ScriptMethod)
    $resolveStringPlaceholders = {
        param([string]$text)
        if (-not $text) { return $text }

        function ConvertRecursive {
            param($raw)
            if ($null -eq $raw) { return $null }
            if ($raw -is [scriptblock]) {
                try { $raw = & $raw $this.Context } catch { try { $raw = & $raw } catch { $raw = $null } }
            }
            if ($raw -is [System.Management.Automation.PSCustomObject] -or $raw -is [hashtable]) {
                try { return [string]$raw } catch { return $raw.ToString() }
            }
            if ($raw -is [System.Collections.IEnumerable] -and -not ($raw -is [string])) {
                $elems = @()
                foreach ($e in $raw) { $elems += (ConvertRecursive $e) }
                return ($elems -join ",")
            }
            try { $s = [string]$raw } catch { $s = $raw.ToString() }
            if ($s -and ($s -match '\{\{[^}]+\}\}')) { return $this._ResolveStringPlaceholders($s) }
            return $s
        }

        $pattern = '\{\{([^}]+)\}\}'
        $regex = [regex]$pattern
        $matches = $regex.Matches($text)
        if ($matches.Count -eq 0) { return $text }

        $sb = New-Object System.Text.StringBuilder
        $last = 0
        foreach ($m in $matches) {
            $sb.Append($text.Substring($last, $m.Index - $last)) | Out-Null
            $inner = $m.Groups[1].Value
            $parts = $inner.Split(":",2)
            $replacement = $null

            if ($parts.Count -eq 1) {
                $token = $parts[0]
                if ($this.Callbacks.ContainsKey($token)) {
                    $cb = $this.Callbacks[$token]
                    $val = $null
                    try { $val = & $cb $this.Context } catch {}
                    if (-not $val) { try { $val = & $cb } catch {} }
                    $replacement = ConvertRecursive $val
                }
                if (($null -eq $replacement -or $replacement -eq '') -and $this.Sources.ContainsKey($token)) {
                    $s = $this.Sources[$token]
                    if ($s -is [hashtable] -and $s.ContainsKey('Value')) { $replacement = [string]$s['Value'] }
                    elseif ($s -is [string]) { $replacement = [string]$s }
                }
            } else {
                $src = $parts[0]; $key = $parts[1]
                if ($this.Callbacks.ContainsKey($src)) {
                    $cb = $this.Callbacks[$src]
                    $val = $null
                    try { $val = & $cb $key $this.Context } catch {}
                    if (-not $val) { try { $val = & $cb $this.Context } catch {} }
                    if (-not $val) { try { $val = & $cb $key } catch {} }
                    if (-not $val) { try { $val = & $cb } catch {} }
                    $replacement = ConvertRecursive $val
                }
                if (($null -eq $replacement -or $replacement -eq '') -and $this.Sources.ContainsKey($src)) {
                    $s = $this.Sources[$src]
                    if ($s -is [System.Management.Automation.PSObject]) {
                        if ($s.PSObject.Properties.Match($key).Count -gt 0) {
                            try { $v = $s.$key } catch { $v = $null }
                            $replacement = ConvertRecursive $v
                        }
                    } elseif ($s -is [hashtable]) {
                        if ($s.ContainsKey($key)) {
                            $val = $s[$key]
                            if ($val -is [string] -and ($val -match '\{\{[^}]+\}\}')) {
                                $replacement = $this._ResolveStringPlaceholders($val, $this.Context)
                            } else {
                                $replacement = ConvertRecursive $val
                            }
                        }
                    }
                }
            }

            if ($null -eq $replacement -or $replacement -eq '') { $sb.Append($m.Value) | Out-Null } else { $sb.Append([string]$replacement) | Out-Null }
            $last = $m.Index + $m.Length
        }

        if ($last -lt $text.Length) { $sb.Append($text.Substring($last)) | Out-Null }
        return $sb.ToString()
    }

    # -------------------------
    # AddHelperMethods (as ScriptMethod)
    $addHelperMethods = {
        param([object]$proxy, [string[]]$methods)
        if (-not $methods -or $methods.Count -eq 0) { return }

        # GetRecords
        if ($methods -contains 'GetRecords' -and -not $proxy.PSObject.Members.Match('GetRecords').Count) {
            $sbGetRecords = {
                param($keys)
                if ($null -eq $keys) { $keys = @() }
                if (-not ($keys -is [System.Collections.IEnumerable]) -or ($keys -is [string])) { $keys = ,$keys }
                $parent = $this
                $out = New-Object PSObject
                $out | Add-Member -NotePropertyName '__proxy_cache' -NotePropertyValue (New-Object System.Collections.Hashtable) -Force
                foreach ($k in $keys) {
                    if (-not $k) { continue }
                    if ($parent.PSObject.Properties.Match($k).Count -eq 0) { continue }
                    $propName = $k
                    $get = {
                        param()
                        if (-not $this.__proxy_cache) { $this.__proxy_cache = @{} }
                        if ($this.__proxy_cache.ContainsKey($propName)) { return $this.__proxy_cache[$propName] }
                        $val = $parent.$propName
                        $this.__proxy_cache[$propName] = $val
                        return $val
                    }.GetNewClosure()
                    $scriptProp = New-Object System.Management.Automation.PSScriptProperty($propName, $get)
                    $out.PSObject.Properties.Add($scriptProp) | Out-Null
                }
                return $out
            }.GetNewClosure()
            $m = New-Object System.Management.Automation.PSScriptMethod('GetRecords', $sbGetRecords)
            $proxy.PSObject.Members.Add($m) | Out-Null
        }

        # Filter
        if ($methods -contains 'Filter' -and -not $proxy.PSObject.Members.Match('Filter').Count) {
            $sbFilter = {
                param($predicate)
                $parent = $this
                $keysToInclude = @()
                foreach ($p in $parent.PSObject.Properties) {
                    if ($p.Name -like '__*') { continue }
                    $val = $null
                    try { $val = $parent.$($p.Name) } catch { $val = $null }
                    $ok = $false
                    try {
                        $try = $null
                        try { $try = & $predicate $p.Name $val } catch {}
                        if ($null -eq $try) { try { $try = & $predicate $p } catch {} }
                        $ok = [bool]$try
                    } catch { $ok = $false }
                    if ($ok) { $keysToInclude += $p.Name }
                }
                $out = New-Object PSObject
                $out | Add-Member -NotePropertyName '__proxy_cache' -NotePropertyValue (New-Object System.Collections.Hashtable) -Force
                foreach ($k in $keysToInclude) {
                    $propName = $k
                    $get = {
                        param()
                        if (-not $this.__proxy_cache) { $this.__proxy_cache = @{} }
                        if ($this.__proxy_cache.ContainsKey($propName)) { return $this.__proxy_cache[$propName] }
                        $val = $parent.$propName
                        $this.__proxy_cache[$propName] = $val
                        return $val
                    }.GetNewClosure()
                    $scriptProp = New-Object System.Management.Automation.PSScriptProperty($propName, $get)
                    $out.PSObject.Properties.Add($scriptProp) | Out-Null
                }
                return $out
            }.GetNewClosure()
            $m = New-Object System.Management.Automation.PSScriptMethod('Filter', $sbFilter)
            $proxy.PSObject.Members.Add($m) | Out-Null
        }

        # AsHashtable
        if ($methods -contains 'AsHashtable' -and -not $proxy.PSObject.Members.Match('AsHashtable').Count) {
            $sbAsHashtable = {
                param($keys)
                if ($null -eq $keys) { $keys = @() }
                if (-not ($keys -is [System.Collections.IEnumerable]) -or ($keys -is [string])) { $keys = ,$keys }
                $parent = $this
                $result = @{}
                $props = $parent.PSObject.Properties | Where-Object { $_.Name -notlike '__*' } | Select-Object -ExpandProperty Name
                if ($keys.Count -gt 0) { $props = $props | Where-Object { $keys -contains $_ } }
                foreach ($p in $props) {
                    $value = $null
                    try { $value = $parent.$p } catch { $value = $null }
                    if ($value -is [System.Management.Automation.PSObject] -and $value.PSObject.Properties.Match('__proxy_sourceId').Count -gt 0) {
                        try { $value = $value.AsHashtable() } catch {
                            $plain = @{}
                            foreach ($sub in $value.PSObject.Properties) {
                                if ($sub.Name -like '__*') { continue }
                                try { $plain[$sub.Name] = $value.$($sub.Name) } catch { $plain[$sub.Name] = $sub.Value }
                            }
                            $value = $plain
                        }
                    } elseif ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
                        $arr = @()
                        foreach ($el in $value) {
                            if ($el -is [System.Management.Automation.PSObject] -and $el.PSObject.Properties.Match('__proxy_sourceId').Count -gt 0) {
                                $arr += $el.AsHashtable()
                            } else { $arr += $el }
                        }
                        $value = $arr
                    }
                    $result[$p] = $value
                }
                return $result
            }.GetNewClosure()
            $m = New-Object System.Management.Automation.PSScriptMethod('AsHashtable', $sbAsHashtable)
            $proxy.PSObject.Members.Add($m) | Out-Null
        }

        # GetKeys
        if ($methods -contains 'GetKeys' -and -not $proxy.PSObject.Members.Match('GetKeys').Count) {
            $sbKeys = {
                param()
                return ($this.PSObject.Properties | Where-Object { $_.Name -notlike '__*' } | Select-Object -ExpandProperty Name)
            }.GetNewClosure()
            $m = New-Object System.Management.Automation.PSScriptMethod('GetKeys', $sbKeys)
            $proxy.PSObject.Members.Add($m) | Out-Null
        }
    }

    # -------------------------
    # ProxyCacheReset helper (recursive)
    $proxyCacheReset = {
        if ($null -eq $this.Context) { return }
        foreach ($prop in $this.Context.PSObject.Properties) {
            if ($prop.Name -like '__*') { continue }
            $val = $null
            try { $val = $this.Context.$($prop.Name) } catch { $val = $prop.Value }
            if ($val -is [System.Management.Automation.PSObject] -and $val.PSObject.Properties.Match('__proxy_cache').Count -gt 0) {
                try { $val.__proxy_cache.Clear() } catch {}
                $this._ProxyCacheReset($val)
                continue
            }
            if ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) {
                foreach ($el in $val) {
                    if ($el -is [System.Management.Automation.PSObject]) {
                        try { $el.__proxy_cache.Clear() } catch {}
                        $this._ProxyCacheReset($el)
                    }
                }
            }
        }
    }

    # -------------------------
    # Attach internal helpers as ScriptMethods on resolver
    $resolver | Add-Member -MemberType ScriptMethod -Name _CreateProxyRecursive -Value $createProxyRecursive
    $resolver | Add-Member -MemberType ScriptMethod -Name _ResolveStringPlaceholders -Value $resolveStringPlaceholders
    $resolver | Add-Member -MemberType ScriptMethod -Name _AddHelperMethods -Value $addHelperMethods
    $resolver | Add-Member -MemberType ScriptMethod -Name _ProxyCacheReset -Value $proxyCacheReset

    # -------------------------
    # Public methods

    # Initialize / set Context
    $setContext = {
        param($Context)
        $this.Context = $Context
    }
    $resolver | Add-Member -MemberType ScriptMethod -Name SetContext -Value $setContext

    # RegisterSource
    $regSource = {
        param([string]$ID, [hashtable]$Source)
        $this.Sources[$ID] = $Source
    }
    $resolver | Add-Member -MemberType ScriptMethod -Name RegisterSource -Value $regSource

    # RegisterCallback
    $regCallback = {
        param([string]$ID, [scriptblock]$callback)
        $this.Callbacks[$ID] = $callback
    }
    $resolver | Add-Member -MemberType ScriptMethod -Name RegisterCallback -Value $regCallback

    # RegisterCallbacks (bulk)
    $regCallbacks = {
        param([hashtable]$callbacks)
        foreach ($ID in $callbacks.Keys) {
            $this.RegisterCallback($ID, $callbacks[$ID])
        }
    }
    $resolver | Add-Member -MemberType ScriptMethod -Name RegisterCallbacks -Value $regCallbacks

    # CreateProxy (public)
    $createProxy = {
        param([string]$ID, [string[]]$AddMethods)
        if (-not $this.Sources.ContainsKey($ID)) { throw "Source not registered: $ID" }
        $entries = $this.Sources[$ID]
        $callback = $null
        if ($this.Callbacks.ContainsKey($ID)) { $callback = $this.Callbacks[$ID] }
        return $this._CreateProxyRecursive($ID, $entries, $callback, $AddMethods)
    }
    $resolver | Add-Member -MemberType ScriptMethod -Name CreateProxy -Value $createProxy

    # ResolveStringPlaceholders (public wrapper)
    $resolveStringPlaceholdersPublic = {
        param([string]$Text)
        return $this._ResolveStringPlaceholders($Text)
    }
    $resolver | Add-Member -MemberType ScriptMethod -Name ResolveStringPlaceholders -Value $resolveStringPlaceholdersPublic

    # ResolveProxyObjects (helper to convert proxies to plain hashtables)
    $resolveProxyObjects = {
        param([string[]]$Resolve)
        $resolvedCtx = @{}
        foreach ($prop in $this.Context.PSObject.Properties) {
            $name = $prop.Name
            if ($name -like '__*') { continue }
            $val = $null
            try { $val = $this.Context.$name } catch { $val = $prop.Value }
            if ($Resolve -contains $name -and $null -ne $val) {
                if ($val -is [System.Management.Automation.PSObject]) {
                    if ($null -ne $val.PSObject.Members['AsHashtable']) {
                        try { $resolvedCtx[$name] = $val.AsHashtable(); continue } catch {}
                    }
                }
            }
            $resolvedCtx[$name] = $val
        }
        return $resolvedCtx
    }
    $resolver | Add-Member -MemberType ScriptMethod -Name ResolveProxyObjects -Value $resolveProxyObjects

    # ProxyCacheReset public wrapper
    $proxyCacheResetPublic = {
        $this._ProxyCacheReset()
    }
    $resolver | Add-Member -MemberType ScriptMethod -Name ProxyCacheReset -Value $proxyCacheResetPublic

    return $resolver
}

# Export the factory
Export-ModuleMember -Function ProxyResolver