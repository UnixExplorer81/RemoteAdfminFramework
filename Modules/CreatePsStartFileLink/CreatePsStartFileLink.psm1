function CreatePsStartFileLink {
    param (
        [Parameter(Mandatory)]
        [string]$TargetScript,

        [Parameter()]
        [string]$LinkName = ("{0}.lnk" -f (Get-Item $TargetScript).BaseName),

        [Parameter()]
        [ValidateSet("Desktop", "StartMenu", "Custom")]
        [string]$Location = "Desktop",

        [Parameter()]
        [string]$CustomTargetFolder,

        [Parameter()]
        [switch]$PS7
    )

    # Determine shortcut target folder
    switch ($Location) {
        "Desktop"   { $ShortcutPath = Join-Path -Path $env:USERPROFILE -ChildPath "Desktop\$LinkName" }
        "StartMenu" { $ShortcutPath = Join-Path -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs" -ChildPath $LinkName }
        "Custom"    {
            if (-not $CustomTargetFolder) {
                throw "CustomTargetFolder must be specified if Location is 'Custom'."
            }
            $ShortcutPath = Join-Path -Path $CustomTargetFolder -ChildPath $LinkName
        }
    }

    # Shortcut points to powershell.exe
    $Ps5Exe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Ps7Exe = "$env:PROGRAMFILES\PowerShell\7\pwsh.exe"
    $targetPath = if ($PS7) {
        $Ps7Exe
    } else {
        $Ps5Exe
    }
    $Arguments = "-ExecutionPolicy Bypass -File `"$TargetScript`" -ExecutedByShortcut"

    # Create shortcut
    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $targetPath
    $Shortcut.Arguments  = $Arguments
    $Shortcut.WorkingDirectory = Split-Path -Path $TargetScript
    # $Shortcut.WindowStyle = 1
    $Shortcut.IconLocation = "$targetPath,0"
    $Shortcut.Save()

    # Enable "Run as administrator" via bit manipulation
    $bytes = [System.IO.File]::ReadAllBytes($ShortcutPath)
    $bytes[21] = $bytes[21] -bor 0x20
    [System.IO.File]::WriteAllBytes($ShortcutPath, $bytes)

    Write-Host "Shortcut created at: $ShortcutPath" -ForegroundColor Green
}
