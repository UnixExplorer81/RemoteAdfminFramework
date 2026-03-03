function ComputerActive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$Computer,
        [string]$Type
    )

    Write-Verbose "Testing accessibilty of $($Computer.hostname)..."
    switch ($Type) {
        'TC' {
            TestConnection
        }
        'TP' {
            TestPath
        }
        'TW' {
            TestWSMan
        }
        default {
            TestPath
            TestConnection
            TestWSMan
        }
    }
    Write-Verbose "→ $($Computer.hostname) appears to be unreachable."
    return $false
}

function TestConnection {
    if (Test-Connection -ComputerName $($Computer.ip) -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        Write-Verbose "→ Accessed $($Computer.hostname) via Ping (ICMP)"
        return $true
    }
}
function TestPath {
    if (Test-Path "\\$($Computer.ip)\c$" -ErrorAction SilentlyContinue) {
        Write-Verbose "→ Accessed via c$ share (SMB)"
        return $true
    }
}
function TestWSMan{
    try {
        Test-WSMan -ComputerName $($Computer.ip) -ErrorAction Stop | Out-Null
        Write-Verbose "→ Accessed $($Computer.hostname) via WinRM (Test-WSMan)"
        return $true
    } catch {
        Write-Verbose "→ No reply from $($Computer.hostname) via WinRM"
    }
}
