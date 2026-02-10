function TestFileReadWriteAccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$MessagePrefix = "FileAndDirectoryOperations->TestFileReadWriteAccess: "
    )

    if (-not (Test-Path $Path -PathType Leaf)) {
        Write-Error "$($MessagePrefix)File does not exist: $Path"
        return $false
    }

    try {
        $stream = [System.IO.File]::Open(
            $Path, 
            [System.IO.FileMode]::Open, 
            [System.IO.FileAccess]::ReadWrite, 
            [System.IO.FileShare]::None
        )
        
        $stream.Close()
        $stream.Dispose()
        
        Write-Verbose "$($MessagePrefix)Full access (read+write) confirmed: $Path"
        return $true
    }
    catch [System.UnauthorizedAccessException] {
        Write-Warning "$($MessagePrefix)No read/write permissions: $Path"
        return $false
    }
    catch [System.IO.IOException] {
        Write-Warning "$($MessagePrefix)File is locked or in use: $Path"
        return $false
    }
    catch {
        Write-Error "$($MessagePrefix)Unexpected error while testing $Path : $_"
        return $false
    }
}

function TestDirectoryWriteAccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$MessagePrefix = "FileAndDirectoryOperations->TestDirectoryWriteAccess: "
    )

    if (-not (Test-Path $Path -PathType Container)) {
        Write-Error "$($MessagePrefix)Path is not a directory: $Path"
        return $false
    }

    try {
        $testFile = Join-Path $Path ([Guid]::NewGuid().ToString() + ".tmp")

        [System.IO.File]::WriteAllText($testFile, "test")
        Remove-Item $testFile -Force

        Write-Verbose "$($MessagePrefix)Write access confirmed for directory: $Path"
        return $true
    } catch {
        Write-Warning "$($MessagePrefix)No write access of directory: $Path"
        return $false
    }
}

function TestWriteAccessStrict {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$MessagePrefix = "FileAndDirectoryOperations->TestWriteAccessStrict: "
    )

    if (Test-Path $Path -PathType Container) {
        $testFile = Join-Path $Path ([Guid]::NewGuid().ToString() + ".tmp")
        try {
            [System.IO.File]::WriteAllText($testFile, "test")
            Remove-Item $testFile -Force
            Write-Verbose "$($MessagePrefix)Write access confirmed for: $Path"
            return $true
        } catch {
            Write-Warning "$($MessagePrefix)No write access for: $Path"
            return $false
        }
    } elseif (Test-Path $Path -PathType Leaf) {
        try {
            $stream = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None')
            $stream.Close()
            $stream.Dispose()
            return $true
            Write-Verbose "$($MessagePrefix)Write access confirmed for: $Path"
        } catch {
            Write-Warning "$($MessagePrefix)No write access for: $Path"
            return $false
        }
    } else {
        Write-Error "$($MessagePrefix)Path does not exist: $Path"
        return $false
    }
}

function TestWriteAccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$MessagePrefix = "FileAndDirectoryOperations->TestWriteAccess: "
    )

    # Fall 1: Pfad ist bereits ein Verzeichnis → prüfe Schreibrechte darauf
    if (Test-Path $Path -PathType Container) {
        $testFile = Join-Path $Path ([Guid]::NewGuid().ToString() + ".tmp")
        try {
            [System.IO.File]::WriteAllText($testFile, "test")
            Remove-Item $testFile -Force
            Write-Verbose "$($MessagePrefix)Write access confirmed for directory: $Path"
            return $true
        }
        catch {
            Write-Warning "$($MessagePrefix)No write access to directory: $Path"
            return $false
        }
    }

    # Fall 2: Pfad ist (soll) eine Datei sein
    $parentDir = Split-Path $Path -Parent

    # Parent-Verzeichnis muss existieren und schreibbar sein
    if (-not (Test-Path $parentDir -PathType Container)) {
        Write-Error "$($MessagePrefix)Parent directory does not exist: $parentDir"
        return $false
    }

    # Test: Kann ich im Parent eine temporäre Datei erstellen?
    $testFile = Join-Path $parentDir ([Guid]::NewGuid().ToString() + ".tmp")
    try {
        [System.IO.File]::WriteAllText($testFile, "test")
        Remove-Item $testFile -Force

        # Wenn die Datei schon existiert → zusätzlich echten RW-Test machen
        if (Test-Path $Path -PathType Leaf) {
            $stream = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None')
            $stream.Close()
            $stream.Dispose()
        }

        Write-Verbose "$($MessagePrefix)Write access confirmed for path: $Path"
        return $true
    }
    catch {
        Write-Warning "$($MessagePrefix)No write access for path: $Path"
        return $false
    }
}

function EnsureDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$MessagePrefix = "FileAndDirectoryOperations->EnsureDirectory: "
    )

    if (Test-Path $Path -PathType Container) {
        $dir = $Path
    } else {
        $dir = Split-Path $Path -Parent
    }

    if (-not (Test-Path $dir)) {
        try {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-Verbose "$($MessagePrefix)directory was created: $dir"
            return $true
        } catch {
            throw "$($MessagePrefix)Failed to create directory: $dir - $($_.Exception.Message)"
        }
    }

    return $true
}