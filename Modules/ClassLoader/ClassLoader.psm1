function ClassLoader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootDirectory,
        [Parameter(Mandatory)]
        [string[]]$Modules
    )
    foreach ($m in $Modules) {
        if (Test-Path "$RootDirectory\Modules\$m\$m.psm1") {
            try {
                $c = Get-Content "$RootDirectory\Modules\$m\$m.psm1" -Raw -Encoding UTF8 -ErrorAction Stop
                & ([scriptblock]::Create($c))
                # Invoke-Expression $c -ErrorAction Stop
                # FallbackLog "$($cls.Name)-Klasse erfolgreich geladen" -force
            } catch {
                Invoke-Expression $c -ErrorAction Stop
                # & ([scriptblock]::Create($c))
                # FallbackLog "Fehler beim Laden von $($cls.Name): $_" -error -force
            }
        } else {
            # FallbackLog "$($cls.Name).ps1 nicht gefunden unter $($cls.Path)" -warning -force
        }
    }
}
