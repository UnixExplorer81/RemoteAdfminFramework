using module ScriptVersionGuard
using module NetConfigurator
using module Logger

Invoke-IfScriptChanged -Id 'StaticNetConfig' -ActionBlock {

    $subnetConfigs = @(
        [PSCustomObject]@{
            SubnetBase   = '192.168.1.'
            SubnetMask   = '255.255.254.0'
            PrefixLength = 24
            Gateway      = '192.168.1.234'
            Metric       = 1
            DNS          = @("192.168.1.254", "192.168.1.253", "192.168.1.252", "192.168.1.234")
        },
        [PSCustomObject]@{
            SubnetBase   = '192.168.0.'
            SubnetMask   = '255.255.254.0'
            PrefixLength = 24
            Gateway      = '192.168.0.234'
            Metric       = 10
            DNS          = @("192.168.0.254", "192.168.0.253", "192.168.0.232", "192.168.0.234", "192.168.1.234")
        }
    )
    $enableDhcp     = $false
    $useMultipleCfg = $false
    $hostnameMatch  = "^\w+-(\d+)(\..+)?$"
    $hostname       = $env:COMPUTERNAME
    $logFile        = 'c:\windows\temp\applyStaticNetConfig.log'

    $Logger = [Logger]::new(@{
        logPath = $logFile
        useConsole = $true
    })

    if ($hostname -match $hostnameMatch) {
        $Logger.Info("--- 🖥️ $($hostname) - Running as: 👤 $(whoami) ---")
        $pcNumber = [int]$matches[1]
        $NetConfigurator = [NetConfigurator]::new(
            @{ enableDhcp = $enableDhcp }
        )

        # Apply Configuration
        $configsToApply = if ($useMultipleCfg) { $subnetConfigs } else { @($subnetConfigs[0]) }

        # Set IPs and Routes
        $ips = @()
        if($configsToApply.Count -gt 1 -and $subnetConfigs[0].Metric -eq $subnetConfigs[1].Metric){
            $ips += "$($subnetConfigs[0].SubnetBase)$pcNumber"
            $ips += "$($subnetConfigs[1].SubnetBase)$pcNumber"
            if ($pcNumber % 2 -eq 0) {
                $NetConfigurator.SetNetConfig("$($subnetConfigs[0].SubnetBase)$pcNumber", $subnetConfigs[0].SubnetMask, $subnetConfigs[0].Gateway, 10)
                $NetConfigurator.SetNetConfig("$($subnetConfigs[1].SubnetBase)$pcNumber", $subnetConfigs[1].SubnetMask, $subnetConfigs[1].Gateway, 20)
            } else {
                $NetConfigurator.SetNetConfig("$($subnetConfigs[1].SubnetBase)$pcNumber", $subnetConfigs[1].SubnetMask, $subnetConfigs[1].Gateway, 10)
                $NetConfigurator.SetNetConfig("$($subnetConfigs[0].SubnetBase)$pcNumber", $subnetConfigs[0].SubnetMask, $subnetConfigs[0].Gateway, 20)
            }
        } else {
            foreach ($cfg in $configsToApply) {
                $ip   = "$($cfg.SubnetBase)$pcNumber"
                $ips += $ip
                # Set IP + Gateway + Metrik
                $NetConfigurator.SetNetConfig($ip, $cfg.SubnetMask, $cfg.Gateway, $cfg.Metric)
            }
        }

        # Remove obsolete IP addresses
        $NetConfigurator.RemoveObsoleteIPs($ips)

        # Set DNS
        $dnsToApply = if ($useMultipleCfg) { $subnetConfigs[1].DNS } else { $subnetConfigs[0].DNS }
        $NetConfigurator.SetDnsServers($dnsToApply)
    }else{
        $Logger.Error('Hostname doesn`t match search pattern')
    }

    # Append Log
    $NetConfigurator.GetLog() | ForEach-Object { $Logger.Log($_.Message, $_.Level) }
}