function ParallelRemotingRunspaces {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string[]]$Computers,
        [Parameter(Mandatory)][pscredential]$Credential,
        [Parameter(Mandatory)][object]$Context,
        [ScriptBlock]$ProgressCallback,
        [int]$MaxRunspaces = 50
    )


    $iss = [initialsessionstate]::CreateDefault2()
    # $iss.ImportPSModule("Microsoft.PowerShell.Core")
    $pool = [runspacefactory]::CreateRunspacePool(1, $MaxRunspaces, $iss, $host)
    $pool.Open()

    $tasks = [System.Collections.ArrayList]::new()
    $localContext = ResolveProxyObjects -Context $Context

    foreach ($computer in $Computers) {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $pool
        $ps.AddScript({
            param(
                [string]$Computer,
                [pscredential]$Credential,
                [object]$Context
            )
            $results = [System.Collections.ArrayList]::new()
            $session = New-PSSession -ComputerName $Computer -Credential $Credential
            if($session){
                Import-Module ParamNormalization
                foreach ($task in $Context.Tasks) {
                    $runtimeState = @{
                        Computer = $Computer
                        Session  = $session
                    }
                    $params = ParamNormalization -Task $task -Context $Context -RuntimeState $runtimeState -Verbose:$Context.Config.Verbose
                    $result = if ($task.RemoteExecution) {
                        Invoke-Command -Session $session @params
                    } else {
                        & $params.ScriptBlock $params.ArgumentList[0]
                    }
                    if ($task.RenewSession -eq $true) {
                        Remove-PSSession -Session $session
                        $session = New-PSSession -ComputerName $Computer -Credential $Credential
                    }
                    $results.Add(@{
                        Computer = $Computer
                        DisplayName = $task.DisplayName
                        Description = $task.Description
                        AffectsProgress = $task.AffectsProgress
                        Result = $result
                    })
                }
                Remove-PSSession $session
            }
            return $results.ToArray()
        }).AddArgument($computer).AddArgument($Credential).AddArgument($localContext) | Out-Null
        $handle = $ps.BeginInvoke()
        $tasks.Add([pscustomobject]@{
            PS      = $ps
            Handle  = $handle
            Computer = $computer
        })
    }
    $counter = 0
    $lock = New-Object object
    $totalTasks = $Computers.Count * ($Context.Tasks | Where-Object { $_.AffectsProgress -eq $true }).Count
    Write-Progress -Activity "Processing Tasks" -Status "Starting..." -PercentComplete 0
    while ($tasks.Count -gt 0) {
        $completedTasks = $tasks.ToArray() | Where-Object { $_.Handle.IsCompleted }
        foreach ($task in $completedTasks) {
            $jobResults = $task.PS.EndInvoke($task.Handle)
            $task.PS.Dispose()
            $tasks.Remove($task)
            foreach ($result in $jobResults) {
                [System.Threading.Monitor]::Enter($lock)
                try {
                    if ($result.AffectsProgress) {
                        $counter++
                        $percent = [math]::Round(($counter / $totalTasks) * 100)
                        Write-Progress -Activity $result.DisplayName -Status "$($result.Description) on $($result.Computer)" -PercentComplete $percent
                    }
                    if ($result.Result.Message) {
                        Write-Output $result.Result.Message
                    }
                } finally {
                    [System.Threading.Monitor]::Exit($lock)
                }
            }
        }
    }
    $pool.Close()
    $pool.Dispose()
    Write-Progress -Activity "All tasks completed" -Completed
}

function ResolveProxyObjects {
    param(
        [Parameter(Mandatory)][object]$Context,
        [string[]]$ResolveProps = @('Config','Registry')
    )
    $jobCtx = @{}
    foreach ($prop in $Context.PSObject.Properties) {
        $name = $prop.Name
        if ($name -like '__*') { continue }
        $val = $null
        try { $val = $Context.$name } catch { $val = $prop.Value }
        if ($ResolveProps -contains $name -and $null -ne $val) {
            if ($val -is [System.Management.Automation.PSObject]) {
                if ($null -ne $val.PSObject.Members['AsHashtable']) {
                    try {
                        $jobCtx[$name] = $val.AsHashtable()
                        continue
                    } catch {}
                }
            }
        }
        $jobCtx[$name] = $val
    }
    return $jobCtx
}