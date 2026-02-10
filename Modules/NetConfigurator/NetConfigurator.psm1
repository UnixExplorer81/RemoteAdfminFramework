class NetConfigurator {
    [bool]$enableDhcp = $false
    [string]$InterfaceAlias = ''
    [hashtable]$ConfigCache
    [System.Collections.ArrayList]$LogData

    NetConfigurator([hashtable]$options) {
        $this.LogData = [System.Collections.ArrayList]::new()
        if (-not $options) { $options = @{} }
        foreach ($key in $options.Keys) {
            if ($this.PSObject.Properties.Name -contains $key) {
                $this.$key = $options[$key]
            }
        }
        if (-not $this.InterfaceAlias) {
            $this.InterfaceAlias = $this.DetectAdapter()
        }
        $this.ConfigCache = @{}
        $this.AnalyzeConfig()
        $this.LogConfig()
        $this.ApplyDhcpState($this.enableDhcp)
    }

    [string]DetectAdapter() {
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
        if (-not $adapter) {
            $this.Log('warning', "No active network adapter found. Attempting to enable the first network adapter.")
            $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Disabled' } | Select-Object -First 1
            if ($adapter) {
                try {
                    Enable-NetAdapter -Name $adapter.Name -Confirm:$false
                    Start-Sleep -Seconds 2
                    $this.Log('success', "Network adapter '$($adapter.Name)' enabled.")
                } catch {
                    $this.Log('warning', "Failed to enable adapter '$($adapter.Name)': $_")
                }
            } else {
                $this.Log('warning', "No network adapter found.")
                return $null
            }
        }
        $this.Log('detect', "Network adapter detected: $($adapter.Name)")
        return $adapter.Name
    }

    [string]GetDhcpState(){
        return (Get-NetIPInterface -InterfaceAlias $this.InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue).Dhcp
    }

    [System.Array]GetIPAddresses(){
        return Get-NetIPAddress -InterfaceAlias $this.InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
    }

    [System.Array]GetDefaultRoutes(){
        return Get-NetRoute -InterfaceAlias $this.InterfaceAlias -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
    }

    [System.Array]GetDnsServers(){
        return Get-DnsClientServerAddress -InterfaceAlias $this.InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
    }

    [void]AnalyzeConfig() {
        if (-not $this.InterfaceReady()) { return }
        $this.Log('detect', "Collecting current network settings.")
        $this.ConfigCache = @{
            DHCP    = $this.GetDhcpState()
            IPs     = $this.GetIPAddresses()
            Routes  = $this.GetDefaultRoutes()
            DNS     = $this.GetDnsServers()
        }
    }

    [void]LogConfig() {
        if (-not $this.ConfigCache) { return }
        $this.Log('info', "DHCP: " + $this.ConfigCache.DHCP)
        $this.Log('info', "IPs: " + ($this.ConfigCache.IPs | ForEach-Object { "$($_.IPAddress) / $($_.PrefixLength)" }) -join ', ')
        $this.Log('info', "Gateways: " + ($this.ConfigCache.Routes | ForEach-Object { "$($_.NextHop) / $($_.RouteMetric)" }) -join ', ')
        $this.Log('info', "DNS: " + ($this.ConfigCache.DNS.ServerAddresses  -join ', '))
    }

    [bool]InterfaceReady() {
        if (-not $this.InterfaceAlias) {
            $this.Log('warning', "Network adapter is not defined.")
            return $false
        }
        return $true
    }

    [void]ApplyDhcpState([bool]$enable) {
        if ($enable) {
            $this.ActivateDhcp()
        } else {
            $this.DeactivateDhcp()
        }
    }

    [void]ActivateDhcp() {
        if (-not $this.InterfaceReady()) { return }
        $isStatic = $this.ConfigCache.Dhcp -eq 'Disabled'
        if($isStatic){
            try {
                $this.Log('update', "Enabling DHCP on adapter: $($this.InterfaceAlias)")
                Remove-NetIPAddress -InterfaceAlias $this.InterfaceAlias -Confirm:$false -ErrorAction SilentlyContinue
                Set-NetIPInterface -InterfaceAlias $this.InterfaceAlias -Dhcp Enabled -ErrorAction Stop
                Set-DnsClientServerAddress -InterfaceAlias $this.InterfaceAlias -ResetServerAddresses -ErrorAction SilentlyContinue
                $this.Log('success', "DHCP got enabled and static IP/DNS cleared.")
                $this.ConfigCache.Dhcp = $this.GetDhcpState()
            } catch {
                $this.Log('warning', "Failed to enable DHCP: $_")
            }
        }
    }

    [void]DeactivateDhcp() {
        if (-not $this.InterfaceReady()) { return }
        $isDhcp = $this.ConfigCache.Dhcp -eq 'Enabled'
        if($isDhcp){
            try {
                $this.Log('update', "Disabling DHCP on adapter: $($this.InterfaceAlias)")
                Set-NetIPInterface -InterfaceAlias $this.InterfaceAlias -Dhcp Disabled -ErrorAction Stop
                $this.Log('success', "DHCP got disabled.")
                $this.ConfigCache.Dhcp = $this.GetDhcpState()
            } catch {
                $this.Log('warning', "Failed to disable DHCP: $_")
            }
        }
    }

    [int]ConvertSubnetMaskToPrefixLength([string]$SubnetMask) {
        try {
            $binary = ( ($SubnetMask -split '\.') | ForEach-Object {
                [Convert]::ToString([int]$_, 2).PadLeft(8, '0')
            } ) -join ''
            return ($binary -split '1').Count - 1
        } catch {
            $this.Log('error', "Error converting SubnetMask '$SubnetMask': $_")
            return -1
        }
    }

    [void]SetNetConfig(
        [string]$IPAddress,
        [string]$SubnetMask,
        [string]$DefaultGateway,
        [int]$RouteMetric = 0 # Automatic Metric
    ) {
        if (-not $this.InterfaceReady()) { return }
        if ($this.enableDhcp -and $this.ConfigCache.Dhcp -eq 'Enabled') {
            $this.Log('warning', "Adapter is already configured as DHCP.")
            return
        }
        $PrefixLength = $this.ConvertSubnetMaskToPrefixLength($SubnetMask)
        if ($PrefixLength -lt 0) {
            $this.Log('error', "Invalid subnet mask '$SubnetMask'. Cannot proceed.")
            return
        }

        $params = @{
            IPAddress      = $IPAddress
            PrefixLength   = $PrefixLength
            InterfaceAlias = $this.InterfaceAlias
        }

        try {
            $existingIP = $this.ConfigCache.IPs | Where-Object { $_.IPAddress -eq $IPAddress }
            if ($existingIP) {
                if ($existingIP.PrefixLength -ne $PrefixLength) {
                    $this.Log('update', "IP: PrefixLength for $IPAddress updated from $($existingIP.PrefixLength) to $PrefixLength")
                    Set-NetIPAddress @params -ErrorAction Stop
                    $this.ConfigCache.IPs = $this.GetIPAddresses()
                }
            } else {
                New-NetIPAddress @params -ErrorAction Stop
                $this.Log('success', "IP: $IPAddress / prefix length: $PrefixLength altered")
                $this.ConfigCache.IPs = $this.GetIPAddresses()
            }
        } catch {
            $this.Log('error', "Error configuring IP '$IPAddress': $_")
        }

        try {
            if ($DefaultGateway) {
                $existingRoute = $this.ConfigCache.Routes | Where-Object { $_.NextHop -eq $DefaultGateway }
                if (-not $existingRoute) {
                    if ($RouteMetric -gt 0) {
                        New-NetRoute -InterfaceAlias $this.InterfaceAlias -DestinationPrefix "0.0.0.0/0" `
                                        -NextHop $DefaultGateway -RouteMetric $RouteMetric -ErrorAction Stop
                        $this.Log('success', "Default gateway: $DefaultGateway / route metric: $RouteMetric altered")
                    } else {
                        New-NetRoute -InterfaceAlias $this.InterfaceAlias -DestinationPrefix "0.0.0.0/0" `
                                        -NextHop $DefaultGateway -ErrorAction Stop
                        $this.Log('success', "Default gateway: $DefaultGateway / route metric: automatic altered")
                    }
                    $this.ConfigCache.Routes = $this.GetDefaultRoutes()
                } elseif ($existingRoute.RouteMetric -ne $RouteMetric) {
                    if ($RouteMetric -gt 0) {
                        Set-NetRoute -InterfaceAlias $this.InterfaceAlias -DestinationPrefix "0.0.0.0/0" `
                                        -NextHop $DefaultGateway -RouteMetric $RouteMetric -ErrorAction Stop
                        $this.Log('success', "Default gateway: RouteMetric for $DefaultGateway updated from $($existingRoute.RouteMetric) to $RouteMetric")
                    }else{
                        Set-NetRoute -InterfaceAlias $this.InterfaceAlias -DestinationPrefix "0.0.0.0/0" `
                                        -NextHop $DefaultGateway -ErrorAction Stop
                        $this.Log('success', "Default gateway: RouteMetric for $DefaultGateway updated from $($existingRoute.RouteMetric) to automatic")
                    }
                    $this.ConfigCache.Routes = $this.GetDefaultRoutes()
                }
            }
        } catch {
            $this.Log('error', "Error configuring default gateway '$DefaultGateway': $_")
        }
    }

    [void]SetDnsServers([string[]]$DnsServers) {
        if (-not $this.InterfaceReady()) { return }
        try {
            if (-not $DnsServers -or $DnsServers.Count -eq 0) {
                $this.Log('error', "No DNS servers specified.")
                return
            }
            $existingDns = $this.ConfigCache.DNS
            if (-not ($existingDns.ServerAddresses) -or ($existingDns.ServerAddresses -join ',') -ne ($DnsServers -join ',')) {
                $this.Log('update', "Updating DNS servers to: $($DnsServers -join ', ')")
                Set-DnsClientServerAddress -InterfaceAlias $this.InterfaceAlias -ServerAddresses $DnsServers -ErrorAction Stop
                $this.ConfigCache.DNS = $this.GetDnsServers()
            } else {
                $this.Log('info', "DNS servers are already up to date.")
            }
        } catch {
            $this.Log('error', "Error setting DNS: $_")
        }
    }

    [void]RemoveObsoleteIPs([string[]]$KeepIPs) {
        if (-not $this.InterfaceReady()) { return }
        try {
            $allIPs = $this.ConfigCache.IPs
            foreach ($ip in $allIPs) {
                if ($KeepIPs -notcontains $ip.IPAddress) {
                    $this.Log('cleanup', "Removing obsolete IP: $($ip.IPAddress)")
                    Remove-NetIPAddress -InterfaceIndex $ip.InterfaceIndex -IPAddress $ip.IPAddress -Confirm:$false -ErrorAction Stop
                }
            }
            $this.ConfigCache.DNS = $this.GetDnsServers()
        } catch {
            $this.Log('error', "Error removing IP addresses: $_")
        }
    }

    [void]Log([string]$level, [string]$message) {
        $null = $this.LogData.Add([PSCustomObject]@{
            Level   = $level.ToLower()
            Message = $message
        })
    }

    [System.Collections.ArrayList]GetLog() {
        return $this.LogData
    }
}
