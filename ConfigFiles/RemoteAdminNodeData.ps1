return [ordered]@{
    "Sound Settings" = [ordered]@{
        "Reset VoiceMeter" = @(
            "Apply this to restore the desired default settings. This will restart VoiceMeter.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure()
            # usw.
        )
        "Reset sound settings" = @(
            "Apply this to set VoiceMeter as default devices.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure()
            # usw.
        )
    }

    "Soundboard fixes" = [ordered]@{
        "Restart Soundboard" = @(
            "Apply this if the soundboard doesn't play on keys press, but on double-clicking recordings.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure(), @{
                Name = "ExitDcsb"
                DisplayName = "Terminate Soundboard"
                Description = "Exiting the Soundboard"
                Script = {
                    param($Context)
                    & $Context.DI.ImportModule 'RemoteDesktopProcess'
                    StopRemoteDesktopProcess -Session $Context.Session -Path $Context.Config.DcsbPath
                }
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
            } 
        )

        "Reset messed up users config.xml" = @(
            "Apply, if sounds are missing or there are no sounds. This will restart the soundboard.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure(), @{
                Name = "ExitDcsb"
                DisplayName = "Exit Soundboard"
                Description = "Exiting Soundboard in order to apply fixes"
                Script = {
                    param($Context)
                    & $Context.DI.ImportModule 'RemoteDesktopProcess'
                    StopRemoteDesktopProcess -Session $Context.Session -Path $Context.Config.DcsbPath
                }
                AffectsProgress = $true
            }, @{
                Name = "DumpMessedUpUserConfig"
                DisplayName = "Delete current users Soundboard config"
                Description = "Deleting the current users inconsistent Soundboard config file"
                Script = {
                    param($Context)
                    DumpMessedUpUserConfig -Context $Context
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
            }
        )

        "Reset messed up global config.xml" = @(
            "Apply, if the previous option didnt fix the issue. This will restart the soundboard.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure(), @{
                Name = "ExitDcsb"
                DisplayName = "Exit Soundboard"
                Description = "Exiting Soundboard in order to apply fixes"
                Script = {
                    param($Context)
                    & $Context.DI.ImportModule 'RemoteDesktopProcess'
                    StopRemoteDesktopProcess -Session $Context.Session -Path $Context.Config.DcsbPath
                }
                AffectsProgress = $true
            }, @{
                Name = "ResetGlobalConfig"
                DisplayName = "Reset global Soundboard config"
                Description = "Resetting the global inconsistent Soundboard config file"
                Script = {
                    param($Context)
                    & $Context.DI.ImportModule 'DcsbFixes'
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
                    param($Context)
                    DumpMessedUpUserConfig -Context $Context
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
            } 
        )

        "Update soundboard configuration & restart" = @(
            "Apply this if all other options don't help.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure(), @{
                Name = "ExitDcsb"
                DisplayName = "Exit Soundboard"
                Description = "Exiting Soundboard in order to apply updates"
                Script = {
                    param($Context)
                    & $Context.DI.ImportModule 'RemoteDesktopProcess'
                    StopRemoteDesktopProcess -Session $Context.Session -Path $Context.Config.DcsbPath
                }
                AffectsProgress = $true
            }, @{
                Name = "UpdateSoundsAndPresets"
                DisplayName = "Update sounds and presets"
                Description = "Running the UpdateDeployment to check for divergences to the server"
                Script = {
                    param($Context)
                    & $Context.DI.ImportModule 'DcsbFixes'
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
                RemoteExecution = $true
                AffectsProgress = $true
                WrappedFunction = $true
            }, @{
                Name = "DumpMessedUpUserConfig"
                DisplayName = "Delete current users Soundboard config"
                Description = "Deleting the current users inconsistent Soundboard config file"
                Script = {
                    param($Context)
                    DumpMessedUpUserConfig -Context $Context
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
            }
        )

        "Update soundboard configuration" = @(
            "Updateing the configuration while the soundboard is in use, without restarting.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure(), @{
                Name = "UpdateSoundsAndPresets"
                DisplayName = "Update sounds and presets"
                Description = "Running the UpdateDeployment to check for divergences to the server"
                Script = {
                    param($Context)
                    & $Context.DI.ImportModule 'DcsbFixes'
                    UpdateSoundsAndPresets -Context $Context
                }.GetNewClosure()
                WrappedFunction = $true
                RemoteExecution = $true
                AffectsProgress = $true
            }
        )

        "Remove recordings & configuration" = @(
            "Removes the entire configuration inclusive recordings of all user accounts.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure(), @{
                Name = "ExitDcsb"
                DisplayName = "Exit Soundboard"
                Description = "Exiting Soundboard in order to apply updates"
                Script = {
                    param($Context)
                    & $Context.DI.ImportModule 'RemoteDesktopProcess'
                    StopRemoteDesktopProcess -Session $Context.Session -Path $Context.Config.DcsbPath
                }
                AffectsProgress = $true
            }, @{
                Name = "RemoveSoundsAndConfig"
                DisplayName = "Remove sounds and config"
                Description = "Removing all sound and configuration files"
                Script = {
                    param($Context)
                    & $Context.DI.ImportModule 'DcsbFixes'
                    RemoveSoundsAndConfig -Context $Context
                }.GetNewClosure()
                WrappedFunction = $true
                RemoteExecution = $true
                AffectsProgress = $true
            }
        )
    }

    "Browser tools" = [ordered]@{
        "Reset chrome bookmarks" = @(
            "Apply this if there are any issues with the dialer which don't occur with all accounts / on all stations.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure()
            # usw.
        )
        "Reset chrome cache" = @(
            "Apply this if there are any issues with the dialer which don't occur with all accounts / on all stations.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure()
            # usw.
        )

        "Export chrome browsing history" = @(
            "This extracts and exports the active users' browsing history of the selected stations.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure()
            # usw.
        )
    }

    "Network" = [ordered]@{
        "Disable & enable network adapter" = @(
            "Apply this if Windows displays offline status although the adapter LEDs are blinking.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure()
            # usw.
        )

        "Change gateway priority" = @(
            "This doesn't disconnect the clients.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure()
            # usw.
            
        )

        "Apply DHCP configuration" = @(
            "This will disconnect the selected clients for a few seconds.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure()
            # usw.
        )

        "Edit static configuration" = @(
            "ATTENTION: Selected clients will reconnect, in case you change any IP oder subnetmask.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure(), @{ 
                Name = "ShowNetConfigurator"
                DisplayName = "Shows the network configuration interface"
                Description = "Launching Soundboard after applying fixes"
                Script = {
                    param($Context)
                    & $Context.DI.ImportModule 'NetConfigAssistant'
                    NetConfigAssistant -Context $Context
                }
                AffectsProgress = $true
            }
        )
    }
    
    "GPOs" = [ordered]@{
        "Task scheduler" = @(
            "Scheduler to run specific tasks",
            {
                param($Context)
                TaskScheduler -Context $Context
            }.GetNewClosure()
        )

        "Automatic client registration" = @(
            "Request clients Mac address to register for wake on LAN",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure()
            # usw.
        )

        "Enter MAC addresses manually" = @(
            "Manually register clients for wake on LAN by entering their MAC address",
            {
                param($Context)
                if($null -eq $Context.Memory.RegisterMacAddress -and $null -eq $Context.Memory.RegisterMacAddress.Computer){
                    $Context.Memory.RegisterMacAddress = @{}
                    $Context.Memory.RegisterMacAddress.Computer = @{
                        hostname = Read-Host "Hostname for which to register the MAC address"
                        mac = Read-Host "MAC address"
                    }
                }
                & $Context.DI.ImportModule 'RegisterMacAddress'
                RegisterMacAddress -Context $Context
            }.GetNewClosure()
        )

        "Start up clients" = @(
            "Wake up clients via wake on LAN (Magic Packets)",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure(), @{ 
                Name = "WakeOnLan"
                DisplayName = "Wake client (WoL)"
                Description = "Sending Magic Packet to wake up $($Context.Computer.hostname)"
                Script = {
                    param($Context)
                    & $Context.DI.ImportModule 'WakeOnLan'
                    WakeOnLan -Context $Context
                }
                AffectsProgress = $true
                WrappedFunction = $true
            }
        )

        "Reboot clients" = @(
            "This runs the shutdown command to reboot clients immediatly.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure(), @{
                Name = "ClientShutdown"
                DisplayName = "Client shut down"
                Description = "This runs the shutdown command to reboot clients immediatly"
                Script = { Start-Process -FilePath "shutdown.exe" -ArgumentList "-r -t 0" -NoNewWindow -Wait }
                RemoteExecution = $true
                AffectsProgress = $true
            }, @{
                Name = "JobComplete"
                DisplayName = "Client reboot"
                Description = "Operation completed"
                Script = {
                    param($Context)
                    Write-Host "✅ Done on $($Context.Computer.hostname)"
                }
            }           
        )

        "Shut down clients" = @(
            "This runs the shutdown command to shut down clients immediatly.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure(), @{
                Name = "ClientShutdown"
                DisplayName = "Client shut down"
                Description = "This runs the shutdown command to shut down clients immediatly."
                Script = { Start-Process -FilePath "shutdown.exe" -ArgumentList "-s -t 0" -NoNewWindow -Wait }
                RemoteExecution = $true
                AffectsProgress = $true
            }, @{
                Name = "JobComplete"
                DisplayName = "Client shut down"
                Description = "Operation completed"
                Script = {
                    param($Context)
                    Write-Host "✅ Done on $($Context.Computer.hostname)"
                }
            }           
        )

        "Log off user" = @(
            "This runs the shutdown command to log off the current user.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure(), @{
                Name = "ClientShutdown"
                DisplayName = "Client shut down"
                Description = "This runs the shutdown command to log off the current user."
                Script = { Start-Process -FilePath "shutdown.exe" -ArgumentList "-l" -NoNewWindow -Wait }
                RemoteExecution = $true
                AffectsProgress = $true
            }, @{
                Name = "JobComplete"
                DisplayName = "Logged off user"
                Description = "Operation completed"
                Script = {
                    param($Context)
                    Write-Host "✅ Done on $($Context.Computer.hostname)"
                }
            }           
        )

        "GpUpdate" = @(
            "This applys the GPOs.",
            {
                param($Context)
                StationSelector -Context $Context
            }.GetNewClosure(), @{
                Name = "GpUpdate"
                DisplayName = "GpUpdate execution"
                Description = "This runs the GpUpdate command on all selected stations"
                Script = { Start-Process -FilePath "cmd.exe" -ArgumentList "/c gpupdate" -NoNewWindow -Wait }
                RemoteExecution = $true
                AffectsProgress = $true
            }, @{
                Name = "JobComplete"
                DisplayName = "GpUpdate"
                Description = "GpUpdate executed"
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
                StationSelector -Context $Context
            }.GetNewClosure(), @{
                Name = "GpUpdateForce"
                DisplayName = "GpUpdate /force execution"
                Description = "This runs the GpUpdate /force command on all selected stations"
                Script = { Start-Process -FilePath "cmd.exe" -ArgumentList "/c gpupdate /force" -NoNewWindow -Wait }
                RemoteExecution = $true
                AffectsProgress = $true
            }, @{
                Name = "JobComplete"
                DisplayName = "GpUpdate force"
                Description = "GpUpdate /force executed"
                Script = {
                    param($Context)
                    Write-Host "✅ Done on $($Context.Computer.hostname)"
                }
            }           
        )
        
        "Module deployment" = @(
            "Physical module deployment of specific PowerShell modules on remote clients",
            {
                param($Context)
                if($null -eq $Context.Memory.RemoteModuleDeployment -and $null -eq $Context.Memory.RemoteModuleDeployment.Installable){
                    $Context.Memory.RemoteModuleDeployment = @{}
                    $Installable = Read-Host "Comma separated list of PsRegistryConfig records"
                    $Context.Memory.RemoteModuleDeployment.Installable = $Installable -split ',' | ForEach-Object { $_.Trim() }
                }
                StationSelector -Context $Context
            }.GetNewClosure(), @{
                Name = "RemoteModuleDeployment"
                DisplayName = "Install/update modules"
                Description = "Installing/updating modules on remote clients"
                Script = {
                    param($Context)
                    & $Context.DI.ImportModule 'RemoteModuleDeployment'
                    RemoteModuleDeployment -Context $Context -Installable $Context.Memory.RemoteModuleDeployment.Installable
                }.GetNewClosure()
                AffectsProgress = $true
                RemoteExecution = $true
                WrappedFunction = $true
                RenewSession = $true
            }
        )
    }

    "Account operations" = [ordered]@{
        "Username change" = @(
            "To change the username of a specific user on selected stations",
            {
                param($Context)
                StationSelector -Context $Context
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
                StationSelector -Context $Context
            }.GetNewClosure(), @{
                Name = "Password change"
                DisplayName = "Password change for the specified user"
                Description = "Changes password for the specified user on selected stations"
                Script = {
                    param($Context)
                    & $Context.DI.ImportModule 'ChangePassword'
                    ChangePassword -Username $Context.Memory.ChangePassword.Username -Password $Context.Memory.ChangePassword.Password
                }
                WrappedFunction = $true
                RemoteExecution = $true
                AffectsProgress = $true
            }          
        )
    }
}