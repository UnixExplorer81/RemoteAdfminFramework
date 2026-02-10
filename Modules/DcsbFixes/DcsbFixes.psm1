using module CapabilityProvider

function UpdateSoundsAndPresets {
    param (
        [Parameter(Mandatory)]
        [object]$Context
    )
   
    # Inject Credential 
    Import-Module CredentialInjector -Force
    $CredentialInjector = CredentialInjector -Context $Context
 
    $CapabilityRegistry = [CapabilityRegistry]::new($Context.Registry)
    $dependencies = @('CredentialManager','NetUseAuthentification','UpdateDeployment')
    $Capabilities = $CapabilityRegistry.GetCapabilities($dependencies)
    $Capabilities.CredentialInjector = $CredentialInjector
    $DependencyInjector = DependencyInjector -Capabilities $Capabilities 

    $ScriptBlock = {
        param(
            [Parameter(Mandatory)][object]$Context
        )
        try{
            # using NetUseAuthentification to ensure UpdateDeployment can access UNC paths of the registry
            $source = $Context.Registry.PsRegistryConfig.source
            if ($null -eq $source){
                throw "Invalid or missing PsRegistryConfig.source: $source"
            }
            if ($source -notmatch '^\\\\(?<Server>[^\\]+)\\(?<Share>[^\\]+)(\\.*)?$') {
                throw "Could not detect a server and/or share name in $source"
            }
            try {
                # Receive Credential
                $credential = & $Context.DependencyInjector 'CredentialInjector'
            } catch {
                throw "Error while receiving credential of CredentialInjector module`: $_"
            }
            try {
                # Ensure NetUseAuthentification is loaded
                & $Context.DependencyInjector 'NetUseAuthentification'
                # SMB authentification via NetUseAuthentification
                $uncPath = "\\$($matches.Server)\$($matches.Share)"
                NetUseAuthentification -UncPath $uncPath -Credential $credential -EnableDebugging:$Context.Config.Verbose
            } catch {
                throw "DcsbFixes->UpdateSoundsAndPresets: Could not load NetUseAuthentification module`: $_"
            }                
            $jobs = @(
                @{
                    "\\dc-1\nas\Profiles\Agents" = "C:\ProgramData"
                    directories = @{
                        "DCSB Nuspray" = "DCSB"
                    }
                    deletes = @(
                        "C:\Users\*\AppData\Local\VirtualStore\ProgramData\DCSB\*.xml"
                    )
                    # deletes = @("DCSB\*")
                }
            )
            try {
                # Ensure UpdateDeployment is loaded
                & $Context.DependencyInjector 'UpdateDeployment'
                # Trigger deployment
                UpdateDeployment -Jobs $jobs -EnableDebugLogging:$Context.Config.Verbose
            } catch {
                throw "DcsbFixes->UpdateSoundsAndPresets: Error while execution of UpdateDeployment module`: $_"
            }
            $message = "Deployment on $env:COMPUTERNAME complete"
            return @{
                Success = $true
                Message = $message
            }
        } catch {
            $message = "Fatal error while deployment on $env:COMPUTERNAME`: $_"
            return @{
                Success = $false
                Message = $message
            }
        }
    }.GetNewClosure()
    
    return @{
        ScriptBlock = $ScriptBlock
        ArgumentList = @(@{
            DependencyInjector = $DependencyInjector
        })
    }
}

function ResetGlobalConfig {
    $scriptBlock = {
        $dst = 'C:\ProgramData\DCSB\'
        $hostnameMatch = "^PC-(\d+)(\..+)?$"
        $ConfigFiles = @{
            "Bill"    = "config_Bill.xml"
            "John"    = "config_John.xml"
            "Luke"    = "config_Luke.xml"
            "Mark"    = "config_Mark.xml"
            "Matt"    = "config_Matt.xml"
            "Nikki"   = "config_Nikki.xml"
            "Phillip" = "config_Phillip.xml"
        }
        try {
            # select alternating config file
            if($env:COMPUTERNAME -match $hostnameMatch){
                $PcIndex = [int]$matches[1] - 1
            }
            $ConfigKeys = @($ConfigFiles.Keys | Sort-Object)
            $configKey = $ConfigKeys[$PcIndex % $ConfigKeys.Count]
            $configFile = $ConfigFiles[$configKey]

            # activate selected config file
            $sourceConfig = Join-Path -Path $dst -ChildPath $configFile
            $destinationConfig = Join-Path -Path $dst -ChildPath "config.xml"
            Copy-Item -Path $sourceConfig -Destination $destinationConfig -Force -ErrorAction Stop
            $acl = Get-Acl -Path $sourceConfig
            Set-Acl -Path $destinationConfig -AclObject $acl

            $message = "✅ Copied config: $configFile -> config.xml"
            return @{
                Success = $true
                Message = $message
            }
        } catch {
            $message = "⚠️ Failed to copy $configFile to $destinationConfig`: $($_.Exception.Message)"
            return @{
                Success = $true
                Message = $message
            }
        }        
    }.GetNewClosure()

    return @{
        ScriptBlock = $scriptBlock
        ArgumentList = @(@{})
    }
}

function DumpMessedUpUserConfig {
    param (
        [Parameter(Mandatory)][object]$Context
    )
    try {
        $dependencies = @('UserProfileUtilities')
        $CapabilityRegistry = [CapabilityRegistry]::new($Context.Registry)
        $Context.Capabilities = $CapabilityRegistry.GetCapabilities($dependencies)
        $DependencyProvider = DependencyProvider $Context
    } catch {
        throw "Executing DumpMessedUpUserConfig failed.`: $($_.Exception.Message)"
    }
    $ScriptBlock = {
        try {
            $scriptBlock = if ($Context.DependencyProvider.ScriptBlock -is [scriptblock]) {
                $Context.DependencyProvider.ScriptBlock
            } elseif ($Context.DependencyProvider.ScriptBlock -is [string]) {
                [scriptblock]::Create($Context.DependencyProvider.ScriptBlock)
            }
            # Executeing DependencyProvider
            $DependencyProvider = & $scriptBlock $Context.DependencyProvider.ArgumentList
        } catch {
            throw "Executing DependencyProvider failed.`: $($_.Exception.Message)"
        }
        # Ensure UserProfileUtilities is loaded
        Invoke-Expression (& $DependencyProvider.InjectProvider 'UserProfileUtilities')
        $profilePath = GetUserProfilePath
        if ($profilePath) {
            $username = $username.Split('\')[-1]
            $remove = Join-Path $profilePath "AppData\Local\VirtualStore\ProgramData\DCSB\config.xml"
            if (Test-Path $remove) {
                Remove-Item $remove -Force
                $message = "🗑️ Removed DCSB config of user $($username): $remove"
            } else {
                $message = "ℹ️ File not found: $remove"
            }
            return @{
                Success = $true
                Message = $message
            }
        } else {
            $message = "❌ Users session couldn be found ($username) or No user currently logged in"
            return @{
                Success = $false
                Message = $message
            }
        }
    }.GetNewClosure()

    return @{
        ScriptBlock = $ScriptBlock
        ArgumentList = @(@{
            DependencyProvider = $DependencyProvider
        })
    }
}

function RemoveSoundsAndConfig {
    param (
        [Parameter(Mandatory)][object]$Context
    )
    $Context.Providers = @{}
    # Inject Credential
    Import-Module CredentialInjector -Force
    $Context.Providers.CredentialInjector = CredentialInjector -Context $Context

    $dependencies = @('CredentialManager','NetUseAuthentification','UpdateDeployment')
    $CapabilityRegistry = [CapabilityRegistry]::new($Context.Registry)
    $Context.Capabilities = $CapabilityRegistry.GetCapabilities($dependencies)
    $DependencyProvider = DependencyProvider $Context

    $ScriptBlock = {
        param(
            [Parameter(Mandatory)][object]$Context
        )
        try{
            # using NetUseAuthentification to ensure UpdateDeployment can access UNC paths of the registry
            $source = $Context.Registry.PsRegistryConfig.source
            if ($null -eq $source){
                throw "Invalid or missing PsRegistryConfig.source: $source"
            }
            if ($source -notmatch '^\\\\(?<Server>[^\\]+)\\(?<Share>[^\\]+)(\\.*)?$') {
                throw "Could not detect a server and/or share name in $source"
            }
            try {
                $scriptBlock = if ($Context.DependencyProvider.ScriptBlock -is [scriptblock]) {
                    $Context.DependencyProvider.ScriptBlock
                } elseif ($Context.DependencyProvider.ScriptBlock -is [string]) {
                    [scriptblock]::Create($Context.DependencyProvider.ScriptBlock)
                }
                # Executeing DependencyProvider
                $DependencyProvider = & $scriptBlock $Context.DependencyProvider.ArgumentList
            } catch {
                throw "Executing DependencyProvider failed.`: $($_.Exception.Message)"
            }  
            try {
                # Receive Credential
                $credential = & $DependencyProvider.InjectProvider 'CredentialInjector'
            } catch {
                throw "Error while receiving credential via CredentialInjector`: $($_.Exception.Message)"
            }
            try {
                # Ensure NetUseAuthentification is loaded
                Invoke-Expression (& $DependencyProvider.ImportModule 'NetUseAuthentification')
                # SMB authentification via NetUseAuthentification
                $uncPath = "\\$($matches.Server)\$($matches.Share)"
                NetUseAuthentification -UncPath $uncPath -Credential $credential -EnableDebugging:$Context.Config.Verbose
            } catch {
                throw "Could not load module NetUseAuthentification module`: $($_.Exception.Message)"
            }  
            $jobs = @(
                @{
                    deletes = @(
                        "C:\ProgramData\DCSB\*"
                        "C:\Users\*\AppData\Local\VirtualStore\ProgramData\DCSB\*.xml"
                    )
                }
            )
            try {
                # Ensure UpdateDeployment is loaded
                Invoke-Expression (& $DependencyProvider.ImportModule 'UpdateDeployment')
                # Trigger deployment
                UpdateDeployment -Jobs $jobs -EnableDebugLogging:$Context.Config.Verbose
            } catch {
                throw "Execution of UpdateDeployment module failed`: $($_.Exception.Message)"
            }
            $message = "Deployment on $env:COMPUTERNAME complete"
            return @{
                Success = $true
                Message = $message
            }
        } catch {
            $message = "DcsbFixes->RemoveSoundsAndConfig: Fatal error on $env:COMPUTERNAME`: $($_.Exception.Message)"
            return @{
                Success = $false
                Message = $message
            }
        }
    }.GetNewClosure()
    
    return @{
        ScriptBlock = $ScriptBlock
        ArgumentList = @(@{
            DependencyProvider = $DependencyProvider
        })
    }
}
Export-ModuleMember -Function DumpMessedUpUserConfig, RemoveSoundsAndConfig, ResetGlobalConfig, UpdateSoundsAndPresets
