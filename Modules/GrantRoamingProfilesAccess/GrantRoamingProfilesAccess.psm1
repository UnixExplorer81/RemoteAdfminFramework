function GrantRoamingProfilesAccess {

# .SYNOPSIS 
# Grant-RoamingProfilesAccess is an advanced Powershell function. It takes ownership of the users roaming profiles folders and grants the administrators group full access.
 
# .DESCRIPTION 
# Uses takeown and icacls. Define the path to the roaming profiles root directory.
 
# .PARAMETER 
# Path
# Enter the path to the roaming profiles root folder.
 
# .EXAMPLE 
# Grant-RoamingProfilesAccess -Path "D:\Roaming Profiles\Agents"
 
# .NOTES 
# Author: Patrick Gruenauer 
# Web: 
# https://sid-500.com 
 
[CmdletBinding()]
 
param
 
(
 
[Parameter(Position=0,Mandatory=$true,Helpmessage = 'Enter Path to the Roaming Profiles Root Directory')]
$Path
 
)

$ErrorActionPreference="SilentlyContinue"

Get-ChildItem $Path -Recurse -Force | 
ForEach-Object { 
    
    takeown /f $_.FullName /a
    icacls $_.Fullname /grant "administrators:(OI)(CI)F" /t
    
}


}