using module FileAndDirectoryOperations

class Logger {

    [hashtable]$LogFiles = @{}
    [bool]$UseConsole
    [int]$MaxLogSize

    # Logger($params) {
    #     if (-not EnsureDirectory $params.LogInfo) { throw "Logger: Failed to create directory: $($params.LogInfo)" }
    #     elseif (-not TestDirectoryWriteAccess (Split-Path $params.LogInfo -Parent)) { throw "Logger: No write access of directory: $(Split-Path $params.LogInfo -Parent)" }
    #     elseif (-not TestWriteAccess $params.LogInfo) { throw "Logger: No write access of : $($params.LogInfo)" }
    #     $this.LogFiles.Info     = $params.LogInfo
    #     $this.LogFiles.Error    = if(($null -ne $params.LogErrors) -and (-not TestWriteAccess $params.LogErrors)) { throw "Logger: No write access on $($params.LogErrors)" }
    #     else { $params.LogInfo }
    # }
    Logger($params) {
        if ($null -eq $params.LogInfo) { throw "Logger: Parameter LogInfo is required!" }

        # Directory & Access Checks
        if (-not (EnsureDirectory $params.LogInfo)) { 
            throw "Logger: Failed to create directory for LogInfo: $($params.LogInfo)"
        }
        if (-not (TestWriteAccess $params.LogInfo)) { 
            throw "Logger: No read/write access for LogInfo: $($params.LogInfo)"
        }
        $this.LogFiles.Info         = $params.LogInfo

        # LogErrors optional
        $this.LogFiles.Error = $this.LogFiles.Info
        if ($null -ne $params.LogErrors) {
            if (-not (EnsureDirectory $params.LogErrors)) { 
                throw "Logger: Failed to create directory for LogErrors: $($params.LogErrors)"
            }
            if (-not (TestWriteAccess $params.LogErrors)) { 
                throw "Logger: No read/write access for LogErrors: $($params.LogErrors)"
            }
            $this.LogFiles.Error = $params.LogErrors
        }
        $this.LogFiles.Warn     = $this.LogFiles.Error

        $Params.HostName        = if ($Params.HostName -is [string]){ $Params.HostName } else { 'ConsoleHost' }
        $Params.CatchOutputs    = if ($Params.CatchOutputs -is [bool]){ $Params.CatchOutputs } else { $Params.HostName -ne 'ConsoleHost' }
        $this.UseConsole        = if ($params.UseConsole -is [bool]) { $params.UseConsole } else { $Params.HostName -eq 'ConsoleHost' }
        $this.MaxLogSize        = if ($params.MaxLogSize -is [int]) { $params.MaxLogSize } else { 512KB }
        # Auto-capture only in non-interactive mode
        if ($Params.CatchOutputs) {
            $this.CatchHostOutputs()
        }
    }
    
    [void]CatchHostOutputs() {

        # Alle Streams auf Continue setzen (nicht Stop oder SilentlyContinue)
        $global:WarningPreference = 'Continue'
        $global:ErrorPreference   = 'Continue'
        $global:VerbosePreference = 'Continue'
        $global:DebugPreference   = 'Continue'

        # Alle Ausgaben (inkl. Write-Host) in Information-Stream umleiten
        $global:InformationPreference = 'Continue'

        # Event-Handler für alle Streams
        Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
            Stop-LoggerCapture
        }

        # Echte Umleitung: Out-Default überschreiben (sehr mächtig)
        $global:originalOutDefault = Get-Command Out-Default

        Set-Alias Out-Default Out-LoggerProxy -Scope Global -Option AllScope

        function Out-LoggerProxy {
            [CmdletBinding()]
            param(
                [Parameter(ValueFromPipeline = $true)]
                $InputObject
            )

            process {
                if ($InputObject -is [System.Management.Automation.ErrorRecord]) {
                    $this.Error($InputObject.Exception.Message)
                }
                elseif ($InputObject -is [System.Management.Automation.WarningRecord]) {
                    $this.Warn($InputObject.Message)
                }
                elseif ($InputObject -is [System.Management.Automation.VerboseRecord]) {
                    $this.Verbose($InputObject.Message)
                }
                elseif ($InputObject -is [System.Management.Automation.DebugRecord]) {
                    $this.Debug($InputObject.Message)
                }
                else {
                    # Normale Ausgabe (inkl. Write-Host)
                    $this.Info($InputObject.ToString())
                }
            }
        }

        function Stop-LoggerCapture {
            Set-Alias Out-Default $global:originalOutDefault -Scope Global -Option AllScope
            Remove-Variable originalOutDefault -Scope Global -ErrorAction SilentlyContinue
            $this.Info("Logger->CatchHostOutputs: Capturing stopped")
        }
    }

    # Convenience Methods
    [void]Info([string]$message)    { $this.Log($message, 'Info') }
    [void]Warn([string]$message)    { $this.Log($message, 'Warning') }
    [void]Error([string]$message)   { $this.Log($message, 'Error') }
    [void]Success([string]$message) { $this.Log($message, 'Success') }
    [void]Debug([string]$message)   { $this.Log($message, 'Debug') }
    [void]Detect([string]$message)  { $this.Log($message, 'Detect') }
    [void]Update([string]$message)  { $this.Log($message, 'Update') }
    [void]Add([string]$message)     { $this.Log($message, 'Add') }
    [void]Remove([string]$message)  { $this.Log($message, 'Remove') }
    [void]Cleanup([string]$message) { $this.Log($message, 'Cleanup') }

    [void]Log([string]$message, [string]$level = 'info') {
        # Always write in the info log
        $this.writeLog($this.LogFiles.Info, $level, $message)

        # Additionally, separate logs depending on the level.
        switch ($level) {
            'error'   { $this.writeLog($this.LogFiles.Error, $level, $message) }
            'warning' { $this.writeLog($this.LogFiles.Warn,  $level, $message) }
            'debug'   { 
                if ($this.LogFiles.ContainsKey('Debug')) {
                    $this.writeLog($this.LogFiles['Debug'], $level, $message)
                }
            }
            default {
                if ($this.LogFiles.ContainsKey($level) -and $level -ne 'info') {
                    $this.writeLog($this.LogFiles[$level], $level, $message)
                }
            }
        }

        # Optional console output
        if ($this.UseConsole) {
            $color = switch ($level.ToLower()) {
                'info'      { 'Cyan' }
                'warning'   { 'Yellow' }
                'error'     { 'Red' }
                'success'   { 'Green' }
                'debug'     { 'DarkGray' }
                default     { 'White' }
            }
            Write-Host $message -ForegroundColor $color
        }    
    }

    hidden [void] writeLog([string]$path, [string]$level, [string]$message) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $icon    = $this.GetIcon($level)
        $logLine   = "$timestamp [$($level)] $icon $message"
        Add-Content -Path $path -Value $logLine -Encoding UTF8 -Force
        $this.truncate($path)
    }

    hidden [string]GetIcon([string]$level) {
        $prefixes = @{
            error    = "❌"
            warning  = "⚠️"
            info     = "ℹ️"
            success  = "✅"
            debug    = "🔧"
            detect   = "🔍"
            add      = "➕"
            remove   = "➖"
            update   = "🔄"
            cleanup  = "🗑️"
        }
        $key = $level.ToLower()
        if ($prefixes.ContainsKey($key)) {
            return $prefixes[$key]
        }else{
            return $prefixes.info
        }
    }

    # === check for max log size and truncate if necessary ===
    hidden [void] truncate([string]$path) {
        $this.truncate($path, $false)
    }
    hidden [void]truncate([string]$path, [bool]$Rotate) {
        if (-not (Test-Path $path)) { return }
        $logSize = (Get-Item $path).Length
        if ($logSize -le $this.MaxLogSize) { return }
        try {
            if ($Rotate) {
                $timestamp = (Get-Date).ToString("yyyy-MM-dd_HH:mm:ss")
                $backupPath = [IO.Path]::ChangeExtension($path, ".$timestamp.bak")
                Move-Item -Path $path -Destination $backupPath -Force
                $this.Info("Log rotated to $backupPath")
            } else {
                $lines = Get-Content -Path $path -Tail 3000
                $lines | Out-File -FilePath $path -Encoding UTF8
                $this.Info("Log truncated (size exceeded $([math]::Round($logSize / 1KB)) KB)")
            }
        } catch {
            $this.Error("Failed to truncate oversized log: $($_.Exception.Message)")
        }
    }
}

# class Logger {
#     hidden [bool] $CaptureOutput = $false
#     hidden [scriptblock] $OriginalOutDefault

#     Logger([hashtable] $config) {
#         # ... deine bestehende Initialisierung ...

#         $this.CaptureOutput = $config.CaptureOutput ?? $false

#         if ($this.CaptureOutput) {
#             $this.OriginalOutDefault = Get-Command Out-Default -CommandType Cmdlet

#             # Override Out-Default
#             Set-Alias Out-Default Out-LoggerRedirect -Scope Global -Option AllScope -Force

#             # Restore on exit
#             Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
#                 Set-Alias Out-Default $this.OriginalOutDefault -Scope Global -Option AllScope -Force
#             }
#         }
#     }

#     hidden static [void] Out-LoggerRedirect {
#         [CmdletBinding()]
#         param(
#             [Parameter(ValueFromPipeline = $true)]
#             $InputObject
#         )

#         process {
#             # Hole den Logger aus globalem Scope oder Context (je nach Setup)
#             $logger = $global:Context.Logger   # oder wie du ihn verfügbar machst

#             if ($null -eq $logger) {
#                 # Fallback
#                 $logger = [Logger]::new(@{ LogPath = "$env:TEMP\fallback.log" })
#             }

#             if ($InputObject -is [System.Management.Automation.ErrorRecord]) {
#                 $logger.Error($InputObject.Exception.Message)
#             }
#             elseif ($InputObject -is [System.Management.Automation.WarningRecord]) {
#                 $logger.Warn($InputObject.Message)
#             }
#             elseif ($InputObject -is [System.Management.Automation.VerboseRecord]) {
#                 $logger.Verbose($InputObject.Message)
#             }
#             elseif ($InputObject -is [System.Management.Automation.DebugRecord]) {
#                 $logger.Debug($InputObject.Message)
#             }
#             elseif ($InputObject -is [System.Management.Automation.InformationRecord]) {
#                 $logger.Info($InputObject.MessageData.ToString())
#             }
#             else {
#                 # Write-Host / normale Ausgabe
#                 $logger.Info($InputObject.ToString())
#             }
#         }
#     }
# }