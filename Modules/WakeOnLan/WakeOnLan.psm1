function WakeOnLan {
    param (
        [Parameter(Mandatory)]
        [object]$Context
    )
    try {
        if(-not $Context.Computer.mac -or -not $Context.Computer.mac.Trim()){
            throw "No MAC address specified."
        }
        $MagicPacket = createMagicPacket -MacAddress $Context.Computer.mac
        if($null -eq $MagicPacket) {
            throw "Invalid MAC address: Required format is XX:XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX."
        }
        $bytesSent = sendMagicPacket -MagicPacket $MagicPacket -BroadcastAddress $Context.Config.BroadcastAddress
        if([int]$bytesSent -ne $MagicPacket.Length){
            throw "An unknown error has occurred. Check connection!"
        }
        return @{
            Success = $true
            Message = "WakeOnLan: Magic packet sent via $($Context.Config.BroadcastAddress) for $($Context.Computer.hostname) ($($Context.Computer.mac))."
        }
    } catch {
        return @{
            Success = $false
            Message = "WakeOnLan: Error on $($Context.Computer.hostname): $_"
        }
    }
}

function createMagicPacket {
    param (
        [Parameter(Mandatory)][string]$MacAddress
    )
    try {
        $MacParts = $MacAddress -split "[:-]"
        if ($MacParts.Count -ne 6) {
            return
        }
        $MacByteArray = $MacParts | ForEach-Object { [Byte] "0x$_" }
        [Byte[]] $MagicPacket = (,0xFF * 6) + ($MacByteArray * 16)
        return $MagicPacket
    } catch {
        return
    }
}

function sendMagicPacket {
    param (
        [Parameter(Mandatory)][byte[]]$MagicPacket,
        [string]$BroadcastAddress,
        [int]$Port = 9  # 7 | 9
    )
    if(-not $BroadcastAddress){
        $BroadcastAddress = ([System.Net.IPAddress]::Broadcast)
    }
    try {
        $UdpClient = New-Object System.Net.Sockets.UdpClient
        $UdpClient.Connect($BroadcastAddress, $Port) | Out-Null
        $bytesSent = $UdpClient.Send($MagicPacket, $MagicPacket.Length) | Out-String
        $UdpClient.Close()
        return $bytesSent
    } catch {
        return
    }
}