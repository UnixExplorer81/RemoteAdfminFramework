function MultiDimensionalMenu {
    param (
        [Parameter(Mandatory)][object]$Node,
        [Parameter(Mandatory)][object]$Context,
        [string[]]$Path,
        [string]$MenuName,
        [bool]$DisplayIndex = $false
    )

    if ($MenuName) {
        $script:CurrentMenuName = $MenuName
    } elseif (-not $script:CurrentMenuName) {
        $script:CurrentMenuName = "Menu"
    }
    $MenuName = $script:CurrentMenuName

    $items = [string[]]$Node.Keys

    $selected = 0

    do {
        Clear-Host
        Write-Host ""
        Write-Host ("$($MenuName): " + ($Path -join " > ")) -ForegroundColor $Context.Config.Coloring.Path
        Write-Host ""

        for ($i = 0; $i -lt $items.Count; $i++) {
            $entry = $Node[$items[$i]]
            $label = if($DisplayIndex){ "$($i+1). $($items[$i])" } else { $items[$i] }
            $prefix = if ($i -eq $selected) { ">>" } else { "  " }
            $desc = ""
            if ($i -eq $selected -and $entry[0] -is [string]) {
                $desc = "  ℹ️ $($entry[0])"
            }
            $color = if ($i -eq $selected) { $Context.Config.Coloring.SelectedItem } else { $Context.Config.Coloring.MenuItem }
            Write-Host "$prefix $label$desc" -ForegroundColor $color
        }

        $key = [Console]::ReadKey($true).Key
        switch ($key) {

            'UpArrow'   { if ($selected -gt 0) { $selected-- } elseif ($selected -eq 0) { $selected = $items.Count - 1 } }
            'DownArrow' { if ($selected -lt ($items.Count - 1)) { $selected++ } elseif ($selected -eq $items.Count - 1) { $selected = 0 } }

            { $_ -in 'Enter', 'Spacebar' } {
                
                $choice = $Node[$items[$selected]]
                $label = $items[$selected]

                if ($choice -is [System.Collections.Hashtable] -or $choice -is [System.Collections.Specialized.OrderedDictionary]) {
                    MultiDimensionalMenu -Node $choice -Context $Context -Path ($Path + $label) -DisplayIndex $DisplayIndex
                } elseif ($choice -is [object[]]) {
                    Clear-Host
                    Write-Host ""
                    Write-Host ("$($MenuName): " + (($Path + $label) -join " > ")) -ForegroundColor $Context.Config.Coloring.Path
                    Write-Host ""

                    $description = $choice[0]
                    $entryPoint = $choice[1]
                    $tasks = @()

                    for ($j = 2; $j -lt $choice.Count; $j++) {
                        $e = $choice[$j]
                        if ($e -is [System.Collections.Hashtable] -or $e -is [System.Collections.Specialized.OrderedDictionary] -and $e.Keys -contains 'Description' -and $e.Keys -contains 'Script') {
                            $tasks += $e
                        } else {
                            Write-Warning "❌ Invalid job entry: $e"
                            Pause
                        }
                    }
                    Write-Host "ℹ️ $description" -ForegroundColor $Context.Config.Coloring.Description

                    if ($entryPoint -is [ScriptBlock]) {
                        if($tasks.Count){
                            $Context | Add-Member -NotePropertyName 'Tasks' -NotePropertyValue $tasks -Force
                        }
                        $Context | Add-Member -NotePropertyName 'Path' -NotePropertyValue ($Path + $label) -Force
                        & $entryPoint $Context
                    }
                } else {
                    Write-Warning "❌ Unexpected item type: $($choice.GetType().FullName)"
                    Pause
                }
            }

            'LeftArrow' { return }
            'Escape'    { return }
        }

    } while ($true)
}