using module ParamNormalization
using module ComputerActive

function ParallelRemotingJobs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][object]$Context,
        [Parameter(Mandatory)][object[]]$Clients,
        [Parameter(Mandatory)][pscredential]$Credential,
        [ScriptBlock]$ProgressCallback
    )

    $runningJobs = [System.Collections.ArrayList]::new()
    $jobContext = $Context.Resolver.ResolveProxyObjects(@('Config','Registry'))

    foreach ($Client in $Clients) {
        $runningJobs.Add((Start-Job -ArgumentList $Client, $Credential, $jobContext -ScriptBlock {
            param(
                [object]$Computer,
                [pscredential]$Credential,
                [object]$Context
            )
            if(ComputerActive -Computer $Computer -Type "TS") {
                $session = New-PSSession -ComputerName $Computer.ip -Credential $Credential
            } else {
                $session = $null
            }
            try {
                $results = [System.Collections.ArrayList]::new()
                foreach ($task in $Context.Tasks) {
                    try {
                        $runtimeState = @{
                            Computer = $Computer
                            Session  = $session
                        }
                        $params = ParamNormalization -Task $task -Context $Context -RuntimeState $runtimeState -Verbose:$Context.Config.Verbose
                        $result = if ($null -ne $session -and $task.RemoteExecution) {
                            Invoke-Command -Session $session @params
                        } elseif (-not $task.RemoteExecution) {
                            & $params.ScriptBlock $params.ArgumentList[0]
                        } else {
                            @{
                                Success = $false
                                Message = "ParallelRemotingJobs: Session required, but could not be established" 
                            }
                        }

                        if ($task.RenewSession -eq $true) {
                            if($null -ne $session){
                                Remove-PSSession -Session $session
                            }
                            $session = New-PSSession -ComputerName $Computer.ip -Credential $Credential
                        }

                        $results.Add(@{
                            Computer = $Computer
                            DisplayName = $task.DisplayName
                            Description = $task.Description
                            AffectsProgress = $task.AffectsProgress
                            Result = $result
                        })
                    } catch {
                        $results.Add(@{
                            Computer = $Computer
                            DisplayName = $task.DisplayName
                            Description = $task.Description
                            AffectsProgress = $task.AffectsProgress
                            Result = @{
                                Message = $_.Exception.Message
                                Function= $_.InvocationInfo.MyCommand.Name
                                Script  = $_.InvocationInfo.ScriptName
                                Line    = $_.InvocationInfo.ScriptLineNumber
                                Stack   = $_.ScriptStackTrace
                            }

                        })
                    }
                }
            } catch {
                Write-Debug "Error on $($Computer.hostname): $_"
                continue
            } finally {
                Remove-PSSession $session
            }
            if($Context.Config.Verbose){
                Import-Module Debugger
                Inspect $results
            }
            return $results
        }))
    }

    $counter = 0
    $lock = New-Object object
    $totalTasks = $Clients.Count * @($Context.Tasks | Where-Object { $_.AffectsProgress -eq $true }).Count
    $preMessage = "Total tasks: $totalTasks"
    $Context.Logger.Info($preMessage)

    if($ProgressCallback){
        & $ProgressCallback $preMessage "Starting..." 0
    }
    while ($runningJobs.Count -gt 0) {
        foreach ($job in $runningJobs.ToArray()) {
            if ($job.State -in @("Completed", "Failed", "Stopped")) {
                $jobResults = Receive-Job -Job $job -ErrorAction SilentlyContinue
                Remove-Job -Job $job -Force
                $null = $runningJobs.Remove($job)
                foreach ($result in $jobResults) {
                    [System.Threading.Monitor]::Enter($lock)
                    try {
                        if ($result.AffectsProgress) {
                            $counter++
                            if($percent -le 100){
                                $percent = [math]::Round(($counter / $totalTasks) * 100)
                                if ($ProgressCallback) {
                                    & $ProgressCallback "Task $counter/$totalTasks" "$($result.Computer.hostname): $($result.Description)" $percent
                                    Start-Sleep -Milliseconds 100
                                }
                                $Context.Logger.Info("$($result.Computer.hostname) Task $counter/$totalTasks ($percent%): $($result.DisplayName)")
                            }
                        }
                    } finally {
                        [System.Threading.Monitor]::Exit($lock)
                    }
                }
            }
        }
    }
    $completeMessage = "$totalTasks tasks completed"
    $Context.Logger.Info($completeMessage)
    $Context.Logger.Info("-------------------------------------------------------")
    if($ProgressCallback){
        & $ProgressCallback $preMessage $completeMessage 100
        & $ProgressCallback "null" "null" 101
    }
}

# function ExecuteTaskPipeline {
#     param(
#         [Parameter(Mandatory)]$Context,
#         [string[]]$Computers,
#         [pscredential]$Credential
#     )

#     # Phase 0: Local configuration
#     foreach ($task in $Context.Tasks | Where-Object ExecutionScope -eq 'Local') {
#         & $task.Script $Context
#     }

#     # Phase 1+2: Remote execution
#     $Context.Tasks = $Context.Tasks | Where-Object ExecutionScope -eq 'Remote'
#     ParallelRemotingJobs -Computers $Computers -Credential $Credential -Context $Context
# }
