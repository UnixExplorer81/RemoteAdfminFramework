<#
==============================================
CsvManager – Minimal CSV Manager with Locking
==============================================

This module provides:
- Management of multiple CSV files simultaneously
- Insert and update records
- Sorting by a primary key
- Thread-/process-safe writing using file locks
- Support for CSVs with or without headers

-------------------------------------------------
Functions:
-------------------------------------------------
1. RegisterCsvSchema
   Registers a CSV file and its schema.
   Parameters:
     -Path        : File path
     -Delimiter   : Column separator
     -Headers     : Column headers (array or comma-separated string, optional for CSV without headers)
     -PrimaryKey  : Primary key (name if headers, index if no headers)

   Example:
   $Csv = "C:\Temp\Computers.csv"
   $CsvHeaders = @('hostname','ip','mac','cn','dc','controller')
   RegisterCsvSchema -Path $Csv -Delimiter ";" -Headers $CsvHeaders -PrimaryKey "hostname"

2. GetCsvSchema
   Returns the registration info (schema) for a CSV.
   
   Example:
   $schema = GetCsvSchema -Path $Csv

3. GetCsvRecord
   Retrieves a record by primary key.
   
   Example:
   $record = GetCsvRecord -Path $Csv -Key "DC-1"
   Write-Host $record.ip

4. SetCsvRecord
   Inserts a new record or updates an existing one.
   - Key is optional if headers are defined (automatically derived from PrimaryKey)
   - Locking is handled automatically
   - File is sorted by primary key after write

   Example Insert:
   SetCsvRecord -Path $Csv -Values @{
       hostname   = "DC-2"
       ip         = "192.168.1.254"
       mac        = "AC:22:0B:2A:CE:31"
       cn         = "CN=Domain Computers,CN=Users"
       dc         = "DC=topcall,DC=inc"
       controller = "topcall.inc"
   }

   Example Update (Key not required):
   SetCsvRecord -Path $Csv -Values @{
       hostname = "DC-1"
       ip       = "192.168.1.253"
   }

5. ReadCSVInternal
   Internal function that reads CSVs (with or without lock)
   - Used by SetCsvRecord
   - Supports CSVs with headers (returns PSCustomObjects) or without headers (returns arrays)

6. WriteCsvInternal
   Internal function that writes CSVs into an open FileStream
   - Uses ConvertTo-Csv for header CSVs
   - Joins arrays for headerless CSVs
   - Lock must be held externally (e.g., in SetCsvRecord)
   - Overwrites the file with the given $Records array

7. LockCsv / UnlockCsv
   - Sets an exclusive write lock on the file
   - Waits if another process is currently writing

-------------------------------------------------
Best Practices:
-------------------------------------------------
- Always call RegisterCsvSchema before using a CSV
- Use SetCsvRecord with a hashtable of Values
- If headers exist, Key is optional
- Locking is handled automatically; no need to manually open a FileStream
- For CSVs without headers, Key must be specified
- CSVs are automatically sorted by PrimaryKey after write

-------------------------------------------------
Complete Workflow Example:
-------------------------------------------------
$Csv = "C:\Temp\Computers.csv"
$CsvHeaders = @('hostname','ip','mac','cn','dc','controller')
RegisterCsvSchema -Path $Csv -Delimiter ";" -Headers $CsvHeaders -PrimaryKey "hostname"

# Insert new computer
SetCsvRecord -Path $Csv -Values @{
    hostname   = "DC-1"
    ip         = "192.168.1.254"
    mac        = "AC:22:0B:2A:CE:32"
    cn         = "CN=Domain Computers,CN=Users"
    dc         = "DC=topcall,DC=inc"
    controller = "topcall.inc"
}

# Update existing computer
SetCsvRecord -Path $Csv -Values @{
    hostname = "DC-1"
    ip       = "192.168.1.253"
}

# Retrieve a record
$record = GetCsvRecord -Path $Csv -Key "DC-1"
Write-Host "DC-1 IP: $($record.ip)"

# Read all records (internal)
$allData = ReadCSVInternal -Schema (GetCsvSchema -Path $Csv)

# CSV is always sorted by PrimaryKey after each write

# ============================================
# End of CsvManager Documentation
# ============================================
#>

# ============================
# Module State
# ============================
$Script:CsvSchemas = @{}

# ============================
# Helper: Resolve + Validate Schema
# ============================
function GetCsvSchema {
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    $fullPath = [System.IO.Path]::GetFullPath(
        (Resolve-Path -LiteralPath $Path).ProviderPath
    )

    if (-not $Script:CsvSchemas.ContainsKey($fullPath)) {
        throw "CSV schema for '$fullPath' not registered. Call RegisterCsvSchema first."
    }

    $Script:CsvSchemas[$fullPath]
}

# ============================
# Register Schema
# ============================
function RegisterCsvSchema {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Delimiter,

        [object]$Headers,

        [Parameter(Mandatory)]
        [object]$PrimaryKey
    )

    $fullPath = (Resolve-Path -LiteralPath $Path).ProviderPath

    $schema = @{
        Path        = $fullPath
        Delimiter   = $Delimiter
        HasHeader   = $false
        Headers     = $null
        PrimaryKey  = $null
    }

    # ---- Headers ----
    if ($Headers) {
        $schema.HasHeader = $true

        if ($Headers -is [string]) {
            $schema.Headers = $Headers -split '\s*,\s*'
        } elseif ($Headers -is [array]) {
            $schema.Headers = $Headers
        } else {
            $schema.Headers = $Headers.PSObject.Properties.Name
        }
    }

    # ---- Primary Key ----
    if ($schema.HasHeader) {
        if ($PrimaryKey -notin $schema.Headers) {
            throw "PrimaryKey '$PrimaryKey' not found in headers"
        }
        $schema.PrimaryKey = $PrimaryKey
    } else {
        if ($PrimaryKey -isnot [int] -or $PrimaryKey -lt 0) {
            throw "PrimaryKey must be a non-negative column index when no headers are used"
        }
        $schema.PrimaryKey = $PrimaryKey
    }

    $Script:CsvSchemas[$fullPath] = $schema
}

# ============================
# ReadCSVInternal
# ============================
function ReadCSVInternal {
    [CmdletBinding(DefaultParameterSetName = 'unlocked')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'unlocked')]
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'locked')]
        [hashtable] $Schema,

        [Parameter(Mandatory, ParameterSetName = 'locked')]
        [System.IO.FileStream]$Stream
    )

    if ($PSCmdlet.ParameterSetName -eq 'unlocked') {
        if ($Schema.HasHeader) {
            Import-Csv -Path $Schema.Path -Delimiter $Schema.Delimiter
        } else {
            Get-Content $Schema.Path | ForEach-Object {
                $_ -split $Schema.Delimiter
            }
        }
    } else {
        $Stream.Position = 0
        $reader  = [System.IO.StreamReader]::new($Stream, $true)
        $content = $reader.ReadToEnd()

        if (-not $content) { return @() }

        if ($Schema.HasHeader) {
            $content -split "\r?\n" |
                Where-Object { $_ -ne '' } |
                ConvertFrom-Csv -Delimiter $Schema.Delimiter
        } else {
            $content -split "\r?\n" |
                Where-Object { $_ -ne '' } |
                ForEach-Object { $_ -split $Schema.Delimiter }
        }
    }
}

# ============================
# WriteCsvInternal
# ============================
function WriteCsvInternal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Schema,

        [Parameter(Mandatory)]
        [System.IO.FileStream] $Stream,

        [Parameter(Mandatory)]
        [object[]] $Records
    )

    $Stream.SetLength(0)
    $Stream.Position = 0

    $writer = [System.IO.StreamWriter]::new(
        $Stream,
        [System.Text.Encoding]::UTF8,
        4096,
        $true
    )

    if ($Schema.HasHeader) {
        # ConvertTo-Csv liefert Strings → in Writer schreiben
        $Records | ConvertTo-Csv -Delimiter $Schema.Delimiter -NoTypeInformation |
            ForEach-Object { $writer.WriteLine($_) }
    } else {
        foreach ($row in $Records) {
            $writer.WriteLine($row -join $Schema.Delimiter)
        }
    }
    $writer.Flush()
}

# ============================
# Get Record
# ============================
function GetCsvRecord {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$Key
    )

    $schema = GetCsvSchema -Path $Path
    $data   = ReadCSVInternal -Schema $schema

    if ($schema.HasHeader) {
        return $data | Where-Object { $_.$($schema.PrimaryKey) -eq $Key }
    } else {
        return $data | Where-Object { $_[$schema.PrimaryKey] -eq $Key }
    }
}

# ============================
# Set (Update / Insert)
# ============================
function SetCsvRecord {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$Values,

        [object]$Key
    )

    $schema = GetCsvSchema -Path $Path

    if (-not $PSBoundParameters.ContainsKey('Key')) {
        if ($schema.HasHeader) {
            $Key = $Values[$schema.PrimaryKey]
        } else {
            throw "Key must be specified when no headers are used"
        }
    }

    $lock = $null

    try {
        $lock = LockCsv -Path $schema.Path
        $data = @(ReadCSVInternal -Schema $schema -Stream $lock)

        $found = $false
        if ($schema.HasHeader) {
            for ($i = 0; $i -lt $data.Count; $i++) {
                if ($data[$i].$($schema.PrimaryKey) -eq $Key) {
                    foreach ($p in $Values.Keys) {
                        $data[$i].$p = $Values[$p]
                    }
                    $found = $true
                    break
                }
            }

            if (-not $found) {
                $row = [ordered]@{}
                foreach ($h in $schema.Headers) {
                    $row[$h] = $Values[$h]
                }
                $data += [pscustomobject]$row
            }

            $data = $data | Sort-Object { $_.$($schema.PrimaryKey) }
        } else {
            for ($i = 0; $i -lt $data.Count; $i++) {
                if ($data[$i][$schema.PrimaryKey] -eq $Key) {
                    $data[$i] = $Values
                    $found = $true
                    break
                }
            }

            if (-not $found) {
                $data += $Values
            }

            $data = $data | Sort-Object { $_[$schema.PrimaryKey] }
        }

        WriteCsvInternal -Schema $schema -Stream $lock -Records $data
        
        return @{ Success = $true }
    } catch {
        return @{ Success = $false; Message = $_ }
    } finally {
        if ($lock) {
            UnlockCsv -FileStream $lock
        }
    }
}

function LockCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [int]$TimeoutSeconds = 30,
        [int]$RetryDelayMs   = 200
    )

    $sw = [Diagnostics.Stopwatch]::StartNew()

    while ($true) {
        try {
            return [System.IO.FileStream]::new(
                $Path,
                [System.IO.FileMode]::OpenOrCreate,
                [System.IO.FileAccess]::ReadWrite,
                [System.IO.FileShare]::Read
            )
        } catch [System.IO.IOException] {
            if ($sw.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                throw "Timeout while waiting for exclusive lock on '$Path'"
            }
            Start-Sleep -Milliseconds $RetryDelayMs
        } catch [System.UnauthorizedAccessException] {
            if ($sw.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                throw "Access denied while waiting for lock on '$Path'"
            }
            Start-Sleep -Milliseconds $RetryDelayMs
        }
    }
}


function UnlockCsv {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileStream]$FileStream
    )

    $FileStream.Close()
    $FileStream.Dispose()
}

Export-ModuleMember -Function RegisterCsvSchema, GetCsvSchema, GetCsvRecord, SetCsvRecord