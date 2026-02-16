function TaskScheduler {
    param (
        [Parameter(Mandatory)][object]$Context
    )

    if ($Host.Name -eq 'ConsoleHost') {
        MultiDimensionalMenu -Node (GetTaskSchedulerMenu -Context $Context) -Path $Context.Path -Context $Context -DisplayIndex $Context.Config.DisplayIndex
    } else {
        ResolveApiRequestPath -Node (GetTaskSchedulerMenu -Context $Context) -Path $Context.Path -Context $Context
    }
}

function GetTaskSchedulerMenu {
    param (
        [Parameter(Mandatory)][object]$Context
    )

    # $Config = & $Context.Registry.TaskSchedulerConfig.target
    $Config = Invoke-Expression (Get-Content $Context.Registry.TaskSchedulerConfig.target -Raw -Encoding UTF8 -ErrorAction Stop)
    $Menu  = [ordered]@{}

    foreach ($key in $Config.Keys) {
        $Scheduler = $Config[$key]
        $Tasks = [object[]]$Scheduler.Tasks
        $Description = $Scheduler.Description
        $Schedule = $Scheduler.Schedule

        $Menu[$key] = @(
            $Description,
            {
                ExecuteScheduler -Tasks $Tasks -Schedule $Schedule
            }.GetNewClosure()
        )
    }

    return $Menu
}

function ExecuteScheduler {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][object[]]$Tasks,
        [Parameter(Mandatory)][object]$Schedule
    )

    if ($Host.Name -eq 'ConsoleHost') {
        Write-Host "Scheduler activated" -ForegroundColor Green
        Write-Host "Press [ESCAPE] to terminate the scheduler"-ForegroundColor Cyan
    }
    $LastExecutionDate = $null

    while ($true) {

        if (TerminateScheduler) { return }
        
        $Now = Get-Date
        $Today = $Now.Date
        $DayIndex = [int]$Now.DayOfWeek

        # interrupt checking temporary during from schedule excluded days
        if ($Schedule.days -notcontains $DayIndex) {
            Start-Sleep -Seconds 300
            continue
        }

        $Begin = $Today.Add([TimeSpan]::Parse($Schedule.begin))
        $End   = $Today.Add([TimeSpan]::Parse($Schedule.end))

        # If shift end is past midnight
        if ($End -le $Begin) {
            $End = $End.AddDays(1)
        }

        $InWorktime = ($Now -ge $Begin -and $Now -le $End)
        $AlreadyExecuted = $LastExecutionDate -and $LastExecutionDate.Date -eq $Today

        if ($InWorktime -and -not $AlreadyExecuted) {
            if ($Host.Name -eq 'ConsoleHost') {
                Write-Host "Schedule executed: $Now"
            }
            foreach ($Task in $Tasks) {
                $job = Start-Job -FilePath $ApiPath -ArgumentList $Task
                while ($job.State -eq 'Running') {
                    Start-Sleep -Seconds 1
                }
                $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
                Remove-Job $job -Force -ErrorAction SilentlyContinue
            }
            $LastExecutionDate = $Today
        }
        if ($Host.Name -eq 'ConsoleHost') {
            $sleep = 120
            while($sleep) {
                $sleep--
                if (TerminateScheduler) { return }
                Start-Sleep -MilliSeconds 500
            }
        } else {
            Start-Sleep 60
        }
    }
}

function TerminateScheduler {
    if ($Host.Name -ne 'ConsoleHost') { return $false }
    if (-not [Console]::KeyAvailable) { return $false }
    $key = [Console]::ReadKey($true)
    if ($key.Key -in 'Escape','LeftArrow') {
        Write-Host "Terminating scheduler..." -ForegroundColor Cyan
        return $true
    }
    return $false
}
