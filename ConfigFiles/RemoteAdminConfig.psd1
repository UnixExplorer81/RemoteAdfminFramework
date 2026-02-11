@{
    BroadcastAddress = "192.168.1.255"
    Subnet = "192.168.1." # in stationselector gegen BroadcastAdresse austauschen
    ClientsCredPath = "{{USERPROFILE}}\AppData\Local\PowerShell\CredentialManager\DomainClients.xml"
    CredentialKey = "{{CREDENTIALKEY}}"
    CsvDelimiter = ";"
    CsvHeader = @('hostname','ip','mac','cn','dc','controller')
    CsvPath = "\\{{SERVER}}\NAS\Scripts\PowerShell\ConfigFiles\AiStations.csv"
    DcsbPath = "C:\Program Files (x86)\Deathcounter and Soundboard\DCSB.exe"
    DefaultAdmin = "TOPCALL\Administrator"
    DisplayIndex = $true
    GlobalModulePath = "C:\Windows\System32\WindowsPowerShell\v1.0\Modules"
    IsInteractive = "{{INTERACTIVE}}"
    LogProgress = "{{PROGRAMDATABASEDIR}}\RemoteAdminTools\Progress.log"
    LogErrors = "{{PROGRAMDATABASEDIR}}\RemoteAdminTools\Error.log"
    MenuName = "Remote Admin"
    NetConfig = "\\{{SERVER}}\NAS\Scripts\PowerShell\ConfigFiles\NetConfig.json"
    Repositories = @("\\{{SERVERS:0}}\nas\Scripts\PowerShell","\\{{SERVERS:1}}\nas\Scripts\PowerShell","\\{{SERVERS:2}}\nas\Scripts\PowerShell")
    ProgramData = "{{PROGRAMDATABASEDIR}}\RemoteAdminTools"
    ProgramNodes = "NodeData.ps1"
    ProgramDataBaseDir = "C:\ProgramData\PowerShell"
    PsRegistryConfig = @{
        source = "{{REPOSITORY}}\ConfigFiles\PsRegistryConfig.psd1"
        target = "{{PROGRAMDATABASEDIR}}\PsRegistryConfig.psd1"
    }
    Servers = @("dc-1","dc-2","dc-3")
    Coloring = @{
        Path = "Yellow"
        Description = "Yellow"
        MenuItem = "Blue"
        SelectedItem = "Cyan"
    }
    TrustedSite = "\\topcall.inc\shares\TrustedSites"
    UserModulePath =  "{{USERPROFILE}}\Documents\WindowsPowerShell\Modules"
    Verbose = $true
}