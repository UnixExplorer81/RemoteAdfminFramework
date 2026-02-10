Import-Module "CredentialManager"

$cred = Get-Credential
$key = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID

Save-Credential -Credential $cred -Key $key -Path "$PSScriptRoot\Credential.xml"
