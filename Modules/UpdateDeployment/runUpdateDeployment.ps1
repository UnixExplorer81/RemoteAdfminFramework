using module UpdateDeployment

$Jobs = @(
    @{
        "\\dc-1\nas\Scripts\PowerShell" = "C:\Windows\System32\WindowsPowerShell\v1.0\Modules"
        files = @{
            "ScriptVersionGuard\ScriptVersionGuard.psm1" = "ScriptVersionGuard\ScriptVersionGuard.psm1"
            "Network\classNetConfigurator.psm1" = "NetConfigurator\NetConfigurator.psm1"
            "Logger\classLogger.psm1" = "Logger\Logger.psm1"
        }
    },
    @{
        "\\dc-1\nas\Profiles\Agents" = "C:\Users\*"
        directories = @{
            "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" = "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
        }
        exceptions = @{
            directories = @("Administrator", "Default")
        }
    },
    @{
        directories = @{
            "\\dc-1\nas\Profiles\Agents\Desktop" = "C:\Users\Public\Desktop"
        }
        deletes = @(
            "c:\users\*\Desktop\*.html"
            "c:\users\*\Desktop\*.lnk"
            "c:\users\*\Desktop\*.url"
            "c:\users\*\Desktop\*.jpg"
            "c:\users\*\Desktop\*.png"
            "c:\users\*\Desktop\*.gif"
            "c:\users\*\Desktop\*.svg"
            "c:\users\*\Desktop\New *"
        )
    },
    @{
        "\\dc-1\nas\Profiles\Agents" = "C:\ProgramData"
        directories = @{
            "DCSB Nuspray" = "DCSB"
        }
<#
        deletes = @("DCSB\*") // tidy up rule if configuration got changed significent
#>
    },
    @{
        deletes = @(
            "C:\Users\*\AppData\Local\VirtualStore\ProgramData\DCSB\*.xml"
            "C:\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\*.lnk"
            "C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\*.lnk"
            "C:\Users\Administrator.*\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\*.lnk"
        )
    }
)

UpdateDeployment -Jobs $Jobs -EnableDebugLogging
