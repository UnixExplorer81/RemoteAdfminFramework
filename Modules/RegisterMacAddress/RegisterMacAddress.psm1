
function RegisterMacAddress {
    param($Context)

    if ($null -ne $Context.Memory -and
        $null -ne $Context.Memory.RegisterMacAddress -and
        $Context.Memory.RegisterMacAddress.Computer -is [object]) {

        $Computer = $Context.Memory.RegisterMacAddress.Computer    
        $netAddress = ($Context.Config.BroadcastAddress -split '\.')[0..2] -join '.'
        if($Computer -is [PSCustomObject]){
            Import-Module ConvertToHashtable
            $Computer = ConvertToHashtable $Computer
        }
        if($Computer.Keys -contains 'ip'){
            $ip = @($Computer.ip | Where-Object { $_.StartsWith($netAddress) })[0]
            $Computer.ip = $ip
        }

        if (-not ($null -ne $Context.Config.CsvPath)) {
            throw "CSV path not defined in context"
        }

        Import-Module CsvManager
        RegisterCsvSchema -Path $Context.Config.CsvPath `
                        -Delimiter $Context.Config.CsvDelimiter `
                        -Headers $Context.Config.CsvHeader `
                        -PrimaryKey "hostname"

        $existing = GetCsvRecord -Path $Context.Config.CsvPath -Key $Computer.hostname
        $result = SetCsvRecord -Path $Context.Config.CsvPath -Values $Computer

        if ($result.Success) { 
            if ($existing) {
                $message = "MAC address updated for $($Computer.hostname)"
                $Context.Logger.Success($message)
            } else {
                $message = "MAC address registered for $($Computer.hostname)"
                $Context.Logger.Success($message)
            }
        } else {
            $message = "RegisterMacAddress: Fatal error on $($Computer.hostname) - $($result.Message)"
            $Context.Logger.Error($message)
        }
        if ($Host.Name -eq 'ConsoleHost') {
            Write-Host $message
            Start-Sleep -Seconds 3
            return
        } else {
            return $result
        }
        $Context.Memory.RegisterMacAddress = $null
    }
}
