using module WakeOnLan

$Context = @{
    Config = @{
        BroadcastAddress = "192.168.1.255"
    }
    Computer = @{
        hostname = "AI-086"
        mac = "B0-83-FE-6F-25-52"
    }
}

WakeOnLan -Context $Context


$task = @{
    Path = @("GPOs", "Wake up clients", "Specific clients")
    Memory = @{
        StationSelector = @{
            selection = @("AI-086", "253")
        }
    }
}
.\PsRemoteAdminFramework.ps1 -InvokeApi $task
