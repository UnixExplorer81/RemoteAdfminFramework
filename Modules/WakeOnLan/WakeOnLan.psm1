function WakeOnLan {
    param (
        [Parameter(Mandatory)]
        [object]$Context
    )
    if(-not $Context.Computer.mac){
        return @{
            Success = $false
            Message = "MAC address missing for $($Context.Computer.hostname)"
        }
    }
    try {
        $MagicPacket = buildMagicPackage -MacAddress $Context.Computer.mac
        if($null -eq $MagicPacket) {
            throw "Invalid MAC address: Required format is XX:XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX."
        }
        $bytesSent = sendMagicPackage -MagicPacket $MagicPacket -BroadcastAddress $Context.Config.BroadcastAddress
        if($bytesSent -ne $MagicPacket.Length){
            throw "An unknown error has occurred. Check connection!"
        }
        return @{
            Success = $true
            Message = "Magic packet sent on port $Port via $BroadcastAddress for $($Context.Computer.hostname) ($MacAddress)."
        }
    } catch {
        return @{
            Success = $false
            Message = $_
        }
    }
}

function buildMagicPackage {
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

function sendMagicPackage {
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