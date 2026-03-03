param(
    [bool]$EnableDebugLogging = $true,
    [string]$logPath = "C:\Windows\Temp\UpdateDeployment.log",
    [hashtable]$UpdateDeployment = @{
        source = "\\topcall.inc\shares\PowerShell_Framework$\Modules\UpdateDeployment\UpdateDeployment.psm1"
        target = "C:\Program Files\WindowsPowerShell\Modules\UpdateDeployment\UpdateDeployment.psm1"
    }
)

if (-not (Test-Path $UpdateDeployment.source)) {
    WriteLog "❌ Source module not found: $($UpdateDeployment.source)" -error
    exit 2
}

function WriteLog($msg, [switch]$warning, [switch]$error, [switch]$force) {
    $force = if($error){$error}else{$force}
    if (-not $EnableDebugLogging -and -not $force) { return }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $msg"
    $line | Out-File -FilePath $logPath -Encoding UTF8 -Append
    if($error){
        Write-Error $line
    }elseif($warning){
        Write-Warning $line
    }else{
        Write-Host $line
    }
}

function EnsureDirectory([string]$target){
    try{
        if (-not (Test-Path $target)) {
            New-Item -Path $target -ItemType Directory -Force -ErrorAction Stop | Out-Null
            WriteLog "📁 Created target directory: $target"
        }
    } catch {
        WriteLog "❌ Failed to create directory: $($_.Exception.Message)" -error
    }
}

$userModulePath = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules"
$globalModulePath = "C:\Windows\System32\WindowsPowerShell\v1.0\Modules"
$testFile = Join-Path $globalModulePath "test_write_access.tmp"
try {
    Set-Content -Path $testFile -Value "test" -Force -ErrorAction Stop
    Remove-Item $testFile -Force -ErrorAction Stop
} catch {
    EnsureDirectory($userModulePath)
    $moduleFolder = Split-Path (Split-Path $UpdateDeployment.target -Parent) -Leaf
    $UpdateDeployment.target = Join-Path (Join-Path $userModulePath $moduleFolder) (Split-Path $UpdateDeployment.target -Leaf)
}

WriteLog "🖥️ $env:COMPUTERNAME - Running as: 👤 $(whoami)"
WriteLog "────────────────────────────────────────────"
if (Test-Path $UpdateDeployment.target) {
    try {
        $srcHash = Get-FileHash $UpdateDeployment.source -Algorithm SHA256
        $dstHash = Get-FileHash $UpdateDeployment.target -Algorithm SHA256
        if ($srcHash.Hash -eq $dstHash.Hash) {
            WriteLog "✅ UpdateDeployment already up to date.`n"
            return $true
        } else {
            WriteLog "🔄 UpdateDeployment hash mismatch. Updating..."
        }
    } catch {
        WriteLog "⚠️ Failed to compare hashes: $($_.Exception.Message)" -warning
    }
} else {
    WriteLog "➕ UpdateDeployment not found. Deploying..."
}

try {
    $target = Split-Path $UpdateDeployment.target -Parent
    EnsureDirectory($target)
    WriteLog "────────────────────────────────────────────"
    Copy-Item $UpdateDeployment.source $UpdateDeployment.target -Force
    WriteLog "✅ Deployed to $($UpdateDeployment.target)`n"
    return $false  # Erstmalige Kopie → Neustart erforderlich
} catch {
    WriteLog "❌ Failed to deploy: $($_.Exception.Message)`n" -error
    exit 1
}
