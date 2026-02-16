
<#
    Universal REST API Wrapper
    How to install Pode:
    Install-Module Pode -Scope CurrentUser
#>
function RestApiWrapper {
    <#
        # Defining the API endpoint name
        $ApiEndpoint = "remote-admin"

        # Defining Api script to wrapp by RestApiWrapper.ps1
        $ApiPath = Join-Path $PSScriptRoot 'PsRemoteAdminFramework.ps1'
        $ApiPath = ".\PsRemoteAdminFramework.ps1"

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

    Import-Module Pode

    Start-PodeServer {
        Add-PodeEndpoint -Address * -Port $Port -Protocol Http

        # POST /api/<Endpoint>
        Add-PodeRoute -Method Post -Path "/api/$ApiEndpoint" -ScriptBlock {
            try {
                # Validator ausführen (Scope des Wrappers!)
                $payload = & $using:ApiValidator $Request

                # Start-Script aufrufen (asynchron)
                $job = Start-Job -FilePath $using:ApiPath -ArgumentList $payload
                
                # $job = Start-Job -ArgumentList $using:ApiPath, $payload -ScriptBlock {
                #     param(
                #         [string]$ScriptPath,
                #         [object]$ApiInput
                #     )
                #     & $ScriptPath $ApiInput
                # }

                # $response = @{}
                # $response.status = "Job accepted"
                # $response.jobId = $job.Id
                # foreach ($key in $payload.Keys) {
                #     $response[$key] = Flatten $payload[$key]
                # }
                # $response.started = Get-Date -Format "o"
                # Write-PodeJsonResponse -Value $response -StatusCode 202

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

        # Add-PodeRoute -Method Get -Path "/api/$ApiEndpoint-status" -ScriptBlock {
        #     $allJobs = Get-Job
        #     $completedJobs = $allJobs | Where-Object { $_.State -eq 'Completed' }
        #     $jobInfos = $completedJobs | ForEach-Object {
        #         [ordered]@{
        #             jobId = $_.Id
        #             name  = $_.Name
        #             state = $_.State
        #             started = $_.PSBeginTime
        #             finished = $_.PSEndTime
        #         }
        #     }
        #     $jobInfos = $jobInfos | Sort-Object finished -Descending
        #     Write-PodeJsonResponse -Value @{
        #         status = "API running"
        #         time = Get-Date -Format "o"
        #         completedJobs = $jobInfos
        #     }
        # }
    }
}
