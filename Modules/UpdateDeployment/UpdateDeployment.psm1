<#
using module UpdateDeployment

$Jobs = @(
    @{
        "\\dc-1\nas\Scripts\PowerShell" = "C:\Windows\System32\WindowsPowerShell\v1.0\Modules"
        files = @{
            "ScriptVersionGuard\ScriptVersionGuard.psm1" = "ScriptVersionGuard\ScriptVersionGuard.psm1"
            "UpdateDeployment\UpdateDeployment.psm1" = "UpdateDeployment\UpdateDeployment.psm1"
            "NetConfigurator\NetConfigurator.psm1" = "NetConfigurator\NetConfigurator.psm1"
            "Logger\classLogger.psm1" = "Logger\Logger.psm1"
        }
    },
    @{
        "\\dc-1\nas\Profiles\Agents" = "C:\Users\*"
        directories = @{
            "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" = "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
        }
        exceptions = @{
            directories = @("Administrator", "Administrator.*", "Default")
        }
    },
    @{
        directories = @{
            "\\dc-1\nas\Profiles\Agents\Desktop" = "C:\Users\Public\Desktop"
        }
        deletes = @(
            "c:\users\*\Desktop\*.html",
            "c:\users\*\Desktop\*.lnk",
            "c:\users\*\Desktop\*.url",
            "c:\users\*\Desktop\*.jpg",
            "c:\users\*\Desktop\*.png",
            "c:\users\*\Desktop\*.gif",
            "c:\users\*\Desktop\*.svg",
            "c:\users\*\Desktop\New *"
        )
    },
    @{
        "\\dc-1\nas\Profiles\Agents" = "C:\ProgramData"
        directories = @{
            "DCSB Nuspray" = "DCSB"
        }        
        deletes = @("DCSB\*") // tidy up rule if configuration got changed significent
    },
    @{
        deletes = @(
            "C:\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\*.lnk"
            "C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\*.lnk"
            "C:\Users\Administrator.*\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\*.lnk"
        )
    }
)

UpdateDeployment -Jobs $Jobs -EnableDebugLogging
#>


$modeKeys = @('files', 'directories', 'exceptions', 'deletes')

function UpdateDeployment {

    param (
        [Parameter(Mandatory)][object[]]$Jobs,
        [switch]$EnableDebugLogging,
        [string]$LogPath = "C:\Windows\Logs\PowerShell\UpdateDeployment.log",
        [long]$MaxLogSize = 1024KB
    )

    $logDir = Split-Path $LogPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    # Log header
    writeLog @(
        appendLog "🖥️ $env:COMPUTERNAME - Running as: 👤 $(whoami)" "force"
        appendLog "────────────────────────────────────────────" "force"
    )

    # Run all jobs simultaniously
    $jobList = foreach ($job in $Jobs) {
        Start-Job -ArgumentList $job -ScriptBlock {
            param ($job)
            Import-Module UpdateDeployment
            ProcessJob -job $job
        }
    }
    
    # collecting results
    $jobList | ForEach-Object {
        $null = Wait-Job $_
        $logRecords = Receive-Job $_
        Remove-Job $_
        writeLog -Entries $logRecords
        writeLog @(
            appendLog "────────────────────────────────────────────" "force"
        )
    }

    # Log footer
    writeLog @(
        appendLog "✅ Deployment complete`n" "force"
    )
    
    truncateLog
}

function CreateJob {
    param (
        [Parameter(Mandatory)]
        [object]$Deployments
    )
    $files = @{}
    $Deployments.Values | ForEach-Object {
        $files[$_.source] = $_.target
    }
    return @{ files = $files }
}

function ProcessJob {
    param (
        [object]$job
    )
    $log = @()
    $hasBasePaths = hasBasePaths -job $job
    if (-not $hasBasePaths) {
        # === summarize updateable files / directories ===
        $plannedTargets = planTargets -job $job -log ([ref]$log)
        # === process deletes ===
        processDeletes -job $job -exceptions $plannedTargets -log ([ref]$log)
        if($plannedTargets.Count){
            # === get missing and updated files ===
            processFileUpdates -job $job -log ([ref]$log)
            # === get missing directories ===
            processDirectoryUpdates -job $job -log ([ref]$log)
        }
    }
    if($hasBasePaths){
        $basePaths  = basePaths -job $job
        $log += appendLog "📁 SourceBase: $($basePaths.Source)"
        $log += appendLog "📁 TargetBase: $($basePaths.Target)"
        # === summarize updateable files / directories ===
        $plannedTargets = planTargets -job $job -sourceBase $basePaths.Source -targetBase $basePaths.Target -log ([ref]$log)
        # === process deletes ===
        processDeletes -job $job -targetBase $basePaths.Target -exceptions $plannedTargets -log ([ref]$log)
        if($plannedTargets.Count){
            # === get missing and updated files ===
            processFileUpdates -job $job -sourceBase $basePaths.Source -targetBase $basePaths.Target -log ([ref]$log)
            # === get missing directories ===
            processDirectoryUpdates -job $job -sourceBase $basePaths.Source -targetBase $basePaths.Target -log ([ref]$log)
        }
    }
    return $log
}

function hasBasePaths{
    param (
        [object]$job
    )
    return ($job.Keys | Where-Object { $_ -notin $modeKeys }).Count -gt 0
}

function basePaths {
    param (
        [object]$job
    )
    $sourceBase = ($job.Keys | Where-Object { $_ -notin $modeKeys }) | Select-Object -First 1
    $targetBase = $job[$sourceBase]
    return @{
        Source = if (isValidPath $sourceBase) { $sourceBase } else { $null }
        Target = if (isValidPath $targetBase) { $targetBase } else { $null }
    }
}

function isValidPath {
    param (
        [string]$path
    )
    return $path -match '^(?:[a-zA-Z]:\\|\\\\[^\\]+\\[^\\]+)'
}

function planTargets {
    param (
        [object]$job,
        [string]$sourceBase = $null,
        [string]$targetBase = $null,
        [ref]$log
    )
    $plannedTargets = @()
    if ($job.Keys -contains 'files') {
        foreach ($relSourcePath in $job.files.Keys) {
            $relTargetPath = $job.files[$relSourcePath]
            $sourceFile = if($sourceBase) { Join-Path $sourceBase $relSourcePath }else{ $relSourcePath }
            $plannedTarget = if($targetBase) { Join-Path $targetBase $relTargetPath }else{ $relTargetPath }
            if (-not (Test-Path $sourceFile)) {
                $log.Value += appendLog "❌ Source file not found: $sourceFile" "error"
                continue
            }
            $plannedTargets += $plannedTarget
        }
    }
    if ($job.Keys -contains 'directories') {
        foreach ($relSourcePath in $job.directories.Keys) {
            $relTargetPath = $job.directories[$relSourcePath]
            $sourceDir = if($sourceBase) { Join-Path $sourceBase $relSourcePath }else{ $relSourcePath }
            $targetDir = if($targetBase) { Join-Path $targetBase $relTargetPath }else{ $relTargetPath }
            if (-not (Test-Path $sourceDir)) {
                $log.Value += appendLog "❌ Source directory not found: $sourceDir" "error"
                continue
            }
            if (Test-Path $sourceDir) {
                try {
                    Get-ChildItem -Path $sourceDir -Recurse -Force | ForEach-Object {
                        $relItemPath = $_.FullName.Substring($sourceDir.Length).TrimStart('\')
                        $plannedTargets += Join-Path $targetDir $relItemPath
                    }
                } catch {
                    $log.Value += appendLog "⚠️ Failed to scan directory '$sourceDir': $($_.Exception.Message)" "error"
                }
            }
        }
    }
    return $plannedTargets
}

function ResolveWildcardTargets {
    param (
        [Parameter(Mandatory)][string]$PathPattern,
        [string[]]$ExcludedPatterns = @(),
        [ref]$Log,
        [switch]$Recurse
    )
    $resolved = @()
    try {
        $wildIndex = [regex]::Match($PathPattern, '[\*\?\[]').Index
        $basePath  = $PathPattern.Substring(0, $wildIndex)
        $items = Get-ChildItem -Path $PathPattern -Force -ErrorAction SilentlyContinue -Recurse:($Recurse.IsPresent)
        $Log.Value += appendLog "🔍 Wildcard scan in: $PathPattern ($($items.Count) matches)"
        foreach ($item in $items) {
            $candidate = ($item.FullName -replace [regex]::Escape($basePath), '') -split '\\' | Select-Object -First 1
            $skip = $false
            foreach ($pattern in $ExcludedPatterns) {
                if ($candidate -like $pattern -or $candidate -match $pattern) {
                    $skip = $true
                    $Log.Value += appendLog "🚫 Skipping excluded path: $candidate ($($item.FullName))"
                    break
                }
            }
            if (-not $skip) { $resolved += $item }
        }
    } catch {
        $Log.Value += appendLog "❌ Wildcard resolution failed for $PathPattern`: $($_.Exception.Message)" "error"
    }
    return $resolved
}

function processDeletes {
    param (
        [object]$job,
        [string]$targetBase = $null,
        [string[]]$exceptions = @(),
        [ref]$log
    )
    if (-not $job.Keys -contains 'deletes' -or $job.deletes.Count -lt 1) { return }

    # collect optional delete exceptions
    $excludedPatterns = @()
    if ($job.Keys -contains 'exceptions' -and $job.exceptions.Keys -contains 'deletes') {
        $excludedPatterns = $job.exceptions.deletes
        $log.Value += appendLog "⚙️ Delete exceptions defined: $($excludedPatterns -join ', ')"
    }

    $log.Value += appendLog "🧹 Processing deletes..." "info"
    foreach ($relDelPath in $job.deletes) {
        $delTarget = if($targetBase) { Join-Path $targetBase $relDelPath }else{ $relDelPath }
        # === wildcard deletes ===
        if ($delTarget -like "*[*?]*") {
            $wildItems = ResolveWildcardTargets -PathPattern $delTarget -ExcludedPatterns $excludedPatterns -Log $log
            foreach ($item in $wildItems) {
                $fullPath = $item.FullName
                # Ist das Item (oder ein übergeordnetes) in den geplanten Zielen enthalten?
                $updateCheckPlanned = $exceptions | Where-Object {
                    $_ -eq $fullPath -or $fullPath.StartsWith($_ + "\")
                }
                if ($updateCheckPlanned) {
                    continue
                }
                try {
                    if ($item.PSIsContainer) {
                        Remove-Item -Path $fullPath -Recurse -Force -ErrorAction Stop
                        $log.Value += appendLog "📁 Directory removed (wildcard match): $fullPath"
                    } elseif (-not (testFileLock -Path $fullPath)) {
                        Remove-Item $fullPath -Force -ErrorAction Stop
                        $log.Value += appendLog "📄 File removed (wildcard match): $fullPath"
                    } else {
                        $log.Value += appendLog "🚫 File in use by another process: $fullPath"
                    }
                } catch {
                    $log.Value += appendLog "❌ Failed to delete $fullPath`: $($_.Exception.Message)" "error"
                }
            }
        # === regular deletes ===
        } else {
            if ($exceptions -contains $delTarget) {
                continue
            }
            try {
                if (Test-Path $delTarget) {
                    $attr = (Get-Item $delTarget).Attributes
                    if ($attr -match "Directory") {
                        Remove-Item $delTarget -Recurse -Force
                        $log.Value += appendLog "📁 Directory removed: $delTarget"
                    } else {
                        Remove-Item $delTarget -Force
                        $log.Value += appendLog "📄 File removed: $delTarget"
                    }
                } else {
                    $log.Value += appendLog "ℹ️ Nothing to remove at: $delTarget"
                }
            } catch {
                $log.Value += appendLog "❌ Failed to remove $delTarget`: $($_.Exception.Message)" "error"
            }
        }
    }
}

function processFileUpdates {
    param (
        [object]$job,
        [string]$sourceBase = $null,
        [string]$targetBase = $null,
        [ref]$log
    )
    if (-not $job.Keys -contains 'files') { return }

    # collect optional file exceptions
    $excludedPatterns = @()
    if ($job.Keys -contains 'exceptions' -and $job.exceptions.Keys -contains 'files') {
        $excludedPatterns = $job.exceptions.files
        $log.Value += appendLog "⚙️ File exceptions defined: $($excludedPatterns -join ', ')"
    }

    foreach ($relPath in $job.files.Keys) {
        $sourceFile = if ($sourceBase) { Join-Path $sourceBase $relPath } else { $relPath }
        $targetFile = if ($targetBase) { Join-Path $targetBase $job.files[$relPath] } else { $job.files[$relPath] }
        $log.Value += appendLog "🔍 Comparing: $sourceFile → $targetFile"
        if (-not (Test-Path $sourceFile)) {
            $log.Value += appendLog "❌ Source file not found: $sourceFile" "error"
            continue
        }
        # === wildcard file updates ===
        if ($targetFile -like "*[*?]*") {
            $wildItems = ResolveWildcardTargets -PathPattern $targetFile -ExcludedPatterns $excludedPatterns -Log $log
            foreach ($item in $wildItems) {
                copyFileIfOutdatedOrMissing -sourceFile $sourceFile -targetFile $item.FullName -log $log
            }
        # === regular file updates ===
        } else {
            copyFileIfOutdatedOrMissing -sourceFile $sourceFile -targetFile $targetFile -log $log
        }
    }
}

function processDirectoryUpdates {
    param (
        [object]$job,
        [string]$sourceBase = $null,
        [string]$targetBase = $null,
        [ref]$log
    )

    if (-not $job.Keys -contains 'directories') { return }

    # collect optional directory exceptions
    $excludedPatterns = @()
    if ($job.Keys -contains 'exceptions' -and $job.exceptions.Keys -contains 'directories') {
        $excludedPatterns = $job.exceptions.directories
        $log.Value += appendLog "⚙️ Directory exceptions defined: $($excludedPatterns -join ', ')"
    }

    foreach ($relPath in $job.directories.Keys) {
        $sourceDir = if ($sourceBase) { Join-Path $sourceBase $relPath } else { $relPath }
        $targetDir = if ($targetBase) { Join-Path $targetBase $job.directories[$relPath] } else { $job.directories[$relPath] }

        # === wildcard directory updates ===
        if ($targetDir -like "*[*?]*") {
            $wildItems = ResolveWildcardTargets -PathPattern $targetDir -ExcludedPatterns $excludedPatterns -Log $log
            foreach ($item in $wildItems) {
                processDirectorySync -sourceDir $sourceDir -targetDir $item.FullName -log $log
            }
        # === regular directory updates ===
        } else {
            $log.Value += appendLog "🧹 Processing regular directory update: $targetDir"
            processDirectorySync -sourceDir $sourceDir -targetDir $targetDir -log $log
        }
    }
}

function isFileOutdated {
    param (
        [string]$sourceFile,
        [string]$targetFile
    )
    if (-not (Test-Path $targetFile)) {
        return $true
    }
    $srcItem = Get-Item $sourceFile
    $dstItem = Get-Item $targetFile
    if ($srcItem.LastWriteTime -ne $dstItem.LastWriteTime) {
        try {
            $srcHash = Get-FileHash $sourceFile -Algorithm SHA256
            $dstHash = Get-FileHash $targetFile -Algorithm SHA256
            return ($srcHash.Hash -ne $dstHash.Hash)
        } catch {
            return $true  # Wenn Hash fehlschlägt: lieber kopieren
        }
    }
    return $false
}

function copyFileIfOutdatedOrMissing {
    param (
        [string]$sourceFile,
        [string]$targetFile,
        [ref]$log
    )
    $targetFolder = Split-Path $targetFile -Parent
    if (-not (Test-Path $targetFolder)) {
        New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
        $log.Value += appendLog "📁 Created directory: $targetFolder"
    }
    if (isFileOutdated -sourceFile $sourceFile -targetFile $targetFile) {
        try {
            Copy-Item -Path $sourceFile -Destination $targetFile -Force
            $log.Value += appendLog "📂 Copied: $sourceFile → $targetFile"
        } catch {
            $log.Value += appendLog "❌ Failed to copy $sourceFile`: $($_.Exception.Message)" "error"
        }
    } else {
        $log.Value += appendLog "✅ File up to date: $targetFile"
    }
    # Remove Zone.Identifier
    try {
        $zoneFile = "$targetFile`:Zone.Identifier"    
        if (Test-Path $zoneFile) {
            Remove-Item $zoneFile -Force -ErrorAction Stop
            $log.Value += appendLog "🔓 Removed Zone.Identifier from $targetFile"
        }
    } catch {
        $log.Value += appendLog "⚠️ Could not remove Zone.Identifier: $($_.Exception.Message)" "warn"
    }
}

function processDirectorySync {
    param (
        [string]$sourceDir,
        [string]$targetDir,
        [ref]$log
    )
    $log.Value += appendLog "📁 Syncing directory: $sourceDir → $targetDir"
    Get-ChildItem -Path $sourceDir -Recurse -File | ForEach-Object {
        $relPath = $_.FullName.Substring($sourceDir.Length).TrimStart('\')
        $sourceFile = $_.FullName
        $targetFile = Join-Path $targetDir $relPath
        $log.Value += appendLog "🔍 Checking file: $sourceFile"
        copyFileIfOutdatedOrMissing -sourceFile $sourceFile -targetFile $targetFile -log $log
    }
}

function testFileLock {
    param ([string]$Path)
    try {
        $stream = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None')
        $stream.Close()
        return $false  # Not locked
    } catch {
        return $true   # Locked
    }
}

function appendLog {
    param (
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet("info", "warn", "error", "force")]
        [string]$Level = "info"
    )
    return [pscustomobject]@{
        Text  = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
        Level = $Level
    }
}

function writeLog {
    param (
        [pscustomobject[]]$Entries
    )
    # === check for max log size ===
    foreach ($entry in $Entries) {
        $write = $false
        switch ($entry.Level) {
            "force" { $write = $true }
            "error" { $write = $true }
            "warn"  { if ($EnableDebugLogging) { $write = $true } }
            "info"  { if ($EnableDebugLogging) { $write = $true } }
        }
        if ($write) {
            $entry.Text | Out-File -FilePath $LogPath -Encoding UTF8 -Append
            Write-Host $entry.Text
        }
    }
}

function truncateLog {   
    if (Test-Path $LogPath) {
        $logSize = (Get-Item $LogPath).Length
        if ($logSize -gt $MaxLogSize) {
            try {
                $lines = Get-Content -Path $LogPath -Tail 3000
                $lines | Out-File -FilePath $LogPath -Encoding UTF8
                Write-Host "🧹 Log truncated (size exceeded $([math]::Round($logSize / 1KB)) KB)"
            } catch {
                Write-Host "⚠️ Failed to truncate oversized log: $($_.Exception.Message)"
            }
        }
    }
}
Export-ModuleMember -Function UpdateDeployment, CreateJob, ProcessJob
<#
function testBasePaths{
    $job = @{
        "\\dc-1\nas\Profiles\Agents" = "C:\ProgramData"
        directories = @{
            "DCSB Nuspray" = "DCSB"
        }
    }
    $basePaths = basePaths -job $job
    foreach($basePathKey in $basePaths.Keys){
        Write-Host "$basePathKey`: $($basePaths[$basePathKey])"
    }
}
function testPlanTargets{
    $job = @{
        "\\dc-1\nas\Profiles\Agents" = "C:\ProgramData"
        directories = @{
            "DCSB Nuspray" = "DCSB"
        }
    }
    $basePaths = basePaths -job $job
    $targets = planTargets -job $job -sourceBase $basePaths.Source -targetBase $basePaths.Target
    foreach($target in $targets){
        Write-Host "$target"
    }
}
#>