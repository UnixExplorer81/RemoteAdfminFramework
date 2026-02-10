function GetUserProfilePath {
    <#
    .SYNOPSIS
        Retrieves the local profile path of a specific or currently logged-on user,
        matching the actual user SID instead of assuming folder names.

    .PARAMETER Username
        Optional. The username to search for (e.g., "DOMAIN\jdoe" or "jdoe").
        If omitted, the currently active user will be used.

    .OUTPUTS
        [string] The full profile path (e.g. "C:\Users\jdoe"), or $null if not found.

    .EXAMPLE
        Get-UserProfilePath
        # Returns the profile path of the currently active user.

    .EXAMPLE
        Get-UserProfilePath -Username "jdoe"
        # Returns the profile path for user "jdoe" (searches all loaded profiles).
    #>

    [CmdletBinding()]
    param (
        [string]$Username
    )

    # If no user name was transferred → Determine active user
    if (-not $Username) {
        $Username = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
        if (-not $Username) {
            Write-Warning "❌ No user currently logged in."
            return $null
        }
    }
    # extract username of domain\username
    $shortName = $Username.Split('\')[-1]

    try {
        # try to get the SID
        $sid = ([System.Security.Principal.NTAccount]$shortName).Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {
        Write-Warning "❌ Could not resolve SID for user '$shortName'"
        return $null
    }

    try {
        # get the user profile object from regestry that matches the SID
        $userprofile = Get-CimInstance -ClassName Win32_UserProfile |
            Where-Object { $_.SID -eq $sid -and $_.Loaded -and -not $_.Special }

        if ($userprofile) {
            return $userprofile.LocalPath
        } else {
            Write-Warning "❌ No loaded user profile found for '$shortName'"
            return $null
        }
    } catch {
        Write-Warning "❌ Failed to get user profile: $_"
        return $null
    }
}
<#
$profilePath = Get-Process -Name explorer -ErrorAction SilentlyContinue |
                Select-Object -First 1 |
                ForEach-Object { $_.StartInfo.EnvironmentVariables["USERPROFILE"] }
#>