function Inspect {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject
    )

    $expr = $MyInvocation.Line
    if ($expr -match 'Inspect\s+([^\s\|]+)') {
        $varName = $matches[1]
    } else {
        $varName = 'Variable'
    }

    return InspectVar -InputObject $InputObject -Name $varName
}

function InspectVar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $InputObject,

        [string]$Name = "Variable",
        [int]$Indent = 0
    )

    $output = @()
    $indentStr = " " * $Indent

    if ($null -eq $InputObject) {
        $line = "$indentStr$Name = null"
        Write-Host $line
        return @($line)
    }

    $typeName = $InputObject.GetType().FullName
    $line = "$indentStr$Name [$typeName]"
    Write-Host $line
    $output += $line

    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        foreach ($prop in $InputObject.PSObject.Properties) {
            $name = $prop.name
            $nested = InspectVar -InputObject $InputObject.$name -Name "[$name]" -Indent ($Indent + 4)
            $output += $nested
        }
    } elseif ($InputObject -is [System.Collections.IDictionary] -or $InputObject -is [hashtable]) {
        foreach ($key in $InputObject.Keys) {
            $nested = InspectVar -InputObject $InputObject[$key] -Name "[$key]" -Indent ($Indent + 4)
            $output += $nested
        }
    } elseif ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $i = 0
        foreach ($item in $InputObject) {
            $nested = InspectVar -InputObject $item -Name "[$i]" -Indent ($Indent + 4)
            $output += $nested
            $i++
        }
    } else {
        $line = "$indentStr = $InputObject"
        Write-Host $line
        $output += $line
    }

    return $output
}

function WriteException {
    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [string]$Context = "An error occurred"
    )

    $info = $ErrorRecord.InvocationInfo
    $line = $info?.Line
    $pos = $info?.OffsetInLine
    $file = $info?.ScriptName
    $msg  = $ErrorRecord.Exception.Message

    Write-Error "⚠️ $Context"
    Write-Error "📌 Line: $line"
    Write-Error "↩️ Position: $pos"
    Write-Error "📄 File: $file"
    Write-Error "🧾 Message: $msg"
}
function ReturnException {
    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [string]$Context = "An error occurred"
    )
    $info = $ErrorRecord.InvocationInfo
    $line = $info?.Line
    $pos = $info?.OffsetInLine
    $file = $info?.ScriptName
    $msg  = $ErrorRecord.Exception.Message

    $str = "⚠️ $Context`n"
    $str += "📌 Line: $line`n"
    $str += "↩️ Position: $pos`n"
    $str += "📄 File: $file`n"
    $str += "🧾 Message: $msg`n"
    return $str
}