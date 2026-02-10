
function ConvertToHashtable {
    param([Parameter(ValueFromPipeline)]$InputObject)
    process {
        if ($null -eq $InputObject) { return $null }
        elseif ($InputObject -is [System.Collections.IDictionary]) {
            $hash = @{}
            foreach ($key in $InputObject.Keys) {
                $hash[$key] = ConvertToHashtable $InputObject[$key]
            }
            return $hash
        } elseif ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
            # Flatten nested enumerables (avoid array-of-array)
            $list = @()
            foreach ($item in $InputObject) {
                $converted = ConvertToHashtable $item
                if ($converted -is [System.Collections.IEnumerable] -and -not ($converted -is [string])) {
                    $list += @($converted)
                }
                else {
                    $list += ,$converted
                }
            }
            return ,$list
        } elseif ($InputObject -is [PSCustomObject]) {
            $hash = @{}
            foreach ($prop in $InputObject.PSObject.Properties) {
                $hash[$prop.Name] = ConvertToHashtable $prop.Value
            }
            return $hash
        } else { return $InputObject }
    }
}
