# Internal storage for replacements
$script:PlaceholderReplacements = @{}

function RecursivePlaceholderResolver {
    param (
        [hashtable]$Initial = $null
    )

    $script:PlaceholderReplacements = @{}

    # Add environment variables in Angular-style placeholders
    foreach ($envVar in [System.Environment]::GetEnvironmentVariables().Keys) {
        $script:PlaceholderReplacements["{{${envVar}}}"] = [System.Environment]::GetEnvironmentVariable($envVar)
    }

    if ($Initial) {
        Add-PlaceholderReplacements -NewReplacements $Initial
    }
}

function AddPlaceholderReplacements {
    param (
        [Parameter(Mandatory)]
        [hashtable]$NewReplacements
    )

    foreach ($key in $NewReplacements.Keys) {
        $script:PlaceholderReplacements["{{${key}}}"] = $NewReplacements[$key]
    }
}

function ResolvePlaceholders {
    param (
        [Parameter(Mandatory)]
        [object]$Input
    )

    if ($Input -is [string]) {
        return ResolveStringPlaceholder -Text $Input
    }
    elseif ($Input -is [hashtable]) {
        $new = @{}
        foreach ($k in $Input.Keys) {
            $new[$k] = ResolvePlaceholders -Input $Input[$k]
        }
        return $new
    }
    elseif ($Input -is [System.Collections.IEnumerable] -and !($Input -is [string])) {
        return @($Input | ForEach-Object { ResolvePlaceholders -Input $_ })
    }
    else {
        return $Input
    }
}

function ResolveStringPlaceholder {
    param (
        [Parameter(Mandatory)]
        [string]$Text
    )

    foreach ($key in $script:PlaceholderReplacements.Keys) {
        $escapedKey = [regex]::Escape($key)
        $value = [string]$script:PlaceholderReplacements[$key]
        $Text = $Text -replace $escapedKey, [System.Text.RegularExpressions.Regex]::Escape($value)
    }

    return $Text -replace '\\E', ''
}

class RecursivePlaceholderResolver {
    [hashtable]$Replacements

    RecursivePlaceholderResolver([hashtable]$initial = $null) {
        $this.Replacements = @{}
        $this.AddEnvVariables()
        if ($initial) { $this.AddReplacements($initial) }
    }

    [void] AddReplacements([hashtable]$newReplacements) {
        foreach ($key in $newReplacements.Keys) {
            $this.Replacements[$key] = $newReplacements[$key]
        }
    }

    [void] AddEnvVariables() {
        foreach ($envVar in [System.Environment]::GetEnvironmentVariables().Keys) {
            $this.Replacements["`$env:$envVar"] = [System.Environment]::GetEnvironmentVariable($envVar)
        }
    }

    [object] Resolve([object]$input) {
        if ($input -is [string]) {
            return $this.ResolveString($input)
        }
        elseif ($input -is [hashtable]) {
            $new = @{}
            foreach ($k in $input.Keys) {
                $new[$k] = $this.Resolve($input[$k])
            }
            return $new
        }
        elseif ($input -is [System.Collections.IEnumerable] -and !($input -is [string])) {
            return @($input | ForEach-Object { $this.Resolve($_) })
        }
        else {
            return $input
        }
    }

    [string] ResolveString([string]$text) {
        foreach ($key in $this.Replacements.Keys) {
            $escapedKey = [regex]::Escape($key)
            $value = [string]$this.Replacements[$key]
            $text = $text -replace $escapedKey, [System.Text.RegularExpressions.Regex]::Escape($value)
        }
        return $text -replace '\\E', '' # fallback cleanup
    }
}