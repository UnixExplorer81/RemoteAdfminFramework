class RunspaceJob {
    [scriptblock]$ScriptBlock
    [hashtable]$Arguments
    [object]$State
    [System.Management.Automation.PowerShell]$PowerShell
    [System.Management.Automation.Runspaces.RunspacePool]$RunspacePool
    [System.IAsyncResult]$AsyncResult
    [bool]$IsCompleted = $false
    [object]$Result
    [System.Exception]$Error

    RunspaceJob([scriptblock]$ScriptBlock, [hashtable]$Arguments, [System.Management.Automation.Runspaces.RunspacePool]$RunspacePool) {
        $this.ScriptBlock = $ScriptBlock
        $this.Arguments   = $Arguments
        $this.RunspacePool = $RunspacePool

        $this.PowerShell = [System.Management.Automation.PowerShell]::Create()
        $this.PowerShell.RunspacePool = $this.RunspacePool

        # Create parameter binding if needed
        $params = @()
        foreach ($key in $Arguments.Keys) {
            $params += $Arguments[$key]
        }

        $this.PowerShell.AddScript($ScriptBlock).AddArgument($Arguments)
    }

    [void] Start() {
        $this.AsyncResult = $this.PowerShell.BeginInvoke()
    }

    [bool] CheckCompletion() {
        if (-not $this.IsCompleted -and $this.AsyncResult.AsyncWaitHandle.WaitOne(0)) {
            try {
                $this.Result = $this.PowerShell.EndInvoke($this.AsyncResult)
            } catch {
                $this.Error = $_.Exception
            }
            $this.IsCompleted = $true
        }
        return $this.IsCompleted
    }

    [void] Dispose() {
        $this.PowerShell.Dispose()
    }

    static [System.Management.Automation.Runspaces.RunspacePool] CreateRunspacePool([int]$Min = 1, [int]$Max = 5) {
        $pool = [runspacefactory]::CreateRunspacePool($Min, $Max)
        $pool.Open()
        return $pool
    }
}

# Beispielnutzung

$runspacePool = [RunspaceJob]::CreateRunspacePool(1, 10)

$jobs = @()

foreach ($i in 1..5) {
    $context = @{ Number = $i }
    $sb = {
        param($context)
        Start-Sleep -Seconds (6 - $context.Number)
        "Done: $($context.Number)"
    }
    
    $job = [RunspaceJob]::new($sb, $context, $runspacePool)
    $job.Start()
    $jobs += $job
}

while ($jobs | Where-Object { -not $_.CheckCompletion() }) {
    Write-Host "." -NoNewline
    Start-Sleep -Milliseconds 500
}

Write-Host "`nResults:"
$jobs | ForEach-Object {
    if ($_.Error) {
        Write-Host "Error: $($_.Error.Message)"
    } else {
        Write-Host $_.Result
    }
    $_.Dispose()
}

$runspacePool.Close()
$runspacePool.Dispose()
