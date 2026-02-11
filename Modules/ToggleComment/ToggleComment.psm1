function ToggleComment {
    $editor = $psISE.CurrentFile.Editor
    $selection = $editor.SelectedText

    if ([string]::IsNullOrWhiteSpace($selection)) {
        # Keine Auswahl → ganze aktuelle Zeile wählen
        $editor.SelectCaretLine()
        $selection = $editor.SelectedText
    } else {
        $fullText = $editor.Text
        $startOffset = $fullText.IndexOf($selection, [System.StringComparison]::Ordinal)
        if ($startOffset -eq -1) {
            Write-Verbose "Auswahl konnte nicht im Editor-Text gefunden werden."
            return
        }
        $before = $fullText.Substring(0, $startOffset)
        $lineStart = ($before -split "`r?`n").Count
        $selLines = $selection -split "`r?`n"
        $lineEnd = $lineStart + $selLines.Count - 1

        # Grenzen der "sinnvollen" Auswahl ermitteln (ohne Leerzeilen außen)
        $startTrim = 0
        $endTrim = 0

        # Führe nur durch, wenn überhaupt Zeilen vorhanden sind
        for ($i = 0; $i -lt $selLines.Count; $i++) {
            if ($selLines[$i].Trim() -ne '') { break }
            $startTrim++
        }
        for ($i = $selLines.Count - 1; $i -ge 0; $i--) {
            if ($selLines[$i].Trim() -ne '') { break }
            $endTrim++
        }

        # Berechne neue Grenzen
        $lineStart += $startTrim
        $lineEnd -= $endTrim

        # Prüfe, ob noch was übrig ist
<# scheint nicht zu funktionieren, ist aber auch eigentlich nicht noetig
        if ($lineStart -gt $lineEnd) {
            Write-Verboset "Nur Leerzeilen ausgewählt – nichts zu kommentieren."
            return
        }
#>

        # Neuauswahl: nur relevante Zeilen
        $lastLineLength = $editor.GetLineLength($lineEnd)
        $editor.Select($lineStart, 1, $lineEnd, $lastLineLength + 1)
        $selection = $editor.SelectedText
    }

    if ($selection.TrimStart().StartsWith('<#') -and $selection.TrimEnd().EndsWith('#>')) {
        $uncommented = $selection `
            -replace '^[ \t]*<#[ \t]*\r?\n?', '' `
            -replace '\r?\n?[ \t]*#>[ \t]*$', ''
        $editor.InsertText($uncommented)
    } else {
        $commented = "<#`n$selection`n#>"
        $editor.InsertText($commented)
    }
}