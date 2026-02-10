<#
.SYNOPSIS
    Performs an API request with support for permanent entry URLs that redirect (HTTP 302) 
    to versioned or temporary API endpoints.

.DESCRIPTION
    RedirectAwareApiRequest loads a configuration file containing:
      - GeneralUrl: A stable, permanent entry point (e.g. Google Apps Script WebApp URL)
      - CachedURL: (optional) The last known direct API endpoint after resolving a redirect
    
    Workflow:
      1. If a CachedURL is available, it will be used first.
         - If it works, no further resolution is done.
         - If it fails, the CachedURL will be discarded and the GeneralUrl will be used.
      2. The GeneralUrl is requested with redirect following disabled (-MaximumRedirection 0).
         - If the API directly returns JSON without redirect, that JSON is used.
         - If an HTTP 302 redirect is encountered, the "Location" header is stored as CachedURL 
           and the request is repeated on that new direct URL.
      3. Updated configuration (with the new CachedURL) is saved back to disk.

    This design is especially useful for APIs that:
      - Provide a permanent, version-independent entry URL.
      - Redirect (HTTP 302) to a temporary or versioned URL for the actual data.
      - Change the direct endpoint periodically, making caching beneficial.

.PARAMETER ConfigPath
    Path to the JSON configuration file.
    Example:
    {
        "GeneralUrl": "https://script.google.com/macros/s/EXAMPLE/exec",
        "CachedURL":  "https://script.googleusercontent.com/macros/echo?...<version specific>..."
    }

.EXAMPLE
    $data = RedirectAwareApiRequest -ConfigPath "C:\config\myapi.json"

.NOTES
    Author: Your Name
    Version: 1.0
#>
function ApiRequest {
    param(
        [string]$ConfigPath
    )

    # -----------------------------
    # Step 1: Load configuration
    # -----------------------------
    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }
    $Config = Get-Content $ConfigPath | ConvertFrom-Json

    $JsonData = $null

    # -----------------------------
    # Step 2: Try cached direct URL
    # -----------------------------
    # If a direct URL (CachedURL) exists in the config, 
    # try to use it first to skip the redirect.
    if ($Config.PSObject.Properties.Name -contains 'CachedURL' -and $Config.CachedURL) {
        try {
            Write-Host "Trying cached direct API URL..." -ForegroundColor Cyan
            $JsonData = Invoke-RestMethod -Uri $Config.CachedURL -UseBasicParsing -ErrorAction Stop
        }
        catch {
            Write-Warning "Cached direct API URL is invalid or expired."
            $JsonData = $null
        }
    }

    # -----------------------------
    # Step 3: Request general API URL
    # -----------------------------
    # If no cached data is available or it failed,
    # call the general API URL without allowing redirects.
    # There are two possible outcomes here:
    #   (A) No redirect -> We get the JSON directly (normal API behavior).
    #   (B) HTTP 302 redirect -> API returns a Location header with the actual data URL.
    if (-not $JsonData) {
        Write-Host "Requesting general API URL..." -ForegroundColor Yellow
        try {
            # Try to get JSON directly (no redirect allowed)
            $JsonData = Invoke-RestMethod -Uri $Config.GeneralUrl -UseBasicParsing -MaximumRedirection 1 -ErrorAction Stop
        } catch [System.Net.WebException] {
            # Check if it's an HTTP redirect (302 Found)
            if ($_.Exception.Response.StatusCode.value__ -eq 302) {
                # Extract new direct URL from Location header
                $Config.CachedURL = $_.Exception.Response.Headers["Location"]
                Write-Host "New direct URL found: $($Config.CachedURL)" -ForegroundColor Green

                # Save updated config with new direct URL
                $Config | ConvertTo-Json | Set-Content $ConfigPath -Encoding UTF8

                # Request JSON from the direct URL
                $JsonData = Invoke-RestMethod -Uri $Config.CachedURL -UseBasicParsing -ErrorAction Stop
            } else {
                # Any other HTTP error (4xx or 5xx) is rethrown
                throw "Error requesting general API URL: $($_.Exception.Message)"
            }
        }
    }
    return $JsonData
}