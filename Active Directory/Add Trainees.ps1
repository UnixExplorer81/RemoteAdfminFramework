# Number of users to be created
$count = 30

# OU and other information
$ou = "OU=Agents,DC=topcall,DC=inc"
$domain = "topcall.inc"
$pwd = "TopCall.Inc"
$profileBase = "\\DC-1\Roaming_Profiles$"

# Active Directory settings for users
$canchpwd = $false
$mustchpwd = $false
$pwdneverexpires = $true
$disabled = $false

# Loop to create users
For ($i = 1; $i -le $count; $i++) {

    # Username with leading zero for single-digit IDs
    if ($i -lt 10) {
        $username = "Trainee-0$i"
    } else {
        $username = "Trainee-$i"
    }

    # Profile path for the user
    $profile = "$profileBase\$username"

    # Debugging output (optional)
    Write-Host "Creating user: $username"
    Write-Host "Profile path: $profile"

    # Create the user object
    New-ADUser `
        -SamAccountName $username `
        -UserPrincipalName "$username@$domain" `
        -Name $username `
        -Path $ou `
        -AccountPassword (ConvertTo-SecureString $pwd -AsPlainText -Force) `
        -ProfilePath $profile `
        -CannotChangePassword $canchpwd `
        -PasswordNeverExpires $pwdneverexpires `
        -Enabled ($disabled -eq $false) `
        -ChangePasswordAtLogon $mustchpwd
}

# Pause for debugging purposes
Pause
