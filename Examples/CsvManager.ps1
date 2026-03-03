Using Module CsvManager
Using Module Debugger

$Csv = "\\topcall.inc\shares\PowerShell_Framework$\ConfigFiles\AiStations.csv"
$CsvHeader = @('hostname','ip','mac','cn','dc','controller')
$CsvDelimiter = ";"

RegisterCsvSchema -Path $Csv -Delimiter $CsvDelimiter -Headers $CsvHeader -PrimaryKey "hostname"

<#
$result = GetCsvRecord -Path $Csv -Key "DC-1"
$result = GetCsvSchema -Path $Csv
Inspect $result
#>

<#
SetCsvRecord -Path $Csv -Values @{
    hostname = "DC-2"
    ip = "192.168.1.253"
    mac = "62:FE:59:7F:36:43"
    cn = "CN=Domain Computers,CN=Users"
    dc = "DC=topcall,DC=inc"
    controller = "topcall.inc"
}
#>

$task = @{
    Path   = @("GPOs", "Enter MAC addresses manually")
    Memory = @{
        RegisterMacAddress = @{            
            Computer = @{
                hostname = "DC-3"
                ip = "192.168.1.252"
                mac = "9C:FB:D5:FF:97:47"
            }
        }
    }
}
.\PsRemoteAdminFramework.ps1 -InvokeApi $task
