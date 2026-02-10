using module ApiRequest
using module ADUserSync
using module ConvertToHashtable

<#
$Users = ApiRequest -ConfigPath "..\ConfigFiles\DomainAccountsApiConfig.json"

$cfg = "..\ConfigFiles\DomainConfig.json"
$params = Get-Content $cfg | ConvertFrom-Json | ConvertToHashtable
ADUserSync -Users $Users @params -WhatIf
#>

# =====================================================================
# Interactive ADUserSync Launcher
# =====================================================================

# Function: Read-YesNo
function Read-YesNo($Prompt, [bool]$DefaultYes = $true) {
    $answer = if ($DefaultYes) { 'Y' } else { 'N' }
    $input = Read-Host "$Prompt [Y/N] (default: $answer)"
    if ([string]::IsNullOrWhiteSpace($input)) { return $DefaultYes }
    return $input.Trim().ToUpper().StartsWith('Y')
}

# Load users from API
Write-Host "🔄 Loading user list from API..." -ForegroundColor Cyan
$Users = ApiRequest -ConfigPath "..\ConfigFiles\DomainAccountsApiConfig.json"
Write-Host "✅ Loaded $($Users.Count) users." -ForegroundColor Green
Write-Host ""

# Load domain config
$cfgPath = "..\ConfigFiles\DomainConfig.json"
$params = Get-Content $cfgPath | ConvertFrom-Json | ConvertToHashtable

# Display and edit GroupFilter interactively
$originalGroups = $params.GroupFilter -join ', '
Write-Host "Current GroupFilter: $originalGroups" -ForegroundColor Yellow
$edit = Read-YesNo "Do you want to modify the GroupFilter?" $false

if ($edit) {
    $newGroups = Read-Host "Enter new comma-separated groups"
    if (-not [string]::IsNullOrWhiteSpace($newGroups)) {
        $params.GroupFilter = $newGroups.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        Write-Host "✅ Updated GroupFilter: $($params.GroupFilter -join ', ')" -ForegroundColor Green
    }
}
Write-Host ""

# Ask for dry-run (WhatIf)
$dryRun = Read-YesNo "Run in dry-run mode (WhatIf)?" $true

# Summary
Write-Host ""
Write-Host "========================================="
Write-Host "ADUserSync Configuration Summary" -ForegroundColor Cyan
Write-Host "========================================="
Write-Host "Groups:     $($params.GroupFilter -join ', ')"
Write-Host "Mode:       $(if ($dryRun) { 'Dry-run (WhatIf)' } else { 'Active' })"
Write-Host "========================================="
Write-Host ""

# Confirm and execute
if (Read-YesNo "Proceed with execution?" $true) {
    if ($dryRun) {
        ADUserSync -Users $Users @params -WhatIf
    } else {
        ADUserSync -Users $Users @params
    }
    Write-Host "`n✅ ADUserSync completed." -ForegroundColor Green
} else {
    Write-Host "`nOperation cancelled." -ForegroundColor DarkYellow
}
PAUSE