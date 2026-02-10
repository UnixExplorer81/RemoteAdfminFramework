function CredentialManager {
    param (
        [Parameter(Mandatory)][string]$Key,
        [string]$DefaultUser,
        [string]$Path = (Join-Path $env:USERPROFILE "AppData\Local\PowerShell\CredentialManager\credential.xml"),
        [string]$XmlString
    )
    if ($XmlString) {
        return LoadCredentialFromXmlString -XmlString $XmlString -Key $Key
    }
    if (Test-Path $Path) {
        try {
            return LoadCredentialFromFile -Path $Path -Key $Key
        } catch {
            try {
                $raw = Import-Clixml -Path $Path
                $storedUser = $null
                if ($raw -and $raw.ContainsKey('Username')) { $storedUser = $raw.Username }
                if (-not $storedUser -and $raw -is [System.Collections.Hashtable] -and $raw.Values) {
                    $storedUser = $raw['Username']
                }
            } catch {
                $storedUser = if($DefaultUser){$DefaultUser}else{$null}
            }
            if ($storedUser) {
                $msg = "Enter password for user $storedUser."
                $cred = Get-Credential -UserName $storedUser -Message $msg
            } else {
                $cred = Get-Credential -Message "Enter credential for an authorized user."
            }
            try { SaveCredentialToFile -Credential $cred -Key $Key -Path $Path } catch { Write-Warning "Failed to save credential: $_" }
            return $cred
        }
    }
    $cred = Get-Credential("Administrator")
    SaveCredentialToFile -Credential $cred -Key $Key -Path $Path
    return $cred
}

function SaveCredentialToFile {
    param (
        [Parameter(Mandatory)][PSCredential]$Credential,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Path
    )
    $entropy = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Key))
    $securePassword = $Credential.Password | ConvertFrom-SecureString -Key $entropy
    $data = @{
        Username = $Credential.UserName
        Password = $securePassword
    }
    $data | Export-Clixml -Path $Path
}

function LoadCredentialFromFile {
    param (
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Path
    )
    $entropy = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Key))
    $data = Import-Clixml -Path $Path
    $securePassword = $data.Password | ConvertTo-SecureString -Key $entropy
    return New-Object System.Management.Automation.PSCredential($data.Username, $securePassword)
}

function LoadCredentialFromXmlString {
    param (
        [Parameter(Mandatory)][string]$XmlString,
        [Parameter(Mandatory)][string]$Key
    )
    $tempFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tempFile -Value $XmlString -Encoding UTF8
    try {
        $entropy = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Key))
        $data = Import-Clixml -Path $tempFile
        $securePassword = $data.Password | ConvertTo-SecureString -Key $entropy
        return New-Object System.Management.Automation.PSCredential($data.Username, $securePassword)
    } finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}