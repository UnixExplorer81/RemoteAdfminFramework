<#
    PowerShell API
#>
<#
.\PsRemoteAdminFramework.ps1 -InvokeApi @{
    Path   = @("GPOs", "Enter MAC addresses manually")
    Memory = @{
        RegisterMacAddress = @{            
            Computer = $(
                @{
                    hostname = "AI-086"
                    ip = @("192.168.0.86","192.168.1.86")
                    mac = "B0:83:FE:6F:25:52"
                }
            )
        }
    }
}
#>
<#
    REST API
#>
$body = @{
    Path = @("GPOs", "Enter MAC addresses manually")
    Memory = @{
        RegisterMacAddress = @{            
            Computer = @{
                hostname = "DC-3"
                ip = @("192.168.1.252")
                mac = "62:FE:59:7F:36:43"
            }
        }
    }
} | ConvertTo-Json -Depth 5 -Compress

Invoke-RestMethod -Uri "http://localhost:8080/api/remote-admin" `
                -Method Post `
                -Body $body `
                -ContentType "application/json"

