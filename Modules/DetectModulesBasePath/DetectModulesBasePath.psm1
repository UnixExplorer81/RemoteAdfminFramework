function DetectModulesBasePath {
    param(
        [Parameter(Mandatory)]
        [string]$GlobalModulePath,
        [Parameter(Mandatory)]
        [string]$UserModulePath     
    )
    
    $testFile = Join-Path $GlobalModulePath "test_write_access.tmp"
    try {
        Set-Content -Path $testFile -Value "test" -Force -ErrorAction Stop
        Remove-Item $testFile -Force -ErrorAction Stop
        return $GlobalModulePath
    } catch {
        return $UserModulePath 
    }
}