function Logger {
    param([hashtable]$Params)

    # create logger object
    $logger = [pscustomobject]@{
        LogFiles   = @{}
        UseConsole = $false
        MaxLogSize = 512KB
        # internal state for capture
        _CaptureActive = $false
        _SavedFunctions = @{}
    }

    # init
    if ($null -eq $Params) { $Params = @{} }
    if ($null -eq $Params.LogInfo) { throw "Logger: Parameter LogInfo is required!" }
    $logger.LogFiles.Info = $Params.LogInfo
    $logger.LogFiles.Error = if ($null -ne $Params.LogErrors) { $Params.LogErrors } else { $Params.LogInfo }
    $logger.UseConsole = if ($Params.UseConsole -is [bool]) { $Params.UseConsole } else { $false }
    $logger.MaxLogSize = if ($Params.MaxLogSize -is [int]) { $Params.MaxLogSize } else { 512KB }

    # helper: write line to file and truncate
    $logger | Add-Member -MemberType ScriptMethod -Name writeLog -Value {
        param($path, $level, $message)
        try {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $icon = switch ($level.ToLower()) {
                'error'   { '❌' }
                'warning' { '⚠️' }
                'info'    { 'ℹ️' }
                'success' { '✅' }
                'debug'   { '🔧' }
                default   { 'ℹ️' }
            }
            $line = "$timestamp [$level] $icon $message"
            Add-Content -Path $path -Value $line -Encoding UTF8 -Force
            if (Test-Path $path) {
                $len = (Get-Item $path).Length
                if ($len -gt $this.MaxLogSize) {
                    $lines = Get-Content -Path $path -Tail 3000
                    $lines | Out-File -FilePath $path -Encoding UTF8
                }
            }
        } catch {
            # swallow to avoid recursion
        }
    }

    # convenience methods
    # Info
    $logger | Add-Member -MemberType ScriptMethod -Name Info -Value {
        param([string]$m)
        $this.writeLog($this.LogFiles.Info, 'Info', $m)
        if ($this.UseConsole) { Write-Host $m -ForegroundColor Cyan }
    }

    # Success
    $logger | Add-Member -MemberType ScriptMethod -Name Success -Value {
        param([string]$m)
        $this.writeLog($this.LogFiles.Info, 'Success', $m)
        if ($this.UseConsole) { Write-Host $m -ForegroundColor Green }
    }

    # Warn
    $logger | Add-Member -MemberType ScriptMethod -Name Warn -Value {
        param([string]$m)
        $this.writeLog($this.LogFiles.Error, 'Warning', $m)
        if ($this.UseConsole) { Write-Host $m -ForegroundColor Yellow }
    }

    # Error
    $logger | Add-Member -MemberType ScriptMethod -Name Error -Value {
        param([string]$m)
        $this.writeLog($this.LogFiles.Error, 'Error', $m)
        if ($this.UseConsole) { Write-Host $m -ForegroundColor Red }
    }

    # Debug
    $logger | Add-Member -MemberType ScriptMethod -Name Debug -Value {
        param([string]$m)
        $this.writeLog($this.LogFiles.Info, 'Debug', $m)
        if ($this.UseConsole) { Write-Host $m -ForegroundColor DarkGray }
    }

    # StartCapture: override Out-Default and Write-Host in global function scope
    $startCapture = {
        if ($this._CaptureActive) { return }
        $this._CaptureActive = $true

        # save existing function definitions (if any)
        $save = @{}
        foreach ($fn in 'Out-Default','Write-Host') {
            $existing = Get-Command $fn -ErrorAction SilentlyContinue
            if ($null -ne $existing -and $existing.CommandType -eq 'Function') {
                $save[$fn] = @{ Type='Function'; Definition = (Get-Item "Function:\$fn").ScriptBlock }
            } elseif ($null -ne $existing) {
                $save[$fn] = @{ Type=$existing.CommandType; Definition = $existing }
            } else {
                $save[$fn] = $null
            }
        }
        $this._SavedFunctions = $save

        # define global function Out-Default to capture pipeline output
        $outDefaultScript = {
            param($InputObject)
            # avoid recursion: call logger methods via saved reference
            $loggerRef = $global:LoggerCaptureInstance
            if ($null -eq $loggerRef) { return }
            try {
                if ($InputObject -is [System.Management.Automation.ErrorRecord]) {
                    $loggerRef.Error($InputObject.Exception.Message)
                } elseif ($InputObject -is [System.Management.Automation.WarningRecord]) {
                    $loggerRef.Warn($InputObject.Message)
                } elseif ($InputObject -is [System.Management.Automation.InformationRecord]) {
                    $loggerRef.Info($InputObject.MessageData.ToString())
                } else {
                    $loggerRef.Info([string]$InputObject)
                }
            } catch {}
        }

        # define global function Write-Host to capture Write-Host calls
        $writeHostScript = {
            param(
                [Parameter(ValueFromRemainingArguments=$true)]
                $Args
            )
            $loggerRef = $global:LoggerCaptureInstance
            if ($null -eq $loggerRef) { return }
            try {
                # join args similar to Write-Host behavior
                $msg = ($Args -join ' ')
                $loggerRef.Info($msg)
            } catch {}
        }

        # expose loggerRef globally so the functions can access it without $this
        $global:LoggerCaptureInstance = $this

        # install functions in global scope (overrides)
        Set-Item -Path Function:\Out-Default -Value $outDefaultScript -Force
        Set-Item -Path Function:\Write-Host -Value $writeHostScript -Force
    }
    $logger | Add-Member -MemberType ScriptMethod -Name StartCapture -Value $startCapture

    # StopCapture: restore saved functions
    $stopCapture = {
        if (-not $this._CaptureActive) { return }
        $this._CaptureActive = $false

        $save = $this._SavedFunctions
        foreach ($fn in 'Out-Default','Write-Host') {
            $entry = $save[$fn]
            if ($null -eq $entry) {
                # remove our override so original cmdlet is used
                if (Test-Path "Function:\$fn") { Remove-Item "Function:\$fn" -ErrorAction SilentlyContinue }
            } elseif ($entry.Type -eq 'Function') {
                Set-Item -Path Function:\$fn -Value $entry.Definition -Force
            } else {
                # remove function override to let original cmdlet be used
                if (Test-Path "Function:\$fn") { Remove-Item "Function:\$fn" -ErrorAction SilentlyContinue }
            }
        }

        Remove-Variable LoggerCaptureInstance -Scope Global -ErrorAction SilentlyContinue
    }
    $logger | Add-Member -MemberType ScriptMethod -Name StopCapture -Value $stopCapture

    return $logger
}
Export-ModuleMember -Function Logger