<#
    Example GPO script for domain clients to register their MAC
    address in Remote Admin Framework for the Wake on Lan feature
#>

param(
	[Parameter(Mandatory)]
        [string]$RestApiServerAddress = 'http:\\localhost:8080/api/remote-admin'
)

function getNetConfig {
    try {
        # Get the primary physical network adapter (Ethernet, not virtual or WIFI)
        $adapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -notlike "*Virtual*" -and $_.PhysicalMediaType -eq "802.3" } | Select-Object -First 1
        if ($adapter) {
            return @{
                success = $true
                hostname = $env:COMPUTERNAME
                ip = @(Get-NetIPAddress -InterfaceAlias $adapter.name -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object { $_.IPAddress })
                mac = $adapter.MacAddress
            }
        } else {
            throw "No physical ethernet adapter found."
        }
    } catch {
        return @{
            success = $false
            message = "Error reading Mac address: $_"
        }
    }
}

$netConfig = getNetConfig

if($null -ne $netConfig -and $netConfig.success){
    $body = @{
        Path = @("GPOs", "Manually enter Mac address")
        Memory = @{
            RegisterMacAddress = @{            
                Computer = @{
                    hostname = $netConfig.hostname
                    ip = $netConfig.ip
                    mac = $netConfig.mac
                }
            }
        }
    } | ConvertTo-Json -Depth 5 -Compress

    Invoke-RestMethod -Uri '$RestApiServerAddress/api/remote-admin' `
                    -Method Post `
                    -Body $body `
                    -ContentType "application/json"
}
