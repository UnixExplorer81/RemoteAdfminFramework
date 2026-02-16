class ProxyPlaceholderResolver {
    
    [hashtable]$Sources
    [hashtable]$Callbacks
    [System.Collections.ArrayList]$Proxies

    ProxyPlaceholderResolver() {
        $this.Sources   = @{}
        $this.Callbacks = @{}
        $this.Proxies   = [System.Collections.ArrayList]@()
    }

    # Register a source under an id (e.g. 'CONFIG')
    [void] RegisterSource([string]$id, [hashtable]$source) {
        $this.Sources[$id] = $source

        # invalidate caches in existing proxies
        foreach ($p in $this.Proxies) {
            if (-not $p.PSObject.Properties.Match('__proxy_sourceId').Count) { continue }
            if (-not $p.PSObject.Properties.Match('__proxy_cache').Count) { continue }

            $pSId = $p.__proxy_sourceId

            if ($id -eq $pSId) {
                # exact proxy updated -> clear whole proxy cache
                try { $p.__proxy_cache.Clear() } catch {}
                continue
            }
            if ($id.Contains('.')) {
                # registering a composed id like "CONFIG.PsRegistryConfig"
                # if this proxy is a parent (pid is prefix of id), remove the appropriate child cache key
                if ($id.StartsWith($pSId + '.')) {
                    $rem = $id.Substring($pSId.Length + 1)
                    $child = $rem.Split('.')[0]
                    try { $p.__proxy_cache.Remove($child) | Out-Null } catch {}
                    continue
                }
            } else {
                # registering a top-level id like "CONFIG"
                # invalidate any proxy whose pid equals or starts with this id (itself or deeper nested proxies)
                if ($pSId -eq $id -or $pSId.StartsWith($id + '.')) {
                    try { $p.__proxy_cache.Clear() } catch {}
                    continue
                }
            }
        }
    }

    # Register a callback scriptblock under an id (e.g. 'REPOSITORY' or 'CREDENTIALKEY')
    [void] RegisterCallback([string]$id, [scriptblock]$callback) {
        $this.Callbacks[$id] = $callback
    }
    
    # Convenience: register multiple callbacks from a hashtable
    [void] RegisterCallbacks([hashtable]$callbacks) {
        foreach ($id in $callbacks.Keys) {
            $this.RegisterCallback($id, $callbacks[$id])
        }
    }

    # Public entry: Create a proxy for a registered source id (alias ToProxy kept for compatibility)
    [object] CreateProxy([string]$sourceId, $Context, [string[]]$AddMethods) {
        if (-not $this.Sources.ContainsKey($sourceId)) { throw "Source not registered: $sourceId" }
        $entries = $this.Sources[$sourceId]
        $callback = $null
        if ($this.Callbacks.ContainsKey($sourceId)) { $callback = $this.Callbacks[$sourceId] }
        return $this.CreateProxyRecursive($sourceId, $entries, $callback, $Context, [string[]]$AddMethods)
    }

    # Core: build a proxy object from the provided entries hashtable.
    # This method supports a lookup-fallback: if a composed id (qualId.child) is registered
    # in $this.Sources, that registration will be used instead of the nested hashtable.
    [object] CreateProxyRecursive([string]$qualId, [hashtable]$entries, [scriptblock]$callback, $Context, [string[]]$AddMethods) {
        $self = $this
        $cb   = $callback
        $ctx  = $Context

        $proxy = New-Object PSObject
        $proxy | Add-Member -NotePropertyName '__proxy_cache' -NotePropertyValue (New-Object System.Collections.Hashtable) -Force
        $proxy | Add-Member -NotePropertyName '__proxy_sourceId' -NotePropertyValue $qualId -Force

        foreach ($k in $entries.Keys) {
            $val = $entries[$k]

            # --- lazy nested hashtable ---
            if ($val -is [hashtable]) {
                # freeze iteration-specific locals BEFORE creating the closure
                $iter_propName      = $k
                $iter_propVal       = $val
                $iter_callbackLocal = $cb
                $iter_ctx           = $ctx
                $iter_resolver      = $self
                $iter_qualId        = $qualId
                $iter_composedId    = "$iter_qualId.$iter_propName"

                $nestedGetter = {
                    param()
                    if (-not $this.__proxy_cache) { $this.__proxy_cache = @{} }

                    if ($this.__proxy_cache.ContainsKey($iter_propName)) { return $this.__proxy_cache[$iter_propName] }

                    # choose registered composed source or fallback to nested hashtable
                    $nestedEntries = $null
                    $nestedCb = $iter_callbackLocal
                    if ($iter_resolver.Sources.ContainsKey($iter_composedId)) {
                        $nestedEntries = $iter_resolver.Sources[$iter_composedId]
                        if ($iter_resolver.Callbacks.ContainsKey($iter_composedId)) { $nestedCb = $iter_resolver.Callbacks[$iter_composedId] }
                    } else {
                        $nestedEntries = $iter_propVal
                    }

                    # build nested proxy and cache it
                    $nestedProxy = $iter_resolver.CreateProxyRecursive($iter_composedId, $nestedEntries, $nestedCb, $iter_ctx, $null)
                    $this.__proxy_cache[$iter_propName] = $nestedProxy
                    return $nestedProxy
                }.GetNewClosure()

                $scriptPropNested = New-Object System.Management.Automation.PSScriptProperty($k, $nestedGetter)
                $proxy.PSObject.Properties.Add($scriptPropNested) | Out-Null
                continue
            }

            # --- lazy array handling ---
            if ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) {
                # freeze iteration locals
                $iter_propName      = $k
                $iter_propVal       = $val
                $iter_callbackLocal = $cb
                $iter_ctx           = $ctx
                $iter_resolver      = $self
                $iter_qualId        = $qualId

                $arrayGetter = {
                    param()
                    if (-not $this.__proxy_cache) { $this.__proxy_cache = @{} }
                    if ($this.__proxy_cache.ContainsKey($iter_propName)) { return $this.__proxy_cache[$iter_propName] }

                    $outList = @()
                    foreach ($item in $iter_propVal) {
                        if ($item -is [string]) {
                            # resolve placeholders inside string elements
                            $outList += $iter_resolver.ResolveStringPlaceholders($item, $iter_ctx)
                        } elseif ($item -is [hashtable]) {
                            # nested hashtable element -> create nested proxy lazily
                            $elemComposedId = "$iter_qualId.$iter_propName"
                            if ($iter_resolver.Sources.ContainsKey($elemComposedId)) {
                                $elemEntries  = $iter_resolver.Sources[$elemComposedId]
                                $elemCb = if ($iter_resolver.Callbacks.ContainsKey($elemComposedId)) { $iter_resolver.Callbacks[$elemComposedId] } else { $iter_callbackLocal }
                                $outList += $iter_resolver.CreateProxyRecursive($elemComposedId, $elemEntries, $elemCb, $iter_ctx, $null)
                            } else {
                                $outList += $iter_resolver.CreateProxyRecursive("$iter_qualId.$iter_propName", $item, $iter_callbackLocal, $iter_ctx, $null)
                            }
                        } else {
                            $outList += $item
                        }
                    }

                    # cache array (store as single array object)
                    $this.__proxy_cache[$iter_propName] = ,$outList
                    return ,$outList
                }.GetNewClosure()

                $scriptPropArray = New-Object System.Management.Automation.PSScriptProperty($k, $arrayGetter)
                $proxy.PSObject.Properties.Add($scriptPropArray) | Out-Null
                continue
            }

            # closure locals for getter
            $propName = $k
            $propVal  = $val
            $callbackLocal = $cb
            $ctx      = $ctx
            $resolver = $self

            # getter closure: lazy resolution + caching + normalization
            $get = {
                param()
                if (-not $this.__proxy_cache) { $this.__proxy_cache = @{} }

                if ($this.__proxy_cache.ContainsKey($propName)) {
                    return $this.__proxy_cache[$propName]
                }

                $resolved = $null

                # 1) If the literal contains placeholders and resolver available -> resolve
                if ($propVal -is [string] -and $propVal -match '\{\{[^}]+\}\}') {
                    try {
                        if ($resolver) { $resolved = $resolver.ResolveStringPlaceholders($propVal, $ctx) }
                    } catch { $resolved = $null }
                }

                # 2) If unresolved, try callback (support several signatures)
                if (($null -eq $resolved -or $resolved -eq $propVal -or $resolved -eq '') -and $callbackLocal) {
                    try { $resolved = & $callbackLocal $propName $ctx } catch {}
                    if (-not $resolved) { try { $resolved = & $callbackLocal $ctx } catch {} }
                    if (-not $resolved) { try { $resolved = & $callbackLocal $propName } catch {} }
                    if (-not $resolved) { try { $resolved = & $callbackLocal } catch {} }
                }

                # 3) fallback to literal value
                if ($null -eq $resolved -or ($null -eq $resolved) -or ($resolved -eq '')) {
                    $resolved = $propVal
                }

                # ----------------- Normalizer (preserve native types) -----------------
                # Execute scriptblocks, preserve booleans/numerics/objects/arrays instead of forcing strings
                $convert = {
                    param($raw)

                    # Execute scriptblock with context if present
                    if ($raw -is [scriptblock]) {
                        try { $raw = & $raw $ctx } catch { try { $raw = & $raw } catch { $raw = $null } }
                    }

                    # Preserve already-structured objects and hashtables
                    if ($raw -is [System.Management.Automation.PSCustomObject] -or $raw -is [hashtable]) {
                        return $raw
                    }

                    # Preserve booleans and numeric scalars (do NOT convert them to strings)
                    if ($raw -is [bool] -or
                        $raw -is [byte] -or
                        $raw -is [int16] -or
                        $raw -is [int] -or
                        $raw -is [long] -or
                        $raw -is [single] -or
                        $raw -is [double] -or
                        $raw -is [decimal]) {
                        return $raw
                    }

                    # Collections: preserve as array, resolve any scriptblocks inside, preserve element types
                    if ($raw -is [System.Collections.IEnumerable] -and -not ($raw -is [string])) {
                        $out = @()
                        foreach ($el in $raw) {
                            if ($el -is [scriptblock]) {
                                try { $val = & $el $ctx } catch { try { $val = & $el } catch { $val = $null } }
                            } else {
                                $val = $el
                            }
                            $out += $val
                        }
                        return ,$out   # return as real array (preserve types)
                    }

                    # Fallback: scalar -> string
                    try { return [string]$raw } catch { return $raw.ToString() }
                }

                # attach small normalizer helper to proxy for nested conversions (once)
                if (-not $this.PSObject.Members.Match('__normalize_element').Count) {
                    $normBlock = {
                        param($element)
                        if ($element -is [scriptblock]) {
                            try { $element = & $element $ctx } catch { try { $element = & $element } catch { $element = $null } }
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

            # add property as PSScriptProperty on proxy
            $scriptProp = New-Object System.Management.Automation.PSScriptProperty($propName, $get)
            $proxy.PSObject.Properties.Add($scriptProp) | Out-Null
        }
        $this.AddHelperMethods($proxy, $AddMethods)
        return $proxy
    }

    # String resolver (kept for completeness; proxies use this for nested placeholder resolution)
    [string] ResolveStringPlaceholders([string]$text, $Context) {
        if (-not $text) { return $text }
        $self = $this

        function ConvertRecursive {
            param($raw)
            if ($null -eq $raw) { return $null }

            if ($raw -is [scriptblock]) {
                try { $raw = & $raw $Context } catch { try { $raw = & $raw } catch { $raw = $null } }
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
            if ($s -and ($s -match '\{\{[^}]+\}\}')) {
                return $self.ResolveStringPlaceholders($s, $Context)
            }
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

                if ($self.Callbacks.ContainsKey($token)) {
                    $cb = $self.Callbacks[$token]
                    $val = $null
                    try { $val = & $cb $Context } catch {}
                    if (-not $val) { try { $val = & $cb } catch {} }
                    $replacement = ConvertRecursive $val
                }

                if (($null -eq $replacement -or $replacement -eq '') -and $self.Sources.ContainsKey($token)) {
                    $s = $self.Sources[$token]
                    if ($s -is [hashtable] -and $s.ContainsKey('Value')) {
                        $replacement = [string]$s['Value']
                    } elseif ($s -is [string]) {
                        $replacement = [string]$s
                    }
                }
            } else {
                $src = $parts[0]; $key = $parts[1]

                if ($self.Callbacks.ContainsKey($src)) {
                    $cb = $self.Callbacks[$src]
                    $val = $null
                    try { $val = & $cb $key $Context } catch {}
                    if (-not $val) { try { $val = & $cb $Context } catch {} }
                    if (-not $val) { try { $val = & $cb $key } catch {} }
                    if (-not $val) { try { $val = & $cb } catch {} }
                    $replacement = ConvertRecursive $val
                }

                if (($null -eq $replacement -or $replacement -eq '') -and $self.Sources.ContainsKey($src)) {
                    $s = $self.Sources[$src]
                    if ($s -is [System.Management.Automation.PSObject]) {
                        if ($s.PSObject.Properties.Match($key).Count -gt 0) {
                            try { $v = $s.$key } catch { $v = $null }
                            $replacement = ConvertRecursive $v
                        }
                    } elseif ($s -is [hashtable]) {
                        if ($s.ContainsKey($key)) {
                            $val = $s[$key]
                            if ($val -is [string] -and ($val -match '\{\{[^}]+\}\}')) {
                                $replacement = $self.ResolveStringPlaceholders($val, $Context)
                            } else {
                                $replacement = ConvertRecursive $val
                            }
                        }
                    }
                }
            }

            if ($null -eq $replacement -or $replacement -eq '') {
                $sb.Append($m.Value) | Out-Null
            } else {
                $sb.Append([string]$replacement) | Out-Null
            }

            $last = $m.Index + $m.Length
        }

        if ($last -lt $text.Length) {
            $sb.Append($text.Substring($last)) | Out-Null
        }

        return $sb.ToString()
    }

    [void] AddHelperMethods([object]$proxy, [string[]]$methods) {
        # choose default if none specified
        if (-not $methods -or $methods.Count -eq 0) {
            return
        }

        # --- GetRecords(keys) -> hashtable { key = value } ---
        if ($methods -contains 'GetRecords' -and -not $proxy.PSObject.Members.Match('GetRecords').Count) {
            $sbGetRecords = {
                param($keys)
                # normalize keys -> array
                if ($null -eq $keys) { $keys = @() }
                if (-not ($keys -is [System.Collections.IEnumerable]) -or ($keys -is [string])) { $keys = ,$keys }
                $parent = $this    # $this here is the proxy on which GetRecords was called
                $out = New-Object PSObject
                # optional cache for the returned object
                $out | Add-Member -NotePropertyName '__proxy_cache' -NotePropertyValue (New-Object System.Collections.Hashtable) -Force
                foreach ($k in $keys) {
                    if (-not $k) { continue }
                    if ($parent.PSObject.Properties.Match($k).Count -eq 0) { continue }
                    # capture key for closure
                    $propName = $k
                    # getter for the returned object's property: forward to parent.$propName (lazy)
                    $get = {
                        param()
                        if (-not $this.__proxy_cache) { $this.__proxy_cache = @{} }
                        if ($this.__proxy_cache.ContainsKey($propName)) { return $this.__proxy_cache[$propName] }

                        # IMPORTANT: use $parent (captured) to access original lazy getter
                        $val = $parent.$propName

                        # cache the resolved value inside returned object
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

        # --- Filter(predicate) -> PSObject snapshot where predicate($key,$value) is true ---
        if ($methods -contains 'Filter' -and -not $proxy.PSObject.Members.Match('Filter').Count) {
            $sbFilter = {
                param($predicate)
                $parent = $this
                $keysToInclude = @()
                foreach ($p in $parent.PSObject.Properties) {
                    if ($p.Name -like '__*') { continue }
                    # try predicate; for value-based predicates we must resolve the parent value here
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
                # build a new proxy forwarding to parent for the chosen keys (lazy getters)
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

        # --- AsHashtable([keys]) -> eager PSCustomObject, placeholders resolved (robust) ---
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

                    # --- 1. Echte Proxy-Objekte (mit __proxy_sourceId) → rekursiv AsHashtable ---
                    if ($value -is [System.Management.Automation.PSObject] -and 
                        $value.PSObject.Properties.Match('__proxy_sourceId').Count -gt 0) {
                        try { 
                            $value = $value.AsHashtable() 
                        } catch { 
                            $plain = @{}
                            foreach ($sub in $value.PSObject.Properties) {
                                if ($sub.Name -like '__*') { continue }
                                try { $plain[$sub.Name] = $value.$($sub.Name) } catch { $plain[$sub.Name] = $sub.Value }
                            }
                            $value = $plain
                        }
                    }
                    # --- 2. Arrays: nur Proxy-Elemente rekursiv, plain Elemente unverändert ---
                    elseif ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
                        $arr = @()
                        foreach ($el in $value) {
                            # Nur wenn Element ein echter Proxy ist → AsHashtable()
                            if ($el -is [System.Management.Automation.PSObject] -and 
                                $el.PSObject.Properties.Match('__proxy_sourceId').Count -gt 0) {
                                $arr += $el.AsHashtable()
                            } else {
                                # Plain-Werte (String, Zahl, bool) direkt übernehmen
                                $arr += $el
                            }
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

        # --- GetKeys() -> string[] of keys (excludes meta names) ---
        if ($methods -contains 'GetKeys' -and -not $proxy.PSObject.Members.Match('GetKeys').Count) {
            $sbKeys = {
                param()
                return ($this.PSObject.Properties | Where-Object { $_.Name -notlike '__*' } | Select-Object -ExpandProperty Name)
            }.GetNewClosure()
            $m = New-Object System.Management.Automation.PSScriptMethod('GetKeys', $sbKeys)
            $proxy.PSObject.Members.Add($m) | Out-Null
        }
    }
}

function ResolveProxyObjects {
    param(
        [Parameter(Mandatory)][object]$Context,
        [string[]]$Resolve
    )
    $jobCtx = @{}
    foreach ($prop in $Context.PSObject.Properties) {
        $name = $prop.Name
        if ($name -like '__*') { continue }
        # try real evaluation (will run ScriptProperty getters)
        $val = $null
        try { $val = $Context.$name } catch { $val = $prop.Value }
        # If property is explicitly in Resolve and it is a proxy-like object,
        # prefer calling AsHashtable if available.
        if ($Resolve -contains $name -and $null -ne $val) {
            if ($val -is [System.Management.Automation.PSObject]) {
                # check for script methods (AsHashtable)
                if ($null -ne $val.PSObject.Members['AsHashtable']) {
                    try {
                        # ensure plain is recursively converted into pure PS hashtables/arrays
                        $jobCtx[$name] = $val.AsHashtable()
                        continue
                    } catch {
                        # fall through to general conversion
                    }
                }
            }
        }
        # Fallback: convert whatever we have to plain
        $jobCtx[$name] = $val
    }
    return $jobCtx
}
