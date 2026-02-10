# Change to the desired drive
Set-Location "D:\NAS\Documents\CSV Lists"

# Set the path for configuration and CSV files
$ConfigFile = "Domain.ini"
$Filename = "Agents_new.csv"
$Delimiter = ","

# Read the configuration file to get the domain and controller
$Domain = ""
$Controller = ""
$ProfileBaseDir = ""
$UserGroupContainer = ""
$AdminGroupContainer = ""
$AdminSecurityGroup = ""

Get-Content $ConfigFile | ForEach-Object {
    $Parts = $_ -split ":"
    switch ($Parts[0].Trim()) {
        "Domain" { $Domain = $Parts[1].Trim() }
        "Controller" { $Controller = $Parts[1].Trim() }
        "ProfileBaseDir" { $ProfileBaseDir = $Parts[1].Trim() }
        "UserGroupContainer" { $UserGroupContainer = $Parts[1].Trim() }
        "AdminGroupContainer" { $AdminGroupContainer = $Parts[1].Trim() }
        "AdminSecurityGroup" { $AdminSecurityGroup = $Parts[1].Trim() }
    }
}

# Check if required values are set
if (-not $Domain -or -not $Controller -or -not $UserGroupContainer -or -not $AdminGroupContainer -or -not $AdminSecurityGroup) {
    Write-Host "Required values are missing from config file."
    exit
}

# Read the CSV file and create users
Import-Csv -Path $Filename -Delimiter $Delimiter -Header Username, Password, OuName, FirstName, LastName, DisplayName, CanChangePw, MustChangePw, PwNeverExpires, Disabled | ForEach-Object {
	$OuName = $_.OuName
	$usergroup = if ($OuName -eq "Admin") { $AdminSecurityGroup } else { $OuName }
	$Container = if ($OuName -eq "Admin") { $AdminGroupContainer } else { $UserGroupContainer }
	$Username = $_.Username
	$UserDN = "CN=$Username,OU=$OuName,$Controller"
	$MemberOf = "CN=$usergroup,CN=$Container,$Controller"
	$Pwd = $_.Password
	$FirstName = $_.FirstName
	$LastName = $_.LastName
	$Display = $_.DisplayName
	$Profile =  "$ProfileBaseDir\$($OuName)\$($Username)"
	$CanChangePw = $_.CanChangePw
	$MustChangePw = $_.MustChangePw
	$PwNeverExpires = $_.PwNeverExpires
	$Disabled = $_.Disabled

	Write-Host "UserDN: $UserDN"
	Write-Host "MemberOf: $MemberOf"
	Write-Host "Usergroup: $usergroup"
	Write-Host "Container: $Container"
	Write-Host "Controller: $Controller"
	Write-Host "Profile: $Profile"
	Write-Host "CanChangePw: $CanChangePw"
	Write-Host "MustChangePw: $MustChangePw"
	Write-Host "PwNeverExpires: $PwNeverExpires"
	Write-Host "Disabled: $Disabled"
	Write-Host "Creating user: $Username"

	$dsaddCmd = "dsadd user ""$UserDN"" " +
            "-memberof ""$MemberOf"" " +
            "-upn ""$Username@$Domain"" " +
            "-fn ""$FirstName"" " +
            "-ln ""$LastName"" " +
            "-display ""$Display"" " +
            "-pwd ""$Pwd"" " +
            "-profile ""$Profile"" " +
            "-canchpwd $CanChangePw " +
            "-mustchpwd $MustChangePw " +
            "-pwdneverexpires $PwNeverExpires " +
            "-disabled $Disabled"

	Write-Host "Executing: $dsaddCmd"
	cmd /c $dsaddCmd
}

Pause
