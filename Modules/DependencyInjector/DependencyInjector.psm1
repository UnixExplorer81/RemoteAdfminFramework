function DependencyInjector {
    param (
        [Parameter(Mandatory)][hashtable]$Context,
        [string[]]$Modules = @(),
        [string[]]$Providers = @()
    )
 
    if(-not $Context.ContainsKey('DI')){
        $Context.DI = @{}
    }
    if(-not $Context.DI.ContainsKey('Modules')){
        $Context.DI.Modules = @{}
    }
    if(-not $Context.DI.ContainsKey('Providers')){
        $Context.DI.Providers = @{}
    }

    $CodeLoader = CodeLoader -Registry $Context.Registry -Cache $Context.DI.Modules -DevMode:$Context.Config.Verbose

    $Modules | ForEach-Object {
        $Context.DI.Modules[$_] = & $CodeLoader -Key $_
    }

    $Providers | ForEach-Object {
        $c = & $CodeLoader -Key $_
        & ([scriptblock]::Create($c))
        $Context.DI.Providers[$_] = & $_ -Context $Context      
    }

    $DependencyProvider = {
        param($Context, $CodeLoader)

        return @{
            GetContent = {
                param([string]$Key)
                try {
                    if (-not $Context.DI.Modules.ContainsKey($Key)) {
                        $Context.DI.Modules[$Key] = & $CodeLoader -Key $Key
                    }
                    return $Context.DI.Modules[$Key]
                } catch {
                    throw "DependencyProvider->GetContent: Fatal error while getting code '$Key': $($_.Exception.Message)", $_.Exception
                }
            }.GetNewClosure()

            ImportModule = {
                param(
                    [string]$Key,
                    [object[]]$ArgumentList = @()
                )
                try {
                    if (-not $Context.DI.Modules.ContainsKey($Key)) {
                        $Context.DI.Modules[$Key] = & $CodeLoader -Key $Key
                    }
                    $c = $Context.DI.Modules[$Key]
                    if ($c -is [string]) {
                        & ([scriptblock]::Create($c)) $ArgumentList
                    } else {
                        throw "Invalid capability type: $($c.GetType().FullName)"
                    }
                } catch {
                    throw "DependencyProvider->ImportModule: Fatal error while importing module '$Key': $($_.Exception.Message)", $_.Exception
                }
            }.GetNewClosure()

            GetProvider = {
                param([string]$Key, $execute = $true)
                try {
                    if (-not $Context.DI.Providers.ContainsKey($Key)) {
                        $c = & $CodeLoader -Key $Key
                        & ([scriptblock]::Create($c))
                        $factoryResult = try {
                            & $Key -Context $Context -ErrorAction Stop
                        } catch [System.Management.Automation.CommandNotFoundException] {
                            throw "Provider '$Key' doesn't define a function named '$Key'. Expected: function $Key { ... }"
                        }
                        if ($factoryResult -isnot [hashtable]) {
                            throw "Factory function '$Key' doesn't return a hashtable"
                        }
                        $Context.DI.Providers[$Key] = $factoryResult
                    }
                    $p = $Context.DI.Providers[$Key]
                    if ($p -is [hashtable] -and $p.ContainsKey('ScriptBlock') -and $p.ContainsKey('ArgumentList')) {
                        if ($p.ScriptBlock -is [string]) {
                            $p.ScriptBlock = [scriptblock]::Create($p.ScriptBlock)
                        }
                        if ($p.ScriptBlock -isnot [scriptblock]) {
                            throw "Invalid scriptblock for $Key"
                        }
                        if($execute) {
                            return & $p.ScriptBlock $p.ArgumentList
                        }
                        return $p
                    } else {
                        throw "Invalid provider type: $($p.GetType().FullName)"
                    }
                } catch {
                    throw "DependencyProvider->GetProvider: Fatal error while invoking provider '$Key': $($_.Exception.Message)", $_.Exception
                }
            }.GetNewClosure()
        }
    }.GetNewClosure()

    return @{
        ScriptBlock = $DependencyProvider
        ArgumentList = @($Context, $CodeLoader)
    }
}
function DependencyProvider {
    param (
        [object]$Context
    )

    return {
        $di = $Context.DependencyInjector
        if ($di.ScriptBlock -is [string]) {
            $di.ScriptBlock = [scriptblock]::Create($di.ScriptBlock)
        }
        $params = $di.ArgumentList
        & $di.ScriptBlock @params
    }.GetNewClosure()
}
function CodeLoader {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Registry,
        [hashtable]$Cache = @{},
        [switch]$DevMode
    )

    return {
        param([string]$Key)

        if (-not $Registry.ContainsKey($Key)) {
            throw "DependencyProvider->CodeLoader: Unknown key '$Key'"
        }
        if (-not $Cache.ContainsKey($Key)) {
            $sourcePath = $Registry[$Key].source
            $localPath = $Registry[$Key].target
            if (-not (Test-Path $sourcePath)) {
                $path = $localPath
                if (-not (Test-Path $localPath)) {
                    throw "DependencyProvider->CodeLoader: All repositories are offline and no local copy exists for '$Key' ($localPath)"
                }
            } else {
                $path = $sourcePath
                if($DevMode -ne $true){
                    $dest = Split-Path $localPath -Parent
                    if (-not (Test-Path $dest)) {
                        New-Item -Path $dest -ItemType Directory -Force | Out-Null
                    }
                    Copy-Item -Path $sourcePath -Destination $localPath -Force
                }
            }
            $c = Get-Content -Path $path -Raw -Encoding UTF8
            $c = $c -replace '(?s)<#.*?#>', ''
            $c = $c -replace '[\uFEFF\u200B\u2060]', ''
            $c = $c -replace '(?mi)^\s*Export-ModuleMember\b.*(?:\r?\n)*', ''

            if ($c -match '^\s*$') {
                throw "DependencyProvider->CodeLoader: File '$path' contains no executable code"
            }

            $Cache[$Key] = $c
        }
        return $Cache[$Key]
    }.GetNewClosure()
}
function Show-ErrorDetails {
    param($ex)
    $ex | Select-Object Message, InnerException, StackTrace
}
Export-ModuleMember -Function DependencyInjector, DependencyProvider