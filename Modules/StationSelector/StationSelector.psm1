using module CredentialManager
using module ProgressBar

$ProgressCallback = ProgressBar

function StationSelector {
    param (
        [Parameter(Mandatory)][object]$Context
    )
    if ($Host.Name -eq 'ConsoleHost') {
        MultiDimensionalMenu -Node (GetStationSelectMenu -Context $Context) -Path $Context.Path -Context $Context -DisplayIndex $Context.Config.DisplayIndex
    } else {
        ResolveApiRequestPath -Node (GetStationSelectMenu -Context $Context) -Path $Context.Path -Context $Context
    }
}

function GetStationSelectMenu {
    param (
        [Parameter(Mandatory)][object]$Context
    )
    $CredentialFile = $Context.Config.ClientsCredPath
    $Credential = CredentialManager -Key $Context.Config.CredentialKey -Path $CredentialFile -DefaultUser $Context.Config.DefaultAdmin
    return [ordered]@{
        "Specific clients" = @(
            "Manually define specific clients (numbers or hostnames).",
            (SpecificStationsScript -Credential $Credential -Context $Context -ProgressCallback $ProgressCallback)
        )
        "All clients" = @(
            "All clients from $($Context.Config.CsvPath).",
            (AllStationsScript -Credential $Credential -Context $Context -ProgressCallback $ProgressCallback)
        )
    }
}

function AllStationsScript {
    param(
        [Parameter(Mandatory)][object]$Context,
        [Parameter(Mandatory)][pscredential]$Credential,
        [ScriptBlock]$ProgressCallback
    )
    return {
        $Computers = Import-Csv -Path $Context.Config.CsvPath -Delimiter $Context.Config.CsvDelimiter
        $Clients = $Computers | Where-Object {
            ($_.ip -match '^(?:\d{1,3}\.){3}\d{1,3}$') -or
            ($_.hostname -match '^[a-zA-Z0-9\-]+$')
        }
        if (-not $Computers -or $Computers.Count -eq 0) {
            Write-Warning "❌ No valid IPs or hostnames found."
            return
        }
        ParallelRemotingJobs -Clients $Clients -Credential $Credential -Context $Context -ProgressCallback $ProgressCallback -Verbose:$Context.Config.Verbose | Out-Null
        if ($Host.Name -eq 'ConsoleHost') { Pause }
    }.GetNewClosure()
}

function SpecificStationsScript {
    param(
        [Parameter(Mandatory)][object]$Context,
        [Parameter(Mandatory)][pscredential]$Credential,
        [ScriptBlock]$ProgressCallback
    )
    return {
        if ($null -eq $Context.Memory.StationSelector -or 
            $null -eq $Context.Memory.StationSelector.selection -or 
            $Context.Memory.StationSelector.selection.Count -eq 0) 
        {
            Write-Host "`nEnter client numbers or hostnames, comma separated (e.g. 21,25,pc-001), or ranges (25-50,75-100):"
            Write-Host "[Press ESC or ← to cancel]" -ForegroundColor DarkGray
            Write-Host ""
            Write-Host -NoNewline "> "
            $inputValue = ""
            do {
                $k = [System.Console]::ReadKey($true)
                if ($k.Key -eq "Escape" -or $k.Key -eq "LeftArrow") {
                    return
                } elseif ($k.Key -eq "Enter") {
                    if($inputValue.Trim()){
                        Write-Host "`n"
                        break
                    }
                } else {
                    $inputValue += $k.KeyChar
                    Write-Host -NoNewline $k.KeyChar
                }
            } while ($true)

            $Context.Memory.StationSelector = @{}
            $Context.Memory.StationSelector.selection = $inputValue -split ',' | ForEach-Object {
                $netAddress = ($Context.Config.BroadcastAddress -split '\.')[0..2] -join '.'
                $token = $_.Trim()
                switch -Regex ($token) {
                    # Range: e.g. 5-15
                    '^\d+-\d+$' {
                        $begin, $end = $token -split '-' | ForEach-Object { [int]$_ }

                        $begin..$end | ForEach-Object {
                            "$netAddress.$_"
                        }
                    }
                    # Single number: e.g. 21
                    '^\d+$' {
                        "$netAddress.$token"
                    }
                    # Hostname or anything else: e.g. pc-001
                    default {
                        $token
                    }
                }
            }
        }

        $Computers = Import-Csv -Path $Context.Config.CsvPath -Delimiter $Context.Config.CsvDelimiter
        $Clients = @()
        foreach ($token in $Context.Memory.StationSelector.selection) {
            $match = $Computers | Where-Object {
                $_.hostname -eq $token -or
                $_.ip -eq $token -or
                "$netAddress.$token" -eq $_.ip
            }
            if ($match) {
                $Clients += $match
            } else {
                $Clients += [pscustomobject]@{
                    hostname = $token
                    ip       = $token
                    mac      = $null
                }
            }
        }
        if ($Clients.Count -gt 0) {
            ParallelRemotingJobs -Clients $Clients -Credential $Credential -Context $Context -ProgressCallback $ProgressCallback -Verbose:$Context.Config.Verbose | Out-Null
            $Context.Memory.StationSelector.selection = $()
            if ($Host.Name -eq 'ConsoleHost') { Pause }
        }
    }.GetNewClosure()
}