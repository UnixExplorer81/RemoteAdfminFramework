using module Pode

# Universal REST API Wrapper
function RestApiWrapper {
    <#
        # Defining the API endpoint name
        $ApiEndpoint = "remote-admin"

        # Defining Api script to wrapp by RestApiWrapper.ps1
        $ApiPath = ".\RemoteAdminTools.ps1"
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
            if (-not $body.Path -or $body.Path -isnot [array] -or $body.Path.Count -eq 0) {
                Write-PodeJsonResponse -Value @{ error = "Path must be a non-empty string array" } -StatusCode 400
                return
            }

            # prepare hashtable for Api input
            return @{
                Path   = $body.Path
                Memory = if($null -ne $body.Memory) { $body.Memory } else { @{} }
            }
        }
        Import-Module RestApiWrapper
        RestApiWrapper -ApiPath $ApiPath -InputParamName $InputParamName -ApiEndpoint $ApiEndpoint -ApiValidator $ApiValidator -Port 8080
    #>
    param(
        [Parameter(Mandatory)][string]$ApiPath,
        [Parameter(Mandatory)][string]$InputParamName,
        [Parameter(Mandatory)][string]$ApiEndpoint,
        [Parameter(Mandatory)][scriptblock]$ApiValidator,
        [int]$Port = 8080
    )


    Start-PodeServer {
        Add-PodeEndpoint -Address * -Port $Port -Protocol Http

        # POST /api/<Endpoint>
        Add-PodeRoute -Method Post -Path "/api/$ApiEndpoint" -ScriptBlock {
            try {
                # Validator ausführen (Scope des Wrappers!)
                $payload = & $using:ApiValidator $Request
                Import-Module Debugger
                Inspect $payload

                # Start-Script aufrufen (asynchron)
                $job = Start-Job -FilePath $using:ApiPath -ArgumentList (, @{ $using:InputParamName = $payload })
                # $job = Start-Job -ScriptBlock {
                #     param($scriptPath, $ParamName, $Apiinput)
                #     & $scriptPath -$ParamName $Apiinput
                # } -ArgumentList @($ApiPath, $InputParamName, $payload)

                Write-PodeJsonResponse -Value @{
                    status = "Job accepted"
                    jobId = $job.Id
                    Path = $payload.Path -join " > "
                    Clients = $payload.Memory.StationSelector.selection -join ", "
                    started = Get-Date -Format "o"
                } -StatusCode 202
            } catch {
                Write-PodeJsonResponse -Value @{ error = $_.Exception.Message } -StatusCode 500
            }
        }

        # Status-Endpunkt (optional, zum Testen)
        Add-PodeRoute -Method Get -Path '/api/status' -ScriptBlock {
            Write-PodeJsonResponse -Value @{ status = "API running"; time = Get-Date -Format "o" }
        }
    }
}