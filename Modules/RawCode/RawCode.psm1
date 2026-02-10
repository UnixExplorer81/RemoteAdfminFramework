# region Internal module state
$script:Registry = $null
# endregion
# region Public API
function SetRawCodeRegistry {
    <#
    .SYNOPSIS
        Injects a PsRegistry instance to be used by the module.
    #>
    param (
        [Parameter(Mandatory)]
        [object]$Registry
    )
    $script:Registry = $Registry
}

function GetCode {
    <#
    .SYNOPSIS
        Returns a hashtable with the raw source code (string) for each given module key.

    .PARAMETER ModuleKeys
        Array of module keys whose source paths are defined in the registry.
    #>
    param (
        [Parameter(Mandatory)]
        [string[]]$SourceKeys
    )

    if (-not $script:Registry) {
        throw "❌ PsRegistry has not been set. Use Set-RawCodeRegistry first."
    }

    $rawCodes = @{}

    foreach ($key in $SourceKeys) {
        try {
            $path = GetRawCodeSourcePath -Key $key

            if (-not (Test-Path $path)) {
                throw "File not found: '$path'"
            }

            $rawCodes[$key] = Get-Content -Path $path -Raw -Encoding UTF8

        } catch {
            throw "❌ Failed to retrieve raw module '$key': $_"
        }
    }

    return $rawCodes
}
# endregion
# region Internal helper
function GetRawCodeSourcePath {
    param (
        [Parameter(Mandatory)][string]$Key
    )

    if (-not $script:Registry.ContainsKey($Key)) {
        throw "❌ Unknown module key '$Key' in registry."
    }

    $entry = $script:Registry[$Key]

    if (-not $entry.ContainsKey("source")) {
        throw "❌ Registry entry '$Key' does not contain a 'source' path."
    }

    return $entry.source
}
# endregion


class RawCode {
    
    [object]$Registry

    RawCode([object]$registry) {
        $this.Registry = $registry
    }

    hidden [string] GetSourcePath([string] $key) {
        if (-not $this.Registry.ContainsKey($key)) {
            throw "❌ Unknown module key '$key' in registry."
        }

        $entry = $this.Registry[$key]

        if (-not $entry.ContainsKey("source")) {
            throw "❌ Registry entry '$key' does not contain a 'source' path."
        }

        return $entry.source
    }

    [hashtable] GetCode([string[]] $moduleKeys) {
        $rawModules = @{}

        foreach ($key in $moduleKeys) {
            try {
                $path = $this.GetSourcePath($key)

                if (-not (Test-Path $path)) {
                    throw "File not found: '$path'"
                }

                $rawCode = Get-Content -Path $path -Raw -Encoding UTF8
                $rawModules[$key] = $rawCode

            } catch {
                throw "❌ Failed to retrieve raw module '$key': $_"
            }
        }

        return $rawModules
    }
}
