return @{
    CREDENTIALKEY = {
        return (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
    }
    INTERACTIVE = {
        return $Host.Name -eq 'ConsoleHost'
    }
    MODULESBASE = {
        param($Context)
        switch($PSVersionTable.PSVersion.Major){
            5 {
                $GlobalModulePath = $Context.Config.GlobalModulePath.PS5
                $UserModulePath = $Context.Config.UserModulePath.PS5
            }
            7 {
                $GlobalModulePath = $Context.Config.GlobalModulePath.PS7
                $UserModulePath = $Context.Config.UserModulePath.PS7
            }
            default {
                $GlobalModulePath = $Context.Config.GlobalModulePath.PS5
                $UserModulePath = $Context.Config.UserModulePath.PS5
            }
        }
        try {
            $testFile = Join-Path $GlobalModulePath "test_write_access.tmp"
            Set-Content -Path $testFile -Value "test" -Force -ErrorAction Stop
            Remove-Item $testFile -Force -ErrorAction Stop
            return $GlobalModulePath
        } catch {
            return $UserModulePath 
        }
    }
    OFFLINEMODE = {
        param($Context)
        if($Context.Config.BootstrapRoot.Length) {
            return (-not (Test-Path $Context.Config.BootstrapRoot))
        }elseif($BootstrapRoot.Length) {
            return (-not (Test-Path $BootstrapRoot))
        }
    }
    PROGRAMDATA = {
        param($Context)
        return $Context.Config.ProgramData
    }
    PROGRAMDATABASEDIR = {
        param($Context)
        return $Context.Config.ProgramDataBaseDir
    }
    USERPROFILE = {
        try {
            $Username = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
            $shortName = $Username.Split('\')[-1]
            $sid = ([System.Security.Principal.NTAccount]$shortName).Translate([System.Security.Principal.SecurityIdentifier]).Value
            $userprofile = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.SID -eq $sid -and $_.Loaded -and -not $_.Special }
            return $userprofile.LocalPath
        } catch {
            throw "Fatal error in PlaceHolderCallbacks->USERPROFILE: $_"
        }
    }
    REPOSITORY = {
        param($Context)
        $repos = @()
        foreach ($repo in $Context.Config.Repositories) {
            if ($repo -is [string]) {
                $repos += $Context.Resolver.ResolveStringPlaceholders($repo)
            } else {
                $repos += $repo
            }
        }
        foreach ($r in $repos) {
            if (Test-Path $r) { return $r }
        }
        return $repos[0]
    }
    SERVER = {
        param($Context)
        foreach ($server in $Context.Config.Servers) {
            if (Test-Connection -ComputerName $server -Count 1 -Quiet) {
                return $server
            }
        }
    }
    SERVERS = {
        param($key, $Context)
        if ($null -eq $key -or $key -eq '') { return $Context.Config.Servers }
        if ($key -match '^\d+$') {
            $idx = [int]$key
            if ($idx -lt $Context.Config.Servers.Count) { return $Context.Config.Servers[$idx] }
            return $null
        }
        foreach ($s in $Context.Config.Servers) { if ($s -eq $key) { return $s } }
        return $Context.Config.Servers
    }
    TRUSTEDSITE = {
        param($Context)
        return $Context.Config.TrustedSite
    }
}