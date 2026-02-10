function NetUseAuthentification {
    param(
        [switch]$EnableDebugging,
        [Parameter(Mandatory)][string]$UncPath,
        [Parameter(Mandatory)][System.Management.Automation.PSCredential]$Credential
    )
    $netCred = $Credential.GetNetworkCredential()
    $username = "$($netCred.Domain)\$($netCred.UserName)"
    $password = $netCred.Password

    $netUse = Start-Process -FilePath "net.exe" -ArgumentList @(
        "use", $UncPath, $password, "/user:$username"
    ) -NoNewWindow -Wait -PassThru

    if ($netUse.ExitCode -ne 0) {
        throw "❌ net use command failed with exit code $($netUse.ExitCode)"
    }
}

function NetUseLogouts {
    param(
        [Parameter(Mandatory)][string]$UncPath
    )
    Invoke-Expression "net use $UncPath /delete /y"
}