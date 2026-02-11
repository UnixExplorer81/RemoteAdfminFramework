using module StationSelector
return [ordered]@{
    "Sound" = [ordered]@{
        "Reset VoiceMeter" = @(
            "Apply this to restore the desired default settings. This will restart VoiceMeter.",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure()
        )
        "Reset sound settings" = @(
            "Apply this to set VoiceMeter as default devices.",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure()
        )
    }

    "Soundboard" = [ordered]@{
        "Restart (if hotkey recognition fails)" = @(
            "Apply this if the soundboard doesn't react on keys, but on double-clicking presets.",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure(), @{
                Name = "ExitDcsb"
                DisplayName = "Terminate Soundboard"
                Description = "Exiting the Soundboard"
                Script = {
                    param($Context)
                    Import-Module RemoteDesktopProcess
                    StopRemoteDesktopProcess -Session $Context.Session -Path $Context.Config.DcsbPath
                }
                AffectsProgress = $true
            }, @{
                Name = "RunDcsb"
                DisplayName = "Launch Soundboard"
                Description = "Launching Soundboard after applying fixes"
                Script = {
                    param($Context)
                    Import-Module RemoteDesktopProcess
                    StartRemoteDesktopProcess -Session $Context.Session -Path $Context.Config.DcsbPath
                }
                AffectsProgress = $true
            }, @{
                Name = "JobComplete"
                DisplayName = "Dcsb Fix"
                Description = "Operation completed"
                Script = {
                    param($Context)
                    Write-Host "✅ Done on $($Context.Computer.hostname)"
                }
            }  
        )

        "Reset messed up users config.xml" = @(
            "Apply, if sounds are missing or there are no sounds. This will restart the soundboard.",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure(), @{
                Name = "DependencyCollector"
                DisplayName = "Dependency Collector"
                Description = "Collects module dependencies for all tasks of this job"
                Script = {
                    param($Context)
                    Import-Module DependencyCollector
                    DependencyCollector -Context $Context -JobDependencies @('DcsbFixes','DetectModulesBasePath','UserProfileUtilities','RemoteDesktopProcess')
                }.GetNewClosure()
                AffectsProgress = $true
                WrappedFunction = $true
            }, @{
                Name = "ExitDcsb"
                DisplayName = "Exit Soundboard"
                Description = "Exiting Soundboard in order to apply fixes"
                Script = {
                    param($Context)
                    StopRemoteDesktopProcess -Session $Context.Session -Path $Context.Config.DcsbPath
                }
                AffectsProgress = $true
            }, @{
                Name = "DumpMessedUpUserConfig"
                DisplayName = "Delete current users Soundboard config"
                Description = "Deleting the current users inconsistent Soundboard config file"
                Script = {
                    DumpMessedUpUserConfig
                }
                WrappedFunction = $true
                RemoteExecution = $true
                AffectsProgress = $true
            }, @{
                Name = "RunDcsb"
                DisplayName = "Launch Soundboard"
                Description = "Launching Soundboard after applying fixes"
                Script = {
                    param($Context)
                    StartRemoteDesktopProcess -Session $Context.Session -Path $Context.Config.DcsbPath
                }
                AffectsProgress = $true
            }, @{
                Name = "JobComplete"
                DisplayName = "Dcsb Fix"
                Description = "Operation completed"
                Script = {
                    param($Context)
                    Write-Host "✅ Done on $($Context.Computer.hostname)"
                }
            }  
        )

        "Reset messed up global config.xml" = @(
            "Apply, if the previous option didnt fix the issue. This will restart the soundboard.",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure(), @{
                Name = "DependencyCollector"
                DisplayName = "Dependency Collector"
                Description = "Collects module dependencies for all tasks of this job"
                Script = {
                    param($Context)
                    Import-Module DependencyCollector
                    DependencyCollector -Context $Context -JobDependencies @('DcsbFixes','RemoteDesktopProcess')
                }.GetNewClosure()
                AffectsProgress = $true
                WrappedFunction = $true
            }, @{
                Name = "ExitDcsb"
                DisplayName = "Exit Soundboard"
                Description = "Exiting Soundboard in order to apply fixes"
                Script = {
                    param($Context)
                    StopRemoteDesktopProcess -Session $Context.Session -Path $Context.Config.DcsbPath
                }
                AffectsProgress = $true
            }, @{
                Name = "ResetGlobalConfig"
                DisplayName = "Reset global Soundboard config"
                Description = "Resetting the global inconsistent Soundboard config file"
                Script = {
                    ResetGlobalConfig
                }
                WrappedFunction = $true
                RemoteExecution = $true
                AffectsProgress = $true
            }, @{
                Name = "DumpMessedUpUserConfig"
                DisplayName = "Delete current users Soundboard config"
                Description = "Deleting the current users inconsistent Soundboard config file"
                Script = {
                    DumpMessedUpUserConfig
                }
                WrappedFunction = $true
                RemoteExecution = $true
                AffectsProgress = $true
            }, @{ 
                Name = "RunDcsb"
                DisplayName = "Launch Soundboard"
                Description = "Launching Soundboard after applying fixes"
                Script = {
                    param($Context)
                    StartRemoteDesktopProcess -Session $Context.Session -Path $Context.Config.DcsbPath
                }
                AffectsProgress = $true
            }, @{
                Name = "JobComplete"
                DisplayName = "Dcsb Fix"
                Description = "Operation completed"
                Script = {
                    param($Context)
                    Write-Host "✅ Done on $($Context.Computer.hostname)"
                }
            }  
        )

        "Update soundboard configuration & restart" = @(
            "Apply this if all other options don't help. This will restart the soundboard.",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure(), @{
                Name = "DependencyCollector"
                DisplayName = "Dependency Collector"
                Description = "Collects module dependencies for all tasks of this job"
                Script = {
                    param($Context)
                    Import-Module DependencyCollector
                    DependencyCollector -Context $Context -JobDependencies @('CredentialInjector','CredentialManager','DcsbFixes','RemoteDesktopProcess')
                }.GetNewClosure()
                AffectsProgress = $true
                WrappedFunction = $true
            }, @{
                Name = "ExitDcsb"
                DisplayName = "Exit Soundboard"
                Description = "Exiting Soundboard in order to apply updates"
                Script = {
                    param($Context)
                    StopRemoteDesktopProcess -Session $Context.Session -Path $Context.Config.DcsbPath
                }
                AffectsProgress = $true
            }, @{
                Name = "UpdateSoundsAndPresets"
                DisplayName = "Update sounds and presets"
                Description = "Running the UpdateDeployment to check for divergences to the server"
                Script = {
                    param($Context)
                    UpdateSoundsAndPresets -Context $Context
                }.GetNewClosure()
                WrappedFunction = $true
                RemoteExecution = $true
                AffectsProgress = $true
            }, @{
                Name = "ResetGlobalConfig"
                DisplayName = "Resets global Soundboard config"
                Description = "Resetting the global inconsistent Soundboard config file"
                Script = {
                    ResetGlobalConfig
                }
                WrappedFunction = $true
                RemoteExecution = $true
                AffectsProgress = $true
            }, @{
                Name = "DumpMessedUpUserConfig"
                DisplayName = "Delete current users Soundboard config"
                Description = "Deleting the current users inconsistent Soundboard config file"
                Script = {
                    DumpMessedUpUserConfig
                }
                WrappedFunction = $true
                RemoteExecution = $true
                AffectsProgress = $true
            }, @{ 
                Name = "RunDcsb"
                DisplayName = "Launch Soundboard"
                Description = "Launching Soundboard after applying fixes"
                Script = {
                    param($Context)
                    StartRemoteDesktopProcess -Session $Context.Session -Path $Context.Config.DcsbPath
                }
                AffectsProgress = $true
            }, @{
                Name = "JobComplete"
                DisplayName = "Dcsb Fix"
                Description = "Operation completed"
                Script = {
                    param($Context)
                    Write-Host "✅ Done on $($Context.Computer.hostname)"
                }
            }
        )

        "Update soundboard configuration" = @(
            "Updateing the configuration while the soundboard is in use, without restarting.",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure(), @{
                Name = "UpdateSoundsAndPresets"
                DisplayName = "Update sounds and presets"
                Description = "Running the UpdateDeployment to check for divergences to the server"
                Script = {
                    param($Context)
                    Import-Module DcsbFixes
                    UpdateSoundsAndPresets -Context $Context
                }.GetNewClosure()
                WrappedFunction = $true
                RemoteExecution = $true
                AffectsProgress = $true
            }, @{
                Name = "JobComplete"
                DisplayName = "Dcsb Fix"
                Description = "Operation completed"
                Script = {
                    param($Context)
                    Write-Host "✅ Done on $($Context.Computer.hostname)"
                }
            }
        )

        "Remove sounds & configuration" = @(
            "Removes sounds and configuration files in all user accounts.",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure(), @{
                Name = "DependencyCollector"
                DisplayName = "Dependency Collector"
                Description = "Collects module dependencies for all tasks of this job"
                Script = {
                    param($Context)
                    Import-Module DependencyCollector
                    DependencyCollector -Context $Context -JobDependencies @('RemoteDesktopProcess','DcsbFixes')
                }.GetNewClosure()
                AffectsProgress = $true
                WrappedFunction = $true
            }, @{
                Name = "ExitDcsb"
                DisplayName = "Exit Soundboard"
                Description = "Exiting Soundboard in order to apply updates"
                Script = {
                    param($Context)
                    StopRemoteDesktopProcess -Session $Context.Session -Path $Context.Config.DcsbPath
                }
                AffectsProgress = $true
            }, @{
                Name = "RemoveSoundsAndConfig"
                DisplayName = "Remove sounds and config"
                Description = "Removing all sound and configuration files"
                Script = {
                    param($Context)
                    RemoveSoundsAndConfig -Context $Context
                }.GetNewClosure()
                WrappedFunction = $true
                RemoteExecution = $true
                AffectsProgress = $true
            }, @{
                Name = "JobComplete"
                DisplayName = "Dcsb Cleanup"
                Description = "Operation completed"
                Script = {
                    param($Context)
                    Write-Host "✅ Done on $($Context.Computer.hostname)"
                }
            }
        )
    }

    "Browser" = [ordered]@{
        "Reset browser cache" = @(
            "Apply this if there are any issues with the dialer which don't occur with all accounts / on all stations.",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure()
        )

        "Export browser history" = @(
            "This extracts and exports the active users' browsing history of the selected stations.",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure()
        )
    }

    "Network" = [ordered]@{
        "Disable & Enable adapter" = @(
            "Apply this if Windows displays offline status although the adapter LEDs are blinking.",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure()
        )

        "Change gateway priority" = @(
            "This doesn't disconnect the clients.",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure()
            
        )

        "Apply DHCP configuration" = @(
            "This will disconnect the selected clients for a few seconds.",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure()
        )

        "Edit static configuration" = @(
            "ATTENTION: Selected clients will reconnect, in case you change any IP oder subnetmask.",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure(), @{
                Name = "RemoteModuleDeployment"
                DisplayName = "Install/update modules"
                Description = "Checking and installing the required modules on the selected stations, if missing"
                Script = {
                    param($Context)
                    Import-Module RemoteModuleDeployment
                    RemoteModuleDeployment -Context $Context -TaskRequires @('CredentialManager','NetUseAuthentification','UpdateDeployment','UserProfileUtilities')
                }.GetNewClosure()
                WrappedFunction = $true
                RemoteExecution = $true
                AffectsProgress = $true
                RenewSession = $true
            }, @{ 
                Name = "ShowNetConfigurator"
                DisplayName = "Shows the network configuration interface"
                Description = "Launching Soundboard after applying fixes"
                Script = {
                    param($Context)
                    Import-Module NetConfigAssistant
                    ShowNetConfigAssistant -Context $Context
                }
                AffectsProgress = $true
            }, @{
                Name = "JobComplete"
                DisplayName = "Dcsb Fix"
                Description = "Operation completed"
                Script = {
                    param($Context)
                    Write-Host "✅ Done on $($Context.Computer.hostname)"
                }
            }
        )

        "Automatic Mac address registration for WoL" = @(
            "Request clients Mac address to register for wake on LAN",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure()
        )

        "Manually enter Mac addresses" = @(
            "Manually register clients for wake on LAN by entering their Mac address",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure()
        )

        "Wake up clients (WoL)" = @(
            "Wake up clients by wake on LAN / Magic Packages",
            {
                param($Context)
                InitStationSelectMenu -Context $Context
            }.GetNewClosure(), @{ 
                Name = "WakeOnLan"
                DisplayName = "Wake client (WoL)"
                Description = "Sending Magic Packet to wake up $($Context.Computer.hostname)"
                Script = {
                    param($Context)
                    Import-Module WakeOnLan
                    WakeOnLan -Context $Context
                }
                AffectsProgress = $true
                WrappedFunction = $true
            }, @{
                Name = "JobComplete"
                DisplayName = "Magic packet sent"
                Description = "Operation completed"
                Script = {
                    param($Context)
                    Write-Host "✅ Done on $($Context.Computer.hostname)"
                }
            }
        )
    }
    
    "GPOs" = [ordered]@{
        "GpUpdate" = @(
            "This applys the GPOs.",
            {
                param($Context)
                Import-Module StationSelector
                InitStationSelectMenu -Context $Context
            }.GetNewClosure(), @{
                Name = "GpUpdate"
                DisplayName = "GpUpdate execution"
                Description = "This runs the GpUpdate command on all selected stations"
                Script = { Start-Process -FilePath "cmd.exe" -ArgumentList "/c gpupdate" -NoNewWindow -Wait }
                WrappedFunction = $true
                RemoteExecution = $true
                AffectsProgress = $true
            }, @{
                Name = "JobComplete"
                DisplayName = "Dcsb Fix"
                Description = "Operation completed"
                Script = {
                    param($Context)
                    Write-Host "✅ Done on $($Context.Computer.hostname)"
                }
            }           
        )

        "GpUpdate /force" = @(
            "This applys the GPOs. ATTENTION: Clients might restart without asking for confirmation!",
            {
                param($Context)
                Import-Module StationSelector
                InitStationSelectMenu -Context $Context
            }.GetNewClosure(), @{
                Name = "GpUpdateForce"
                DisplayName = "GpUpdate /force execution"
                Description = "This runs the GpUpdate /force command on all selected stations"
                Script = { Start-Process -FilePath "cmd.exe" -ArgumentList "/c gpupdate /force" -NoNewWindow -Wait }
                WrappedFunction = $true
                RemoteExecution = $true
                AffectsProgress = $true
            }, @{
                Name = "JobComplete"
                DisplayName = "Dcsb Fix"
                Description = "Operation completed"
                Script = {
                    param($Context)
                    Write-Host "✅ Done on $($Context.Computer.hostname)"
                }
            }           
        )
    }

    "Account operations" = [ordered]@{
        "Username change" = @(
            "To change the username of a specific user on selected stations",
            {
                param($Context)
                Import-Module StationSelector
                InitStationSelectMenu -Context $Context
            }.GetNewClosure()
            # usw.
        )
        
        "Password change" = @(
            "To change the password of a specific user",
            {
                param($Context)
                    if($null -eq $Context.Memory.ChangePassword){
                    $Context.Memory.ChangePassword = @{
                        Username = Read-Host "User whose password to change"
                        Password = Read-Host "New Password" -AsSecureString
                    }
                }
                Import-Module StationSelector
                InitStationSelectMenu -Context $Context
            }.GetNewClosure(), @{
                Name = "Password change"
                DisplayName = "Password change for the specified user"
                Description = "Changes password for the specified user on selected stations"
                Script = {
                    param($Context)
                    Import-Module ChangePassword
                    ChangePassword -Username $Context.Memory.ChangePassword.Username -Password $Context.Memory.ChangePassword.Password
                }
                WrappedFunction = $true
                RemoteExecution = $true
                AffectsProgress = $true
            }, @{
                Name = "JobComplete"
                DisplayName = "Password change"
                Description = "Operation completed"
                Script = {
                    param($Context)
                    Write-Host "✅ Done on $($Context.Computer.hostname)"
                }
            }           
        )
    }
}