function ProgressBar {
    return {
        param(
            [string]$Activity,
            [string]$Status,
            [int]$Percent
        )
        if ($Host.Name -ne 'ConsoleHost') { return }
        if($Percent -le 100){
            Write-Progress -Activity $Activity -Status $Status -PercentComplete $Percent
        }else{
            Start-Sleep -Seconds 3
            Write-Progress -Activity $Activity -Completed
        }        
    }
}