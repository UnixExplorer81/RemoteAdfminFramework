@{
    BootstrapRoot = "\\topcall.inc\shares\PowerShell_Framework$"
    BroadcastAddress = "192.168.1.255"
    ClientsCredPath = "{{USERPROFILE}}\AppData\Local\PowerShell\CredentialManager\DomainClients.xml"
    Coloring = @{
        Description = "Yellow"
        MenuItem = "Blue"
        Path = "Yellow"
        SelectedItem = "Cyan"
    }
    CredentialKey = "{{CREDENTIALKEY}}"
    CsvDelimiter = ";"
    CsvHeader = @('hostname','ip','mac','cn','dc','controller')
    CsvPath = "{{PROGRAMDATABASEDIR}}\PsRemoteAdminFramework\AiStations.csv"
    DcsbPath = "C:\Program Files (x86)\Deathcounter and Soundboard\DCSB.exe"
    DefaultAdmin = "TOPCALL\Administrator"
    DisplayIndex = $true
    GlobalModulePath = @{
        PS5 = "C:\Program Files\WindowsPowerShell\Modules"
        PS7 = "C:\Program Files\PowerShell\Modules"
    }
    IsInteractive = "{{INTERACTIVE}}"
    LogProgress = "{{PROGRAMDATABASEDIR}}\PsRemoteAdminFramework\Progress.log"
    LogErrors = "{{PROGRAMDATABASEDIR}}\PsRemoteAdminFramework\Error.log"
    MenuName = "Remote Admin Framework"
    NetConfig = "\\{{SERVER}}\NAS\Scripts\PowerShell\ConfigFiles\NetConfig.json"
    OfflineMode = "{{OFFLINEMODE}}"
    Repositories = @("\\{{SERVERS:0}}\nas\Scripts\PowerShell","\\{{SERVERS:1}}\nas\Scripts\PowerShell","\\{{SERVERS:2}}\nas\Scripts\PowerShell")
    ProgramData = "{{PROGRAMDATABASEDIR}}\PsRemoteAdminFramework"
    ProgramDataBaseDir = "C:\ProgramData\PowerShell"
    PsCallbacks = "PsCallbacks.ps1"
    PsRegistryConfig = @{
        source = "{{REPOSITORY}}\ConfigFiles\PsRegistryConfig.psd1"
        target = "{{PROGRAMDATABASEDIR}}\PsRemoteAdminFramework\PsRegistryConfig.psd1"
    }
    Servers = @("dc-1","dc-2","dc-3")
    ServersTest = @(
        @("dc-1","dc-2","dc-3")
        @("dc-4","dc-5","dc-6")
        @("dc-7","dc-8","dc-9")
    )
    TrustedSite = "\\topcall.inc\shares\TrustedSites"
    UserModulePath = @{
        PS5 = "{{USERPROFILE}}\Documents\WindowsPowerShell\Modules"
        PS7 = "{{USERPROFILE}}\Documents\PowerShell\Modules"
    }
    Verbose = $true
    VolatileDI = $false
}