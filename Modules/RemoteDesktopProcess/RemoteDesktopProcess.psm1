function StartRemoteDesktopProcess {
    [CmdletBinding(DefaultParameterSetName = 'ByComputer')]
    param (
        # --- Option 1: Session usage ---
        [Parameter(Mandatory, ParameterSetName = 'BySession')]
        [System.Management.Automation.Runspaces.PSSession]$Session,

        # --- Option 2: ComputerName + Credential ---
        [Parameter(Mandatory, ParameterSetName = 'ByComputer')]
        [string]$ComputerName,

        [Parameter(Mandatory, ParameterSetName = 'ByComputer')]
        [PSCredential]$Credential,

        # --- Common Parametersr ---
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Arguments = ""
    )

    # Preparing command for target computer
    $scriptBlock = {
        param (
            [Parameter(Mandatory)]
            [string]$Path,
            [string]$Arguments
        )

        function Start-DesktopProcess {
            param (
                [Parameter(Mandatory)]
                [string]$Path,
                [string]$Arguments
            )
            $taskName = "TempLaunch_$(Get-Random)"
            $taskCommand = "'$Path' $Arguments"
            $startTime = (Get-Date).AddMinutes(3).ToString("HH:mm")

            schtasks /Create /TN $taskName /TR "$taskCommand" /SC ONCE /ST $startTime /RU "INTERACTIVE" /RL HIGHEST /F | Out-Null
            schtasks /Run /TN $taskName | Out-Null

            Start-Sleep -Seconds 5
            $state = schtasks /Query /TN $taskName
            if ($state -like "*Running*") {
                schtasks /Delete /TN $taskName /F | Out-Null
                return $true
            }
            return $false
        }
        $program = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        if(Start-DesktopProcess -Path $Path -Arguments $Arguments){
            Write-Host "🚀 $program started on $env:COMPUTERNAME." -ForegroundColor Green
        }else{
            Write-Host "⚠️ Failed to start $program on $env:COMPUTERNAME." -ForegroundColor Red
        }
    }

    # Preparing parameter for remote execution
    $params = @{
        ScriptBlock  = $scriptBlock
        ArgumentList = @($Path, $Arguments)
    }

    if ($PSCmdlet.ParameterSetName -eq 'BySession') {
        $ComputerName = $Session.ComputerName
        $params.Session = $Session
    } else {
        $params.ComputerName = $ComputerName
        $params.Credential = $Credential
    }

    Write-Host "📡 Connecting to $ComputerName..." -ForegroundColor Cyan

    Invoke-Command @params
}

function StopRemoteDesktopProcess {
    [CmdletBinding(DefaultParameterSetName = 'ByComputer')]
    param (
        # --- Option 1: Session usage ---
        [Parameter(Mandatory, ParameterSetName = 'BySession')]
        [System.Management.Automation.Runspaces.PSSession]$Session,

        # --- Option 2: ComputerName + Credential ---
        [Parameter(Mandatory, ParameterSetName = 'ByComputer')]
        [string]$ComputerName,

        [Parameter(Mandatory, ParameterSetName = 'ByComputer')]
        [PSCredential]$Credential,

        # --- Common Parameters ---
        [Parameter(Mandatory)][string]$Path
    )

    # Preparing command for target computer
    $scriptBlock = {
        param (
            [Parameter(Mandatory)]
            [string]$Path
        )

        $Process = [System.IO.Path]::GetFileNameWithoutExtension($Path)

        Write-Host "⏳ Attempting to terminate $Process on $env:COMPUTERNAME." -ForegroundColor Yellow

        # Nur wenn der Prozess existiert
        $proc = Get-Process -Name $Process -ErrorAction SilentlyContinue
        if ($proc) {
            $proc | Stop-Process -Force
            Write-Host "⛔ Process $Process got terminated on $env:COMPUTERNAME." -ForegroundColor Green
        } else {
            Write-Host "ℹ️ Process $Process not found on $env:COMPUTERNAME." -ForegroundColor Blue
        }
    }

    # Preparing parameter for remote execution
    $params = @{
        ScriptBlock  = $scriptBlock
        ArgumentList = @($Path)
    }

    if ($PSCmdlet.ParameterSetName -eq 'BySession') {
        $ComputerName = $Session.ComputerName
        $params.Session = $Session
    } else {
        $params.ComputerName = $ComputerName
        $params.Credential = $Credential
    }

    Write-Host "📡 Connecting to $ComputerName..." -ForegroundColor Cyan

    Invoke-Command @params
}