# ===========================================
# Module: RemoveZoneIdentifier
# Author: JackpotSash
# Description: Utility module to list and remove NTFS Zone.Identifier streams
# ===========================================

function RemoveZoneIdentifier {
    <#
    .SYNOPSIS
        Removes Zone.Identifier alternate data streams from all files in a directory.
    .PARAMETER Path
        Directory path to clean.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    $blocked = GetBlockedFiles -Path $Path
    if (-not $blocked) {
        Write-Host "No Zone.Identifier streams found in '$Path'." -ForegroundColor Green
        return
    }

    foreach ($item in $blocked) {
        if ($PSCmdlet.ShouldProcess($item.FilePath, "Remove Zone.Identifier")) {
            try {
                Remove-Item -Path $item.FilePath -Stream $item.Stream -ErrorAction Stop
                Write-Host "Removed: $($item.FilePath)" -ForegroundColor Cyan
            } catch {
                Write-Warning "Failed to remove ADS from: $($item.FilePath) — $_"
            }
        }
    }
}

function GetBlockedFiles {
    <#
    .SYNOPSIS
        Lists files containing a Zone.Identifier ADS.
    .PARAMETER Path
        Root path to search recursively.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Path '$Path' does not exist."
    }

    Write-Verbose "Scanning for Zone.Identifier streams in: $Path"

    try {
        Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue |
            ForEach-Object {
                $streams = Get-Item -Path $_.FullName -Stream * -ErrorAction SilentlyContinue
                foreach ($s in $streams) {
                    if ($s.Stream -eq 'Zone.Identifier') {
                        [PSCustomObject]@{
                            FilePath = $_.FullName
                            Stream   = $s.Stream
                            Length   = $s.Length
                        }
                    }
                }
            }
    } catch {
        Write-Warning "Error while scanning: $_"
    }
}

function UnblockFolder {
    <#
    .SYNOPSIS
        Uses RemoveZoneIdentifier to remove download protection recursively.
    .PARAMETER Path
        Directory to unblock.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Path '$Path' does not exist."
    }

    Write-Host "Unblocking all files under '$Path' ..." -ForegroundColor Yellow

    Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object {
            if ($PSCmdlet.ShouldProcess($_.FullName, "Unblock")) {
                try {
                    RemoveZoneIdentifier -Path $_.FullName -ErrorAction Stop
                } catch {
                    # fallback: remove Zone.Identifier directly
                    Remove-Item -Path $_.FullName -Stream Zone.Identifier -ErrorAction SilentlyContinue
                }
            }
        }

    Write-Host "Unblock operation completed." -ForegroundColor Green
}

Export-ModuleMember -Function GetBlockedFiles, RemoveZoneIdentifier, UnblockFolder
