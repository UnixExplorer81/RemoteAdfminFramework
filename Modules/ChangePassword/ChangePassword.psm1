function ChangePassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Username,
        [Parameter(Mandatory)][SecureString]$Password
    )
    $scriptBlock = {
        param($Context)
        try {
            $user = Get-LocalUser -Name $Context.Username -ErrorAction SilentlyContinue
            if (-not $user) { throw "User not found" }
            Set-LocalUser -Name $user.Name -Password $Context.Password -ErrorAction Stop
            $message = "Password changed for $($user.Name)"
            # Write-Host $message -ForegroundColor Green
            return @{
                Success = $true
                Message = $message
            }
        } catch {
            $message = "Failed to change password for $($Context.Username): $($_.Exception.Message)"
            # Write-Error $message
            return @{
                Success = $false
                Message = $message
            }
        }
    }.GetNewClosure()
    return @{
        ScriptBlock = $scriptBlock
        ArgumentList = @(@{
            Username = $Username
            Password = $Password
        })
    }
}
