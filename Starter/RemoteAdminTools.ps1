using module ProxyPlaceholderResolver
using module Logger

<#
    .\RemoteAdminTools.ps1 -InvokeApi @{
        Path   = @("Network", "Wake Clients (WoL)")
        Memory = @{
            StationSelector = @{
                selection = @("AI-086")
            }
        }
    }
    .\RemoteAdminTools.ps1 -InvokeApi @{ 
        Path = @("Soundboard", "Restart (if hotkey recognition fails)", "Specific stations")
        Memory = @{ StationSelector = @{ selection = @("AI-086") } }
    }
#>
[CmdletBinding(DefaultParameterSetName = 'Interactive')]
param(
    [Parameter(ParameterSetName = 'Interactive')]
    [switch]$ExecutedByShortcut,

    [Parameter(Mandatory = $true, ParameterSetName = 'ApiMode', Position = 0)]
    [object]$InvokeApi
)

try {
    $IsApiMode = $PSCmdlet.ParameterSetName -eq 'ApiMode'
    if ($IsApiMode) {
        if ($null -eq $InvokeApi.Path -or $InvokeApi.Path -isnot [array] -or $InvokeApi.Path.Count -eq 0) {
            Write-Error "ApiMode requires 'Path' to be a non-empty string array"
            exit 1
        }
        if ($null -ne $InvokeApi.Memory -and $InvokeApi.Memory -isnot [hashtable]) {
            Write-Error "InvokeApi.Memory must be a hashtable if provided"
            exit 1
        }
        $Memory = if ($null -ne $InvokeApi.Memory) { $InvokeApi.Memory } else { @{} }
    } else {
        Start-Sleep -Seconds 1
        if (-not $ExecutedByShortcut) {
            Import-Module CreatePsStartFileLink
            CreatePsStartFileLink -TargetScript $MyInvocation.MyCommand.Definition -PS7
            Start-Sleep -Seconds 1
        }
        $Memory = @{}
    }

    $Context = [pscustomobject]@{}
    $Resolver = [ProxyPlaceholderResolver]::new()
    $Context | Add-Member -NotePropertyName 'Resolver' -NotePropertyValue $Resolver
    $callbacks = & 'C:\ProgramData\PowerShell\PlaceholderCallbacks.ps1'
    $Resolver.RegisterCallbacks($callbacks)
    $CfgPsd = Import-PowerShellDataFile "C:\ProgramData\PowerShell\RemoteAdminTools\Config.psd1"
    $Resolver.RegisterSource('CONFIG', $CfgPsd)
    $Config = $Resolver.CreateProxy('CONFIG', $Context, @('AsHashtable','GetKeys'))
    $Context | Add-Member -NotePropertyName 'Config' -NotePropertyValue $Config
    $RegPsd = Import-PowerShellDataFile $Config.PsRegistryConfig.target
    $Resolver.RegisterSource('REGISTRY', $RegPsd)
    $Registry = $Resolver.CreateProxy('REGISTRY', $Context, @('AsHashtable','Filter','GetKeys','GetRecords'))
    $Context | Add-Member -NotePropertyName 'Registry' -NotePropertyValue $Registry
    $Context | Add-Member -NotePropertyName 'Memory' -NotePropertyValue $Memory
    $Logger = [Logger]::new(@{
        LogInfo         = $Config.LogProgress
        LogErrors       = $Config.LogErrors
        UseConsole      = if ($IsApiMode) { $true } else { $false }
        # CatchOutputs    = if ($IsApiMode) { $false } else { $true }
        CatchOutputs    = $false
    })
    $Context | Add-Member -NotePropertyName 'Logger' -NotePropertyValue $Logger -Force
    $Context.Logger.Info("--- 🖥️ $($env:COMPUTERNAME) - Running as: 👤 $(whoami) ---")
    $Node = & (Join-Path $Config.ProgramData $Config.ProgramNodes)
    if ($IsApiMode) {
        Import-Module ExecuteApiRequest
        ExecuteApiRequest -Node $Node -Path $InvokeApi.Path -Context $Context
    } else {
        Import-Module MultiDimensionalMenu
        ShowMenu -Node $Node -Context $Context -MenuName $Config.MenuName -DisplayIndex $Config.DisplayIndex
    }
} catch {
    Write-Error "Fatal error while main program initialization`:"
    Write-Error $_.Exception.Message
    if (-not $IsApiMode) { Pause }
    exit 1
} finally {
    $Logger.Info("Remote Admin Framework was terminated")
    $Logger.Info("-------------------------------------------------------")
}