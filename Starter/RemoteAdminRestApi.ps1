# RemoteAdminApi.ps1
<#
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
#>

# Defining the API endpoint name
$ApiEndpoint = "remote-admin"

# Defining Api script to wrapp by RestApiWrapper.ps1
# $ApiPath = ".\RemoteAdminTools.ps1"
$ApiPath = Join-Path $PSScriptRoot 'RemoteAdminTools.ps1'

# Defining API script payload parameter name
$InputParamName = "-InvokeApi"

# Defining the request body validation script
$ApiValidator = {
    param($Request)

    Import-Module Pode

    # JSON-Body lesen
    $body = $Request.Body | ConvertFrom-Json -ErrorAction Stop

    # Validierung (minimal)
    if ($null -eq $body.Path -or $body.Path -isnot [array] -or $body.Path.Count -eq 0) {
        Write-PodeJsonResponse -Value @{ error = "Path must be a non-empty string array" } -StatusCode 400
        return
    }

    # prepare payload hashtable for Api input
    return @{
        Path   = $body.Path
        Memory = if($null -ne $body.Memory) { $body.Memory } else { @{} }
    }
}
Import-Module RestApiWrapper
RestApiWrapper -ApiPath $ApiPath -InputParamName $InputParamName -ApiEndpoint $ApiEndpoint -ApiValidator $ApiValidator -Port 8080
