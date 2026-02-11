function ReadMacAddress {
    param (
        [Parameter(Mandatory)][string]$Context
    )
}

function ReadLocal {
    try {
        # Get the primary physical network adapter (Ethernet, not virtual or WIFI)
        $adapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -notlike "*Virtual*" -and $_.PhysicalMediaType -eq "802.3" } | Select-Object -First 1
        if ($adapter) {
            return @{
                success = $true
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

function ReadRemote {
    param (
        [Parameter(Mandatory)][string]$ComputerName,
        [Parameter(Mandatory)][PSCredential]$Credential
    )

    try {
        $result = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            return ReadLocal
        }
        if($null -ne $result) {
            if($result.success){
                Write-Output "MAC-Adresse von $ComputerName`: $($result.mac)"
                return $result
            } else {
                
            }
        }
    } catch {
        Write-Error "Error reading from $ComputerName: $_"
    }
}