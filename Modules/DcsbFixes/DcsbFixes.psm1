function UpdateSoundsAndPresets {
    param (
        [Parameter(Mandatory)]
        [object]$Context
    )
   
    $Context.DependencyInjector = DependencyInjector $Context -Providers @('CredentialProvider')

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
            $DI = & ([scriptblock]::Create($Context.DependencyProvider))
            try {
                # Receive Credential
                $credential = & $DI.GetProvider 'CredentialProvider'
            } catch {
                throw "Error while receiving credential of CredentialProvider`: $_"
            }
            try {
                # Ensure NetUseAuthentification is loaded
                Invoke-Expression (& $DI.GetContent 'NetUseAuthentification')
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
                }
            )
            try {
                # Ensure UpdateDeployment is loaded
                Invoke-Expression (& $DI.GetContent 'UpdateDeployment')
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
        ArgumentList = @(@{})
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
    }

    return @{
        ScriptBlock = $scriptBlock
        ArgumentList = @(@{})
    }
}

function DumpMessedUpUserConfig {
    param (
        [Parameter(Mandatory)][object]$Context
    )

    $ScriptBlock = {
        param([object]$Context)

        # Ensure UserProfileUtilities is loaded
        $DI = & ([scriptblock]::Create($Context.DependencyProvider))
        & $DI.ImportModule 'UserProfileUtilities'
        # Invoke-Expression (& $DI.GetContent 'UserProfileUtilities')
        $profilePath = GetUserProfilePath
        if ($profilePath) {
            $username = $profilePath.Split('\')[-1]
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
        ArgumentList = @(@{})
    }
}

function RemoveSoundsAndConfig {
    param (
        [Parameter(Mandatory)][object]$Context
    )

    # execute CredentialProvider 
    $Context.DependencyInjector = DependencyInjector $Context -Providers @('CredentialProvider')

    $ScriptBlock = {
        param([object]$Context)
        try{
            # using NetUseAuthentification to ensure UpdateDeployment can access UNC paths of the registry
            $source = $Context.Registry.PsRegistryConfig.source
            if ($null -eq $source){
                throw "Invalid or missing PsRegistryConfig.source: $source"
            }
            if ($source -notmatch '^\\\\(?<Server>[^\\]+)\\(?<Share>[^\\]+)(\\.*)?$') {
                throw "Could not detect a server and/or share name in $source"
            }
            $DI = & ([scriptblock]::Create($Context.DependencyProvider))
            try {
                # Receive Credential
                $credential = & $DI.GetProvider 'CredentialProvider'
            } catch {
                throw "Error while receiving credential of CredentialProvider`: $_"
            }
            try {
                # Ensure NetUseAuthentification is loaded
                Invoke-Expression (& $DI.GetContent 'NetUseAuthentification')
                # SMB authentification via NetUseAuthentification
                $uncPath = "\\$($matches.Server)\$($matches.Share)"
                NetUseAuthentification -UncPath $uncPath -Credential $credential -EnableDebugging:$Context.Config.Verbose
            } catch {
                throw "Could not load module NetUseAuthentification`: $($_.Exception.Message)"
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
                Invoke-Expression (& $DI.GetContent 'UpdateDeployment')
                # Trigger deployment
                UpdateDeployment -Jobs $jobs -EnableDebugLogging:$Context.Config.Verbose
            } catch {
                throw "Execution of UpdateDeployment failed`: $($_.Exception.Message)"
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
        ArgumentList = @(@{})
    }
}
Export-ModuleMember -Function DumpMessedUpUserConfig, RemoveSoundsAndConfig, ResetGlobalConfig, UpdateSoundsAndPresets
