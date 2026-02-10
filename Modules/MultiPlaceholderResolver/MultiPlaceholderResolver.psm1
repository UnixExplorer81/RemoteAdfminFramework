$script:PlaceholderSources = @{}
$script:PlaceholderCallbacks = @{}

function InitializePlaceholderResolver {
    $script:PlaceholderSources = @{}
    $script:PlaceholderCallbacks = @{}

    # Add env as default source
    RegisterPlaceholderSource -Id 'env' -Hashtable (&{
        $envVars = @{}
        foreach ($k in [System.Environment]::GetEnvironmentVariables().Keys) {
            $envVars["`$env:$k"] = [System.Environment]::GetEnvironmentVariable($k)
        }
        return $envVars
    })
}

function RegisterPlaceholderSource {
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][hashtable]$Hashtable
    )
    $script:PlaceholderSources[$Id] = $Hashtable
}

function RegisterPlaceholderCallbacks {
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][scriptblock]$Callback
    )
    $script:PlaceholderCallbacks[$Id] = $Callback
}

function ResolvePlaceholderValue {
    param (
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][string]$Key
    )
    if ($script:PlaceholderSources.ContainsKey($SourceId)) {
        return $script:PlaceholderSources[$SourceId][$Key]
    }
    elseif ($script:PlaceholderCallbacks.ContainsKey($SourceId)) {
        return & $script:PlaceholderCallbacks[$SourceId] $Key
    }
    else {
        return "{{${SourceId}:${Key}}}" # fallback: unresolved
    }
}

function ResolveStringPlaceholders {
    param ([string]$Text)

    return ($Text -replace '\{\{(\w+):([^}]+)\}\}', {
        param($match)
        $source = $match.Groups[1].Value
        $key    = $match.Groups[2].Value
        $resolved = ResolvePlaceholderValue -SourceId $source -Key $key
        return [string]$resolved
    })
}

function ResolvePlaceholders {
    param (
        [Parameter(Mandatory)][object]$Input
    )

    if ($Input -is [string]) {
        return ResolveStringPlaceholders -Text $Input
    }
    elseif ($Input -is [hashtable]) {
        $resolved = @{}
        foreach ($key in $Input.Keys) {
            $resolved[$key] = ResolvePlaceholders $Input[$key]
        }
        return $resolved
    }
    elseif ($Input -is [System.Collections.IEnumerable] -and !($Input -is [string])) {
        return @($Input | ForEach-Object { ResolvePlaceholders $_ })
    }
    else {
        return $Input
    }
}

class MultiPlaceholderResolver {
    [hashtable]$Sources
    [hashtable]$Callbacks

    MultiPlaceholderResolver() {
        $this.Sources = @{}
        $this.Callbacks = @{}

        # Default: env vars
        $envVars = @{}
        foreach ($k in [System.Environment]::GetEnvironmentVariables().Keys) {
            $envVars["`$env:$k"] = [System.Environment]::GetEnvironmentVariable($k)
        }
        $this.RegisterSource('env', $envVars)
    }

    [void] RegisterSource([string]$id, [hashtable]$table) {
        $this.Sources[$id] = $table
    }

    [void] RegisterCallback([string]$id, [scriptblock]$callback) {
        $this.Callbacks[$id] = $callback
    }

    [string] ResolveString([string]$text) {
        return ($text -replace '\{\{(\w+):([^}]+)\}\}', {
            param($match)
            $source = $match.Groups[1].Value
            $key    = $match.Groups[2].Value
            $resolved = $this.ResolveKey($source, $key)
            return [string]$resolved
        })
    }

    [object] Resolve([object]$input) {
        if ($input -is [string]) {
            return $this.ResolveString($input)
        }
        elseif ($input -is [hashtable]) {
            $result = @{}
            foreach ($k in $input.Keys) {
                $result[$k] = $this.Resolve($input[$k])
            }
            return $result
        }
        elseif ($input -is [System.Collections.IEnumerable] -and !($input -is [string])) {
            return @($input | ForEach-Object { $this.Resolve($_) })
        }
        else {
            return $input
        }
    }

    [string] ResolveKey([string]$source, [string]$key) {
        if ($this.Sources.ContainsKey($source)) {
            return $this.Sources[$source][$key]
        }
        elseif ($this.Callbacks.ContainsKey($source)) {
            return & $this.Callbacks[$source] $key
        }
        else {
            return "{{${source}:${key}}}" # unresolved
        }
    }
}