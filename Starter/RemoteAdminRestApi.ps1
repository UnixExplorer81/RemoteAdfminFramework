# RestApi.ps1
using module RestApiWrapper

# Defining API listener port number
$ApiPort = 8080

# Defining API endpoint name
$ApiEndpoint = "remote-admin"

# Defining Api script to wrapp by RestApiWrapper.ps1
$ApiPath = Join-Path $PSScriptRoot 'PsRemoteAdminFramework.ps1'
# $ApiPath = '.\PsRemoteAdminFramework.ps1'

# Defining API script payload parameter name
$InputParamName = "InvokeApi"

# Defining the request body validation script
$ApiValidator = {
    param($Request)

    Import-Module Pode

    # JSON-Body lesen
    $body = $Request.Body | ConvertFrom-Json -ErrorAction Stop

    # Validierung
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

RestApiWrapper -ApiPath $ApiPath -InputParamName $InputParamName -ApiEndpoint $ApiEndpoint -ApiValidator $ApiValidator -Port $ApiPort
