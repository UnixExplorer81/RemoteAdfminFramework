###############################################################################
# Module: ScriptVersionGuard.psm1
# Description: Provides `Invoke-IfScriptChanged`, which conditionally executes
#              a script (by path) or a ScriptBlock only if its content hash has
#              changed since last run. Supports multiple identifiers stored in
#              a single JSON hash file.
###############################################################################

function Invoke-IfScriptChanged {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        # Unique identifier for the script or block
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Id,

        # Path to script file to hash & execute
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        # file Path to hash ($ScriptPath + $ActionBlock)
        [Parameter(Mandatory, ParameterSetName = 'Both')]
        [string]$ScriptPath,

        # Inline ScriptBlock to hash & execute
        [Parameter(Mandatory, ParameterSetName = 'Block')]
        # ScriptBlock to execute ($ScriptPath + $ActionBlock)
        [Parameter(Mandatory, ParameterSetName = 'Both')]
        [ScriptBlock]$ActionBlock,

        # JSON file storing Id->Hash mappings
        [Parameter()]
        [string]$HashFile = "$env:ProgramData\ScriptVersionGuard.json"
    )

    # Ensure hash file exists
    if (-not (Test-Path $HashFile)) {
        '{}' | Out-File -FilePath $HashFile -Encoding UTF8 -Force
    }

    # Load and convert JSON to hashtable
    try {
        $json = Get-Content -Path $HashFile -Raw | ConvertFrom-Json -ErrorAction Stop
        $entries = @{}
        foreach ($prop in $json.PSObject.Properties) {
            $entries[$prop.Name] = $prop.Value
        }
    } catch {
        Write-Warning "Failed to load or parse hash file. Resetting: $_"
        $entries = @{}
    }

    # Compute current hash
    switch ($PSCmdlet.ParameterSetName) {
        'Path' {
            if (-not (Test-Path $ScriptPath)) {
                Write-Warning "Script file not found: $ScriptPath"
                return
            }
            $currentHash = (Get-FileHash -Path $ScriptPath -Algorithm SHA256).Hash
        }
        'Block' {
            $text = $ActionBlock.ToString().Trim()
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
            $sha = [System.Security.Cryptography.SHA256]::Create()
            $currentHash = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '')
        }
        default {
            if ($ScriptPath -and $ActionBlock) {
                if (-not (Test-Path $ScriptPath)) {
                    Write-Warning "Script file not found: $ScriptPath"
                    return
                }
                $currentHash = (Get-FileHash -Path $ScriptPath -Algorithm SHA256).Hash
            }
        }
    }

    # Compare & Execute
    $storedHash = $entries[$Id]

    if ($currentHash -ne $storedHash) {
        Write-Host "[ScriptVersionGuard] Change detected for '$Id', executing..."
        try {
            if ($ActionBlock) {
                & $ActionBlock
            } elseif ($ScriptPath) {
                & $ScriptPath
            }
        } catch {
            Write-Error "Execution failed for '$Id': $_"
        }
        $entries[$Id] = $currentHash
        $entries | ConvertTo-Json -Depth 3 | Out-File -FilePath $HashFile -Encoding UTF8 -Force
    } else {
        Write-Host "[ScriptVersionGuard] No change for '$Id', skipping."
    }
    # # Compute current hash
    # if ($PSCmdlet.ParameterSetName -eq 'Path') {
    #     if (-not (Test-Path $ScriptPath)) {
    #         Write-Warning "Script file not found: $ScriptPath"
    #         return
    #     }
    #     $currentHash = (Get-FileHash -Path $ScriptPath -Algorithm SHA256).Hash
    # } else {
    #     $text = $ActionBlock.ToString().Trim()
    #     $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    #     $sha = [System.Security.Cryptography.SHA256]::Create()
    #     $currentHash = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '')
    # }

    # # Retrieve stored hash (empty if nonexistent)
    # $storedHash = $null
    # if ($entries.ContainsKey($Id)) { $storedHash = $entries[$Id] }

    # # Execute if changed
    # if ($currentHash -ne $storedHash) {
    #     Write-Host "[ScriptVersionGuard] Change detected for '$Id', executing..."
    #     try {
    #         if ($PSCmdlet.ParameterSetName -eq 'Path') { & $ScriptPath } else { & $ActionBlock }
    #     } catch {
    #         Write-Error "Execution failed for '$Id': $_"
    #     }
    #     # Update and save
    #     $entries[$Id] = $currentHash
    #     $entries | ConvertTo-Json -Depth 3 | Out-File -FilePath $HashFile -Encoding UTF8 -Force
    # } else {
    #     Write-Host "[ScriptVersionGuard] No change for '$Id', skipping."
    # }
}
Export-ModuleMember -Function Invoke-IfScriptChanged
