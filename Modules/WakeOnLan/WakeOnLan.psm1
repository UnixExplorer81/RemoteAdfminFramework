function WakeOnLan {
    param (
        [Parameter(Mandatory)][string]$MacAddress,
        [int]$Port = 7  # 7 | 9
    )

    $MacParts = $MacAddress -split "[:-]"
    if ($MacParts.Count -ne 6) {
        throw "Ungültige MAC-Adresse: Muss im Format XX:XX:XX:XX:XX:XX oder XX-XX-XX-XX-XX-XX sein."
    }
    $MacByteArray = $MacParts | ForEach-Object { [Byte] "0x$_" }
    [Byte[]] $MagicPacket = (,0xFF * 6) + ($MacByteArray * 16)
    try {
        $UdpClient = New-Object System.Net.Sockets.UdpClient
        $UdpClient.Connect(([System.Net.IPAddress]::Broadcast), $Port)
        $UdpClient.Send($MagicPacket, $MagicPacket.Length) | Out-Null
        Write-Output "Magic Packet an $MacAddress auf Port $Port gesendet."
    } catch {
        Write-Error "Fehler beim Senden: $_"
    } finally {
        $UdpClient.Close()
    }
}

function ReadMacAddress {
    param (
        [Parameter(Mandatory)][string]$ComputerName,
        [Parameter(Mandatory)][PSCredential]$Credential
    )

    try {
        $mac = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
            # Hole den primären physischen Netzwerkadapter (Ethernet, nicht virtuell)
            $adapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -notlike "*Virtual*" -and $_.PhysicalMediaType -eq "802.3" } | Select-Object -First 1
            if ($adapter) {
                return $adapter.MacAddress
            } else {
                throw "Kein physischer Ethernet-Adapter gefunden."
            }
        }
        Write-Output "MAC-Adresse von $ComputerName: $mac"
        return $mac
    } catch {
        Write-Error "Fehler beim Auslesen von $ComputerName: $_"
    }
}
