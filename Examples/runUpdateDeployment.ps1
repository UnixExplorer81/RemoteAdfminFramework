Using Module UpdateDeployment

$Config = @{
    GlobalModulePath = @{
        PS5 = "C:\Program Files\WindowsPowerShell\Modules"
        PS7 = "C:\Program Files\PowerShell\7\Modules"
    }
}

switch($PSVersionTable.PSVersion.Major){
    5 {
        $GlobalModulePath = $Config.GlobalModulePath.PS5
    }
    7 {
        $GlobalModulePath = $Config.GlobalModulePath.PS7
    }
    default {
        $GlobalModulePath = $Config.GlobalModulePath.PS5
    }
}

$Jobs = @(
    @{
        "\\topcall.inc\shares\PowerShell_Framework$\Modules" = "$GlobalModulePath"
        files = @{
            "ScriptVersionGuard\ScriptVersionGuard.psm1" = "ScriptVersionGuard\ScriptVersionGuard.psm1"
            "NetConfigurator\NetConfigurator.psm1" = "NetConfigurator\NetConfigurator.psm1"
            "Logger\Logger.psm1" = "Logger\Logger.psm1"
        }
    },
    @{
        "\\topcall.inc\shares\Profile_Update_Repository$\Agents" = "C:\Users\*"
        directories = @{
            "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" = "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
        }
        exceptions = @{
            directories = @("Administrator", "Default")
        }
    },
    @{
        directories = @{
            "\\topcall.inc\shares\Profile_Update_Repository$\Agents\Desktop" = "C:\Users\Public\Desktop"
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
        "\\topcall.inc\shares\Profile_Update_Repository$\Agents" = "C:\ProgramData"
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
