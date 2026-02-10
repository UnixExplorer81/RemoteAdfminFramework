using module CreatePsStartFileLink
using module CredentialManager
using module TerminateFixRestart

param(
    [switch]$ExecutedByShortcut
)

if (-not $ExecutedByShortcut) {
    CreatePsStartFileLink -TargetScript $MyInvocation.MyCommand.Definition -PS7
    Pause
}

do {
    Clear-Host
    $inputValue = Read-Host "Enter client number"
    $id = $inputValue.Trim()
    $ComputerName = "192.168.1.$id"
    $Key = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
    $CredentialFile = Join-Path $env:USERPROFILE "AppData\Local\PowerShell\CredentialManager\DomainClients.xml"

    try{
        if (-not (Test-Path $CredentialFile)) {
            $parent = Split-Path -Path $CredentialFile -Parent
            if (-not (Test-Path $parent)) {
                New-Item -Path $parent -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
        }
    }catch{
        Write-Error "$parent doesn't exist and couldn't be created: $($_)"
    }

    try {
        $Credential = CredentialManager -Key $Key -Path $CredentialFile -User "TOPCALL\Administrator"
    }catch{
        Write-Error "This script must be run as Administrator!"
        Pause
    }

    $programEntry = [PSCustomObject]@{
        Path = "C:\Program Files (x86)\Deathcounter and Soundboard\DCSB.exe"
        Arguments   = "-silent"
        Callback    = {
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

            $dst = 'C:\ProgramData\DCSB\'
            $hostnameMatch = "^PC-(\d+)(\..+)?$"
            $ConfigFiles = @{
                "Bill"    = "config_Bill.xml"
                "John"    = "config_John.xml"
                "Luke"    = "config_Luke.xml"
                "Mark"    = "config_Mark.xml"
                "Matt"    = "config_Matt.xml"
                "Nikki"   = "config_Nikki.xml"
                "Phillip" = "config_Phillip.xml"
            }
            try {
                # select alternating config file
                if($env:COMPUTERNAME -match $hostnameMatch){
                    $PcIndex = [int]$matches[1] - 1
                }
                $ConfigKeys = @($ConfigFiles.Keys | Sort-Object)
                $configKey = $ConfigKeys[$PcIndex % $ConfigKeys.Count]
                $configFile = $ConfigFiles[$configKey]

                # activate selected config file
                $sourceConfig = Join-Path -Path $dst -ChildPath $configFile
                $destinationConfig = Join-Path -Path $dst -ChildPath "config.xml"

                Copy-Item -Path $sourceConfig -Destination $destinationConfig -Force -ErrorAction Stop
                $acl = Get-Acl -Path $sourceConfig
                Set-Acl -Path $destinationConfig -AclObject $acl
    <#
                icacls "$dst" /reset /T /C
                icacls "$dst" /remove "CREATOR OWNER" /T /C
                icacls "$dst" /inheritance:e /T /C
    #>

                $message = "✅ Restored config: $configFile -> config.xml"
                Write-Host $message
            } catch {
                $message = "⚠️ Failed to copy $configFile to $destinationConfig`: $($_.Exception.Message)"
                Write-Error $message
            }

            try{
                $profilePath = GetUserProfilePath
                if ($profilePath) {
                    $username = ((Get-CimInstance -ClassName Win32_ComputerSystem).UserName).Split('\')[-1]
                    $remove = Join-Path $profilePath "AppData\Local\VirtualStore\ProgramData\DCSB\config.xml"
                    if (Test-Path $remove) {
                        Remove-Item $remove -Force
                        Write-Host "🗑️ Removed DCSB config of user $($username): $remove" -ForegroundColor Green
                    } else {
                        Write-Host "ℹ️ File not found: $remove" -ForegroundColor Yellow
                    }
                } else {
                    Write-Warning "❌ No user currently logged in" -ForegroundColor Yellow
                }
            } catch {
                $message = "⚠️ Failed to remove $remove`: $($_.Exception.Message)"
                Write-Error $message
            }
        }
    }

    TerminateFixRestart -ComputerName $ComputerName `
                    -Credential $Credential `
                    -Path $programEntry.Path `
                    -Arguments $programEntry.Arguments `
                    -Callback $programEntry.Callback
    Pause
} while ($true)
