param(
    [string]$psRegistryPath = "\\dc-1\NAS\Scripts\PowerShell\PsRegistry\PsRegistry.psm1",
    [hashtable]$PsRegistryConfig = @{
        source = "\\dc-1\NAS\Scripts\PowerShell\ConfigFiles\PsRegistryConfig.psd1"
        target = "C:\ProgramData\PowerShell\PsRegistryConfig.psd1"
    }
)

function GetHash {
    param(
        [string]$file,
        [int]$Retries = 3
    )
    if (-not (Test-Path $file)) {
        return $null
    }
    try {
        return (Get-FileHash -Path $file -Algorithm SHA256 -ErrorAction Stop).Hash
    } catch {
        if ($Retries -gt 1) {
            Start-Sleep -Seconds 1
            return GetHash -file $file -Retries ($Retries - 1)
        }
        return $null
    }
}

# Bootstrap
Invoke-Expression (Get-Content $psRegistryPath -Raw)
$Registry = [PsRegistry]::new($PsRegistryConfig)

$srcHash = GetHash $Registry.UpdateDeployment.source
$dstHash = GetHash $Registry.UpdateDeployment.target

# Status-Code:
# 0 = Error
# 1 = Is up to date
# 2 = Gets installed
# 3 = Gets updated
[int]$status = 0
if (-not $dstHash) {
    $status = 2
}elseif ($srcHash -eq $dstHash) {
    $status = 1
}elseif (-not ($srcHash -eq $dstHash)) {
    $status = 3
}

if($status -ne 1){
    try {
        Invoke-Expression (Get-Content $Registry.UpdateDeployment.source -Raw)
        UpdateDeployment -Jobs (CreateJobs -Deployments @($Registry.UpdateDeployment)) `
                            -EnableDebugLogging:$EnableDebugLogging
    } catch {
        $status = $_
    }
}

return $status