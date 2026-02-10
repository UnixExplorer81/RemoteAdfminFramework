using module "RemoteDesktopProcess"

function TerminateFixRestart {
    param (
        [Parameter(Mandatory)][string]$ComputerName,
        [Parameter(Mandatory)][PSCredential]$Credential,
        [Parameter(Mandatory)][string]$Path,
        [string]$Arguments = "",
        [ScriptBlock]$Callback = $null
    )
    $session = New-PSSession -ComputerName $ComputerName -Credential $Credential
    if($session){
        # 1. exit desired program
        StopRemoteDesktopProcess -Session $session -Path $Path
        # 2. run Callback to apply any fixes (optional)
        if ($Callback) {
            Invoke-Command -Session $session -ScriptBlock $Callback
        }
        # 3. restart the program
        StartRemoteDesktopProcess -Session $session -Path $Path -Arguments $Arguments
    }else{
        Write-Host "⚠️ $Computer is unreachable" -ForegroundColor Yellow
    }
}