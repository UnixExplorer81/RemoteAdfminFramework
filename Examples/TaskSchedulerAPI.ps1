.\PsRemoteAdminFramework.ps1 -InvokeApi @{
    Path   = @("GPOs", "Task Scheduler", "Wake Specific Clients")
}

<#
.\PsRemoteAdminFramework.ps1 -InvokeApi @{
    Path   = @("GPO", "Task Scheduler")
    Memory = @{
        TaskScheduler = @("Wake All Clients") # skalierbar auf verkettung mehrerer tasks
    }
}
#>