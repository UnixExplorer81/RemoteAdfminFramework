$body = @{
    Path = @("Soundboard", "Restart (if hotkey recognition fails)", "Specific stations")
    Memory = @{
        StationSelector = @{
            selection = @("AI-086")
        }
    }
} | ConvertTo-Json -Depth 5 -Compress

Invoke-RestMethod -Uri "http://localhost:8080/api/remote-admin" `
                -Method Post `
                -Body $body `
                -ContentType "application/json"
