function ResolveApiRequestPath {
    param(
        [Parameter(Mandatory)][object]$Node,
        [Parameter(Mandatory)][string[]]$Path,
        [Parameter(Mandatory)][object]$Context
    )
    
    $Context.Logger.Info("Non-interactive call: $($Path -join ' > ')")

    # Resolve node
    $current = $Node
    $resolvedPath = @()
    $remainingPath = $Path
    foreach ($segment in $Path) {
        if ($current.Keys -contains $segment) {
            $current = $current[$segment]
            $resolvedPath += $segment
            $remainingPath = $remainingPath[1..($remainingPath.Count - 1)]
        } else {
            $Context.Logger.Success("Path found: $($resolvedPath -join ' > ')")
            break
        }
    }
    # Check if we have a job
    if ($current -isnot [array] -or $current.Count -lt 2) {
        $Context.Logger.Error("ResolveApiRequestPath: No executable job on path $($Path -join ' > ')")
        return
    }

    $description = $current[0]
    $entryPoint  = $current[1]
    $tasks = @()
    for ($j = 2; $j -lt $current.Count; $j++) {
        $e = $current[$j]
        if ($e -is [System.Collections.Hashtable] -and $e.ContainsKey('Description') -and $e.ContainsKey('Script')) {
            $tasks += $e
        } else {
            $Context.Logger.Error("ResolveApiRequestPath: Invalid job entry: $e")
            return
        }
    }

    # Execute entry point
    if ($entryPoint -is [ScriptBlock]) {
        if($tasks.Count){
            $Context | Add-Member -NotePropertyName 'Tasks' -NotePropertyValue $tasks -Force
        }
        $Context | Add-Member -NotePropertyName 'Path' -NotePropertyValue ($remainingPath) -Force
        $Context.Logger.Info("Job started: $description")
        & $entryPoint $Context
        $Context.Logger.Info("Non-interactive call executed")
    } else {
        $Context.Logger.Error("ResolveApiRequestPath: The entry point is not a script block")
        return
    }

}