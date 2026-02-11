function ParamNormalization {
    [CmdletBinding()]
    param(
        [hashtable]$Task,
        [hashtable]$Context,
        [hashtable]$RuntimeState
    )

    # Default: Context + Runtime
    $argumentList = @(
        MergeContext -CustomArgs $RuntimeState -DefaultArgs $Context
    )

    if ($task.Script -is [hashtable] -and $task.Script.ContainsKey('ScriptBlock')) {

        $scriptBlockRaw = $task.Script.ScriptBlock

        $scriptBlock =
            if ($scriptBlockRaw -is [scriptblock]) {
                $scriptBlockRaw
            }
            elseif ($scriptBlockRaw -is [string]) {
                Write-Debug "⚠ Task '$($task.Name)' ScriptBlock is string → converting"
                [scriptblock]::Create($scriptBlockRaw)
            }
            else {
                throw "❌ Task '$($task.Name)' ScriptBlock has unexpected type: $($scriptBlockRaw.GetType().FullName)"
            }

        $customArgs = ResolveArgumentList -Params $task.Script
        $argumentList = @(
            MergeContext -CustomArgs $customArgs -DefaultArgs (
                MergeContext -CustomArgs $RuntimeState -DefaultArgs $Context
            )
        )

    } elseif ($task.Script -is [string]) {
        Write-Debug "⚠ Task '$($task.Name)' uses string-based Script"
        $scriptBlock = [scriptblock]::Create($task.Script)
    } elseif ($task.Script -is [scriptblock]) {
        $scriptBlock = $task.Script
    } else {
        throw "❌ Task '$($task.Name)' has unexpected Script type: $($task.Script.GetType().FullName)"
    }

    if ($task.WrappedFunction -eq $true) {
        $params = & $scriptBlock $Context

        if ($params -is [hashtable] -and $params.ContainsKey('ScriptBlock')) {
            $scriptBlock  = $params.ScriptBlock
            $customArgs   = ResolveArgumentList -Params $params

            $argumentList = @(
                MergeContext -CustomArgs $customArgs -DefaultArgs (
                    MergeContext -CustomArgs $RuntimeState -DefaultArgs $Context
                )
            )
        }
    }

    return @{
        ScriptBlock  = $scriptBlock
        ArgumentList = $argumentList
    }
}
# function ParamNormalization {
#     [CmdletBinding()]
#     param(
#         [hashtable]$Task,
#         [object]$Context,
#         [object]$Runtime
#     )
#     $argumentList = @($Context)    
#     if ($task.Script -is [hashtable] -and $task.Script.ContainsKey('ScriptBlock')) {
#         $scriptBlockRaw = $task.Script.ScriptBlock
#         $scriptBlock =
#             if ($scriptBlockRaw -is [scriptblock]) {
#                 $scriptBlockRaw
#             } elseif ($scriptBlockRaw -is [string]) {
#                 Write-Debug "⚠ Task '$($task.Name)' has ScriptBlock as string. Converting..."
#                 [scriptblock]::Create($scriptBlockRaw)
#             } else {
#                 throw "❌ Task '$($task.Name)' ScriptBlock has unexpected type: $($scriptBlockRaw.GetType().FullName)"
#             }
#         $argumentList = @(MergeContext -CustomArgs (ResolveArgumentList -Params $task.Script) -DefaultArgs $Context)
#     } elseif ($task.Script -is [string]) {
#         Write-Debug "⚠️ Task '$($task.Name)' has no structured ScriptBlock → falling back to string-based execution."
#         $scriptBlock = [scriptblock]::Create($task.Script)
#     } elseif ($task.Script -is [scriptblock]) {
#         $scriptBlock = $task.Script
#     } else {
#         throw "❌ Task '$($task.Name)' has Script of unexpected type: $($task.Script.GetType().FullName)"
#     }
#     if ($task.WrappedFunction -eq $true) {
#         $params = & $scriptBlock $Context
#         if ($params -is [hashtable] -and $params.ContainsKey('ScriptBlock')) {
#             $scriptBlock = $params.scriptBlock
#             $argumentList = @(MergeContext -CustomArgs (ResolveArgumentList -Params $params) -DefaultArgs $Context)
#         }
#     }
#     return @{
#         ScriptBlock = $scriptBlock
#         ArgumentList = $argumentList
#     }
# }

function ResolveArgumentList {
    param(
        [hashtable]$Params
    )
    if($Params.ContainsKey('ArgumentList') -and $Params.ArgumentList[0] -is [hashtable]){
        return $Params.ArgumentList[0]
    }
    return @()
}

 function MergeContext {
    param(
        [hashtable]$CustomArgs,
        [hashtable]$DefaultArgs
    )
    $combined = @{}
    $combined += $CustomArgs
    foreach ($key in $DefaultArgs.Keys) {
        if (-not $combined.ContainsKey($key)) {
            $combined[$key] = $DefaultArgs[$key]
        }
    }
    return $combined
}

Export-ModuleMember -Function ParamNormalization