return @{
    CREDENTIALKEY = {
        return (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
    }
    INTERACTIVE = {
        return $Host.Name -eq 'ConsoleHost'
    }
    MODULESBASE = {
        param($Context)
        if (-not (Get-Command DetectModulesBasePath -ErrorAction SilentlyContinue)) {
            Import-Module DetectModulesBasePath -Force
        }
        try {
            return DetectModulesBasePath -GlobalModulePath $Context.Config.GlobalModulePath -UserModulePath $Context.Config.UserModulePath
        } catch {
            throw "Fatal error in PlaceHoldercallbacks->MODULESBASE: Required module DetectModulesBasePath is not available."
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
        param($Context)
        if (-not (Get-Command GetUserProfilePath -ErrorAction SilentlyContinue)) {
            try {
                Import-Module UserProfileUtilities -Force -ErrorAction Stop
            } catch {
                throw "Fatal error in PlaceHolderCallbacks->USERPROFILE: Required module UserProfileUtilities is not available."
            }
        }
        return GetUserProfilePath
    }
    REPOSITORY = {
        param($Context)
        $repos = @()
        foreach ($repo in $Context.Config.Repositories) {
            if ($repo -is [string]) {
                $resolved = $Context.Resolver.ResolveStringPlaceholders($repo, $Context)
                $repos += $resolved
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
        throw "Fatal error in PlaceHolderCallbacks->SERVER: No reachable server found"
    }
    # SERVER = {
    #     param($Context)
    #     foreach ($server in $Context.Config.Servers) {
    #         if (Test-WSMan -ComputerName $server -ErrorAction SilentlyContinue) {
    #             return $server
    #         }
    #     }
    #     throw "Fatal error in PlaceHolderCallbacks->SERVER: No WinRM-reachable server found"
    # }
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