function MountRemoteDrive {
    <#
    .SYNOPSIS
        Mounts a remote share to a local drive letter with automatic cleanup on PowerShell exit.

    .PARAMETER Share
        UNC path of the remote share (e.g. \\server\share).

    .PARAMETER DriveLetter
        Drive letter to assign (e.g. Z). Optional, will auto-select if not provided.

    .PARAMETER Credential
        Credentials used to authenticate against the remote share.

    .PARAMETER UseNetUse
        If set, the drive is mounted using 'net use' instead of New-PSDrive.

    .PARAMETER PSDriveOnly
        If set, the drive will only be visible to the current PowerShell session.

    .PARAMETER Persistent
        If set, the connection will be persistent across reboots (only relevant with -UseNetUse).

    .PARAMETER ReadOnly
        If set, the PSDrive is mounted as read-only (if supported).

    .PARAMETER RegisterExitCleanup
        If set, the drive will be unmounted automatically when PowerShell exits.

    .OUTPUTS
        Returns a hashtable with 'DriveName', 'Success' and optionally 'Error'.

    #>

    param (
        [Parameter(Mandatory)]
        [string] $Share,
        [Parameter()]
        [string] $DriveLetter,
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential] $Credential,

        [switch] $UseNetUse,
        [switch] $PSDriveOnly,
        [switch] $Persistent,
        [switch] $ReadOnly,
        [switch] $RegisterExitCleanup
    )
    $result = @{
        Success   = $false
        DriveName = $null
        Error     = $null
    }
    try {
        # Assign default drive letter if not provided
        if (-not $DriveLetter) {
            $used = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Name
            $free = [char[]](67..90) | ForEach-Object { "$([char]$_)" } | Where-Object { $_ -notin $used }
            if ($free.Count -eq 0) {
                throw "No available drive letters."
            }
            $DriveLetter = $free[0]
        }
        $driveName = "$DriveLetter`:"
        $result.DriveName = $driveName
        if ($UseNetUse) {
            $securePassword = $Credential.Password
            $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
            )
            $netUseCommand = "net use $driveName `"$Share`" `"$($Credential.UserName)`" `"$plainPassword`""
            if ($Persistent) {
                $netUseCommand += " /persistent:yes"
            } else {
                $netUseCommand += " /persistent:no"
            }
            Invoke-Expression $netUseCommand | Out-Null
        } else {
            $psDriveParams = @{
                Name       = $DriveLetter
                PSProvider = 'FileSystem'
                Root       = $Share
                Credential = $Credential
            }
            if ($ReadOnly) {
                $psDriveParams['Description'] = 'ReadOnly'
            }
            New-PSDrive @psDriveParams -Scope Global | Out-Null
        }
        if ($RegisterExitCleanup) {
            Register-EngineEvent -SourceIdentifier "PowerShell.Exiting" -Action {
                try {
                    if ($UseNetUse) {
                        net use $driveName /delete /y | Out-Null
                    } else {
                        Remove-PSDrive -Name $DriveLetter -Force -ErrorAction SilentlyContinue
                    }
                } catch {
                    Write-Debug "Cleanup failed: $_"
                }
            } | Out-Null
        }
        $result.Success = $true
    } catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}

class MountPsDrive {
    [string]$Server
    [string]$Share
    [string]$UNCPath
    [string]$DriveName
    [pscredential]$Credential
    [switch]$AutoUnmount
    [string]$PSDriveName
    [bool]$Mounted = $false

    MountPsDrive([hashtable]$Params) {
        $this.UNCPath     = $Params.UNCPath.TrimEnd('\')
        $this.Credential  = $Params.Credential
        $this.Server      = ($Params.UNCPath -replace '^\\\\([^\\]+)\\.*', '$1')
        $this.Share       = ($Params.UNCPath -replace '^\\\\[^\\]+\\([^\\]+)\\?.*', '$1')
        $this.DriveName   = if ($Params.DriveName) { $Params.DriveName } else { "$($this.Share)@$($this.Server)" }
        $this.PSDriveName = $this.DriveName+":"
        $this.AutoUnmount = if($Params.AutoUnmount) {$Params.AutoUnmount} else {$true}

        if (-not ($this.TestExistingDrive())) {
            $this.Mount()
        } else {
            Write-Verbose "Drive '$($this.DriveName)' already exists and points to the correct UNC path."
            $this.Mounted = $true
        }

        if ($this.AutoUnmount) {
            Register-EngineEvent PowerShell.Exiting -Action {
                try {
                    Remove-PSDrive -Name $using:this.DriveName -Force -ErrorAction SilentlyContinue
                } catch {}
            } | Out-Null
        }
    }

    [bool] TestExistingDrive() {
        $existing = Get-PSDrive -Name $this.DriveName -ErrorAction SilentlyContinue
        return ($existing -and ($existing.Root -eq $this.UNCPath))
    }

    [void] Mount() {
        try {
            New-PSDrive -Name $this.DriveName -PSProvider FileSystem -Root $this.UNCPath -Credential $this.Credential -Persist:$false -Scope Global -ErrorAction Stop | Out-Null
            $this.Mounted = $true
        } catch {
            throw "❌ Failed to mount drive '$($this.DriveName)' to '$($this.UNCPath)': $_"
        }
    }

    [void] Unmount() {
        if ($this.Mounted -and (Get-PSDrive -Name $this.DriveName -ErrorAction SilentlyContinue)) {
            try {
                Remove-PSDrive -Name $this.DriveName -Force -ErrorAction Stop
                $this.Mounted = $false
            } catch {
                Write-Warning "⚠️ Failed to remove PSDrive '$($this.DriveName)': $_"
            }
        }
    }

    [string] GetPath([string]$Path = "") {
        if ($Path.ToUpper().StartsWith($this.UNCPath)) {
            $relativePath = $Path.Substring($this.UNCPath.Length).TrimStart('\')
        } else {
            $relativePath = $Path
        }

        return Join-Path -Path $this.PSDriveName -ChildPath $relativePath
    }

    [string] ToString() {
        return "[$($this.DriveName)] => '$($this.UNCPath)'"
    }
}