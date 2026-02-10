function ADUserSync {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory)][object[]]$Users,
        [Parameter(Mandatory)][string]$Domain,
        [Parameter(Mandatory)][string]$Controller,
        [Parameter(Mandatory)][string]$ProfileBaseDir,
        [Parameter(Mandatory)][string]$UserGroupContainer,
        [Parameter(Mandatory)][string]$AdminGroupContainer,
        [Parameter(Mandatory)][string]$AdminSecurityGroup,
        [Parameter(Mandatory)][string[]]$GroupFilter
    )

    try {
        if(!$GroupFilter.Count) {
            throw "Parameter -GroupFilter has to contain at least one user group name."
        }

        if ($Users -is [string]) {
            $Users = $Users | ConvertFrom-Json
        }
    
        # Falls nur ein einzelnes Objekt kommt, als Array behandeln
        if (-not ($Users -is [object[]])) {
            $Users = @($Users)
        }
    
        if (-not ($Users -is [object[]])) {
            throw "Parameter 'Users' must be of type object[] or a JSON string, but is $($Users.GetType().FullName) instead."
        }
    } catch {
        throw "Fatal error: $($_.Exception.Message)"
    }

    $Users = $Users | Where-Object {
        $GroupFilter -contains $_.'User group'
    }

    # Hash für Vergleich
    $desired = @{}
    foreach ($u in $Users) {
        $key = "$($u.'Login name')|$($u.Displayname)"
        $desired[$key] = $u
    }

    # Ergebnis-Listen für Report
    $reportCreate = @()
    $reportDelete = @()

    # --- EXISTIERENDE ACCOUNTS ERMITTELN ---
    $ouFilter = $GroupFilter | ForEach-Object {
        $group = if ($_ -eq 'Admin') { $AdminSecurityGroup } else { $_ }
        $container = if ($_ -eq 'Admin') { $AdminGroupContainer } else { $UserGroupContainer }
        "CN=$group,CN=$container,$Controller"
    }

    # Hole alle Mitglieder dieser Gruppen:
    $groupMembers = foreach ($groupDN in $ouFilter) {
        Get-ADGroupMember -Identity $groupDN -Recursive | Where-Object { $_.objectClass -eq 'user' }
    }
   
    $allADUsers = $groupMembers | ForEach-Object {
        Get-ADUser -Identity $_.SamAccountName -Properties DisplayName, ProfilePath
    } | Sort-Object SamAccountName -Unique

    foreach ($ad in $allADUsers) {
        $key = "$($ad.SamAccountName)|$($ad.DisplayName)"
        if (-not $desired.ContainsKey($key)) {
            $reportDelete += [PSCustomObject]@{
                Action       = "Delete"
                LoginName    = $ad.SamAccountName
                DisplayName  = $ad.DisplayName
                ProfilePath  = $ad.ProfilePath
            }

            if ($PSCmdlet.ShouldProcess($(if($ad.DisplayName){$ad.DisplayName}else{$ad.SamAccountName}), "Remove AD user")) {
                Write-Host "Deleting AD user: $($ad.SamAccountName) ($($ad.DisplayName))"
                Remove-ADUser -Identity $ad -Confirm:$false

                if ($ad.ProfilePath) {
                    foreach ($suffix in @('', '.V2', '.V3', '.V4', '.V5', '.V6', '.V7', '.V8', '.V9', '.V10')) {
                        if (Test-Path $ad.ProfilePath+$suffix) {
                            Remove-Item -Path $ad.ProfilePath+$suffix -Recurse -Force
                        }
                    }                    
                }
            }
        }
    }

    # --- NEUE ACCOUNTS ANLEGEN ---
    foreach ($u in $Users) {
        $login = $u.'Login name'
        $DisplayName  = $u.Displayname

        $exists = Get-ADUser -Filter { SamAccountName -eq $login } -ErrorAction SilentlyContinue
        if (-not $exists) {
            $ouGroup    = $u.'User group'
            $group      = if ($ouGroup -eq 'Admin') { $AdminSecurityGroup } else { $ouGroup }
            $container  = if ($ouGroup -eq 'Admin') { $AdminGroupContainer } else { $UserGroupContainer }
            $ou         = "OU=$ouGroup,$Controller"
            $groupDN    = "CN=$group,CN=$container,$Controller"
            $profile    = Join-Path $ProfileBaseDir "$ouGroup\$login"

            $reportCreate += [PSCustomObject]@{
                Action      = "Create"
                LoginName   = $login
                DisplayName = $DisplayName
                OU          = $ou
                Group       = $group
            }

            if ($PSCmdlet.ShouldProcess($(if($DisplayName){$DisplayName}else{$login}), "Create AD user")) {
                Write-Host "Creating user: $login ($DisplayName)"
                New-ADUser `
                    -Name                $login `
                    -SamAccountName      $login `
                    -UserPrincipalName   "$login@$Domain" `
                    -GivenName           $u.Firstname `
                    -Surname             $u.Lastname `
                    -DisplayName         $DisplayName `
                    -Path                $ou `
                    -AccountPassword     (ConvertTo-SecureString $u.Password -AsPlainText -Force) `
                    -Enabled             ($u.Disabled -eq 'no') `
                    -ChangePasswordAtLogon ($u.'Must change Pw' -eq 'yes') `
                    -PasswordNeverExpires ($u.'Pw never expires' -eq 'yes') `
                    -CannotChangePassword ($u.'Can change Pw' -eq 'no') `
                    -ProfilePath         $profile

                Add-ADGroupMember -Identity $groupDN -Members $login
            }
        }
    }

    # --- REPORT AUSGEBEN ---
    if ($WhatIfPreference) {
        Write-Host "`n=== WHAT-IF DIFF REPORT ===" -ForegroundColor Yellow
        if ($reportDelete.Count -gt 0) {
            Write-Host "`n--- Would Delete ---" -ForegroundColor Red
            $reportDelete | Format-Table -AutoSize
        } else {
            Write-Host "`n(No deletions planned)" -ForegroundColor DarkGray
        }

        if ($reportCreate.Count -gt 0) {
            Write-Host "`n--- Would Create ---" -ForegroundColor Green
            $reportCreate | Format-Table -AutoSize
        } else {
            Write-Host "`n(No creations planned)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "`nSync operation completed."
    }
}