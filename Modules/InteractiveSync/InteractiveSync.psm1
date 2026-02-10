function InteractiveSync {
    [CmdletBinding(DefaultParameterSetName = 'ByPaths', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ByFileMap')]
        [hashtable]$FileMap,
        [Parameter(Mandatory, ParameterSetName = 'ByPaths')]
        [string]$LocalPath,
        [Parameter(Mandatory, ParameterSetName = 'ByPaths')]
        [string]$ServerPath,
        [Parameter(ParameterSetName = 'ByPaths')]
        [switch]$OnlyLocalModules
    )

    $params = @{
        Verbose = $PSCmdlet.MyInvocation.BoundParameters['Verbose']
        WhatIf = $WhatIfPreference
        OnlyLocalModules  = $OnlyLocalModules
    }
    if ($PSCmdlet.ParameterSetName -eq 'ByFileMap') {
        $params.FileMap = $FileMap
    }else{
        $params.LocalPath = $LocalPath
        $params.ServerPath = $ServerPath
    }

    Clear-Host
    Write-Host "🚀 Ready for module synchronization. Press [Enter] to sync or [Escape] to exit."

    while ($true) {
        $key = GetKeyPress
        if ($key -eq 'Escape') {
            Write-Host "`n👋 Exiting." -ForegroundColor Yellow
            break
        } elseif ($key -eq 'Enter') {
            Write-Host "`n🛠️  Starting manual synchronization..."
            Sync @params
            Write-Host "⏳ Ready for next sync. Press [Enter] or [Escape] to exit."
        }
    }
}
function Sync {
    [CmdletBinding(DefaultParameterSetName = 'ByPaths', SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ByFileMap')]
        [hashtable]$FileMap,
        [Parameter(Mandatory, ParameterSetName = 'ByPaths')]
        [string]$LocalPath,
        [Parameter(Mandatory, ParameterSetName = 'ByPaths')]
        [string]$ServerPath,
        [Parameter(ParameterSetName = 'ByPaths')]
        [switch]$OnlyLocalModules
    )

    $verbose = $PSCmdlet.MyInvocation.BoundParameters['Verbose']

    if ($PSCmdlet.ParameterSetName -eq 'ByPaths') {
        $FileMap = GetSyncMap -LocalPath $LocalPath -ServerPath $ServerPath -OnlyLocalModules:$OnlyLocalModules
    }

    foreach ($name in $FileMap.Keys) {
        $src = $FileMap[$name].source
        $dst = $FileMap[$name].target

        if (!(Test-Path $src) -and !(Test-Path $dst)) {
            Write-Warning "Module '$name' not found on either side."
            continue
        }

        $srcTime = if (Test-Path $src) { (Get-Item $src).LastWriteTime } else { [datetime]::MinValue }
        $dstTime = if (Test-Path $dst) { (Get-Item $dst).LastWriteTime } else { [datetime]::MinValue }

        if ($srcTime -gt $dstTime) {
            if ($verbose) {
                Write-Host "🔄 Sync: $name → local version (server version is newer)" -ForegroundColor Cyan
            }
            CopyFile -Source $src -Target $dst -Name $name -WhatIf:$WhatIfPreference -Verbose:$verbose
        } elseif ($dstTime -gt $srcTime) {
            if ($verbose) {
                Write-Host "🔄 Sync: $name → server version (local version is newer)" -ForegroundColor Cyan
            }
            CopyFile -Source $dst -Target $src -Name $name -WhatIf:$WhatIfPreference -Verbose:$verbose
        } elseif ($verbose) {
            Write-Host "⏭️  Skip: $name (equal timestamps)" -ForegroundColor Blue
        }
    }

    Write-Host "`n✅ Synchronization complete.`n" -ForegroundColor Green
}
function GetSyncMap {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LocalPath,

        [Parameter(Mandatory = $true)]
        [string]$ServerPath,

        [switch]$OnlyLocalModules
    )

    $result = @{}

    $localModules = Get-ChildItem -Path $LocalPath -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).psm1") }

    $serverModules = if ($OnlyLocalModules) {
        $localModules
    } else {
        Get-ChildItem -Path $ServerPath -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).psm1") }
    }

    $allNames = ($localModules.Name + $serverModules.Name) | Sort-Object -Unique

    foreach ($name in $allNames) {
        $localFile  = [System.IO.Path]::Combine($LocalPath, $name, "$name.psm1")
        $serverFile = [System.IO.Path]::Combine($ServerPath, $name, "$name.psm1")
        $result[$name] = @{ source = $serverFile; target = $localFile }
    }

    return $result
}
function CopyFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Target,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $verbose = $PSCmdlet.MyInvocation.BoundParameters['Verbose']

    if (-not $WhatIfPreference) {
        $success = $false
        $maxTries = 3
        for ($i = 1; $i -le $maxTries; $i++) {
            try {
                $parent = Split-Path $Target -Parent
                if (-not (Test-Path $parent)) {
                    New-Item -ItemType Directory -Path $parent -Force | Out-Null
                }
                Copy-Item -Path $Source -Destination $Target -Force -ErrorAction Stop
                $success = $true
                break
            } catch {
                if ($i -eq $maxTries) {
                    Write-Error "⚠️ Copy failed after $maxTries attempts: $_"
                } else {
                    Start-Sleep -Seconds 2
                }
            }
        }
        if ($verbose -and $success) {
            Write-Host "✅ Synced: $Name → $Target" -ForegroundColor Green
        }
    }else{
        $PSCmdlet.ShouldProcess("$Name", "Copy $Source → $Target")
    }
}
function GetKeyPress {
    # Load Windows Forms if not already done
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

    try {
        # Works in ConsoleHost (e.g., Windows Terminal, PowerShell Core)
        if ($Host.Name -eq 'ConsoleHost') {
            return [System.Console]::ReadKey($true).Key
        }

        # Use dialog fallback in ISE
        $dialogResult = [System.Windows.Forms.MessageBox]::Show(
            "Do you want to sync now? Press Yes to start, No to cancel.",
            "InteractiveSync (ISE Fallback)",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($dialogResult -eq [System.Windows.Forms.DialogResult]::Yes) {
            return 'Enter'
        } else {
            return 'Escape'
        }

    } catch {
        Write-Warning "⚠️ Unable to detect key input in this host environment."
        return $null
    }
}
