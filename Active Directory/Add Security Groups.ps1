# Change to the correct directory
Set-Location "D:\NAS\Documents\CSV Lists"

# Define the paths for the configuration and CSV files
$configFile = "Domain.ini"
$csvFile = "SecurityGroups.csv"

# Define the delimiter used in the CSV and the columns to extract
$delimiter = ';'

# Initialize variables for controller and user_group_container
$controller = ""
$userGroupContainer = ""

# Read the Domain.ini file and extract values for controller and user group container
Get-Content $configFile | ForEach-Object {
    $line = $_.Split(":")
    $key = $line[0].Trim()
    $value = $line[1].Trim()

    if ($key -eq "controller") { 
        $controller = $value 
    }
    elseif ($key -eq "user_group_container") { 
        $userGroupContainer = $value 
    }
}

# Process the CSV file to extract security group names
Get-Content $csvFile -Delimiter $delimiter | ForEach-Object {
    # Extract the group from the current line
    $group = $_.Trim()  # Get the line and trim whitespace
    
    # Display the group being processed
    Write-Host "$group:"

    # Add the group using the DSAdd command
    $dsaddCommand = "dsadd group 'CN=$group, CN=$userGroupContainer, $controller'"
    
    # Execute the command
    Invoke-Expression $dsaddCommand
}

# Pause for the user to review the output
Read-Host "Press Enter to continue"
