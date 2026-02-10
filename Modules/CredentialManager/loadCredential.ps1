Import-Module "CredentialManager"

$key = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
$cred = Load-Credential -Path "$PSScriptRoot\Credential.xml" -Key $key

Invoke-Command -ComputerName 192.168.1.11 -Credential $cred -ScriptBlock {
    whoami
}
