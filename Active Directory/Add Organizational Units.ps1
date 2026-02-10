# Change to the desired drive
Set-Location "D:\NAS\Documents\CSV Lists"

# Set the path for configuration and CSV files
$ConfigFile = "Domain.ini"
$Filename = "OrganizationalUnits.csv"
$Delimiter = ";"

# Read the configuration file to get the controller
$Controller = ""
Get-Content $ConfigFile | ForEach-Object {
    $Parts = $_ -split ":"
    if ($Parts[0] -eq "controller") {
        $Controller = $Parts[1].Trim()
    }
}

# Check if controller is set
if (-not $Controller) {
    Write-Host "Controller not found in config file."
    exit
}

# Read the CSV file and create organizational units
Get-Content -Path $Filename -Delimiter $Delimiter | ForEach-Object {
    $OU = $_.Trim()  # Get the line and trim whitespace
    Write-Host "Creating OU: $OU"
    dsadd ou "OU=$OU,$Controller"
}

Pause
