<#
.SYNOPSIS
  Interactive helper to add/remove user accounts to/from an AD group using a generated username pattern or a regex.

.DESCRIPTION
  - Prompts for username syntax (format with zeros like Trainee-00, or regex /.../).
  - Prompts for Add or Remove operation.
  - Prompts for target group (name or DN).
  - Prompts for WhatIf (dry-run).
  - Resolves group DN if possible; previews affected users; executes with optional WhatIf.
#>

# ensure AD module
Import-Module ActiveDirectory -ErrorAction Stop

function Read-YesNo {
    param(
        [string]$Prompt,
        [bool]$DefaultYes = $true
    )
    # Default character for display
    $defaultChar = if ($DefaultYes) { 'Y' } else { 'N' }

    while ($true) {
        $input = Read-Host "$Prompt [Y/N] (default: $defaultChar)"
        if ($input -eq '') { return $DefaultYes }
        $c = $input.Trim().ToUpper()
        if ($c.StartsWith('Y')) { return $true }
        if ($c.StartsWith('N')) { return $false }
        Write-Host "Please answer 'Y' (yes) or 'N' (no)." -ForegroundColor Yellow
    }
}

Write-Host "Interactive Group Member Manager" -ForegroundColor Cyan
Write-Host "----------------------------------"

# 1) Username syntax
$syntax = Read-Host "Enter username syntax (use 0s as numeric placeholder, e.g. 'Trainee-00'), or enter a regex between slashes like /^Trainee-\\d{2}$/"

# detect regex mode (starts and ends with '/')
$regexMode = $false
if ($syntax -and $syntax.StartsWith('/') -and $syntax.EndsWith('/')) {
    $regexMode = $true
    # compile regex without the outer slashes
    $regexPattern = $syntax.Trim('/',' ')
    try { $regex = [regex]::new($regexPattern) } catch { throw "Invalid regex: $regexPattern" }
}

# 2) Add or Remove
$op = ''
while ($op -notin @('A','R')) {
    $opInput = Read-Host "Add or Remove? Enter A to add users to the group, R to remove users from the group"
    $op = $opInput.Trim().ToUpper()
}
$action = if ($op -eq 'A') { 'Add' } else { 'Remove' }

# 3) Group name / DN
$groupInput = Read-Host "Enter target group (group 'Name' or DistinguishedName)"
if (-not $groupInput) { throw "Group not provided, aborting." }

# try to resolve group object (prefer AD lookup)
$groupObj = Get-ADGroup -Identity $groupInput -ErrorAction SilentlyContinue
if (-not $groupObj) {
    # try filter by name
    $groupObj = Get-ADGroup -Filter { Name -eq $groupInput } -ErrorAction SilentlyContinue
}
if ($groupObj) {
    $groupDN = $groupObj.DistinguishedName
    Write-Host "Resolved group to DN: $groupDN"
} else {
    # fallback: assume provided value is DN or name; use it as identity but warn
    $groupDN = $groupInput
    Write-Warning "Group could not be resolved via Get-ADGroup. Will use '$groupDN' as identity (may fail if incorrect)."
}

# 4) WhatIf?
$doWhatIf = Read-YesNo "Run as dry-run (WhatIf)?" $true

# Build list of target users depending on mode
$targetUsers = @()

if ($regexMode) {
    # fetch current members of the group and filter by regex
    Write-Host "Fetching members of group '$groupDN'..." -ForegroundColor Yellow
    try {
        $members = Get-ADGroupMember -Identity $groupDN -Recursive -ErrorAction Stop | Where-Object { $_.ObjectClass -eq 'user' }
    } catch {
        throw "Failed to read group members for '$groupDN': $($_.Exception.Message)"
    }

    Write-Host "Filtering members by regex: $regexPattern"
    $targetUsers = $members | Where-Object { $regex.IsMatch($_.SamAccountName) }

} else {
    # format mode: find zeros placeholder
    $m = [regex]::Match($syntax, '0+')
    if (-not $m.Success) { throw "Format mode requires a sequence of one or more '0' characters as numeric placeholder, e.g. 'Trainee-00'." }
    $width = $m.Value.Length

    # ask for numeric range
    $startNumInput = Read-Host "Start number (default 1)"
    $endNumInput   = Read-Host "End number (default 99)"

    $startNum = if ($startNumInput -and [int]::TryParse($startNumInput,[ref]0)) { [int]$startNumInput } else { 1 }
    $endNum   = if ($endNumInput   -and [int]::TryParse($endNumInput,[ref]0))   { [int]$endNumInput   } else { 99 }

    if ($endNum -lt $startNum) { throw "End number must be >= start number." }
    if ($endNum -gt 10000) { throw "End number too large; aborting." }

    # convert placeholder to format string, e.g. Trainee-00 -> Trainee-{0:D2}
    $fmt = $syntax -replace '0+', "{0:D$width}"

    Write-Host "Generating names with format: $fmt (from $startNum to $endNum)" -ForegroundColor Yellow

    $names = for ($i = $startNum; $i -le $endNum; $i++) { $fmt -f $i }

    # resolve only existing AD users
    Write-Host "Looking up AD user accounts (only existing accounts will be included)..." -ForegroundColor Yellow
    foreach ($n in $names) {
        $u = Get-ADUser -Identity $n -ErrorAction SilentlyContinue
        if ($u) { $targetUsers += $u }
    }
}

# show preview
if (-not $targetUsers -or $targetUsers.Count -eq 0) {
    Write-Warning "No target users found based on your input. Exiting."
    return
}

Write-Host "`nPreview: $($targetUsers.Count) user(s) to $action in group '$groupDN':" -ForegroundColor Cyan
$targetUsers | Select-Object SamAccountName, Name, DistinguishedName | Format-Table -AutoSize

# perform or simulate
if ($doWhatIf) {
    Write-Host "`n--- WHATIF (dry-run) ---" -ForegroundColor Yellow
    if ($action -eq 'Remove') {
        Remove-ADGroupMember -Identity $groupDN -Members $targetUsers -Confirm:$false -WhatIf
    } else {
        Add-ADGroupMember -Identity $groupDN -Members $targetUsers -WhatIf
    }
    Write-Host "`nDry-run complete. No changes made."
    return
}

# final confirmation
$confirm = Read-YesNo "Proceed and actually $action these users in group '$groupDN'?" $false
if (-not $confirm) {
    Write-Host "Aborted by user."
    return
}

# execute
Write-Host "`nExecuting..." -ForegroundColor Green
try {
    if ($action -eq 'Remove') {
        Remove-ADGroupMember -Identity $groupDN -Members $targetUsers -Confirm:$false -ErrorAction Stop
    } else {
        Add-ADGroupMember -Identity $groupDN -Members $targetUsers -ErrorAction Stop
    }
    Write-Host "Operation completed successfully." -ForegroundColor Green
} catch {
    Write-Warning "Operation failed: $($_.Exception.Message)"
}
