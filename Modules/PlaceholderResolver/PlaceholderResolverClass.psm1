
# class PlaceholderResolver {
#     [hashtable]$Replacements

#     PlaceholderResolver([hashtable]$initial = $null) {
#         $this.Replacements = @{}
#         $this.AddEnvVariables()
#         if ($initial) { $this.AddReplacements($initial) }
#     }

#     [void] AddReplacements([hashtable]$newReplacements) {
#         foreach ($key in $newReplacements.Keys) {
#             $this.Replacements[$key] = $newReplacements[$key]
#         }
#     }

#     [void] AddEnvVariables() {
#         foreach ($envVar in [System.Environment]::GetEnvironmentVariables().Keys) {
#             $this.Replacements["`$env:$envVar"] = [System.Environment]::GetEnvironmentVariable($envVar)
#         }
#     }

#     [object] Resolve([object]$input) {
#         if ($input -is [string]) {
#             return $this.ResolveString($input)
#         }
#         elseif ($input -is [hashtable]) {
#             $new = @{}
#             foreach ($k in $input.Keys) {
#                 $new[$k] = $this.Resolve($input[$k])
#             }
#             return $new
#         }
#         elseif ($input -is [System.Collections.IEnumerable] -and !($input -is [string])) {
#             return @($input | ForEach-Object { $this.Resolve($_) })
#         }
#         else {
#             return $input
#         }
#     }

#     [string] ResolveString([string]$text) {
#         foreach ($key in $this.Replacements.Keys) {
#             $escapedKey = [regex]::Escape($key)
#             $value = [string]$this.Replacements[$key]
#             $text = $text -replace $escapedKey, [System.Text.RegularExpressions.Regex]::Escape($value)
#         }
#         return $text -replace '\\E', '' # fallback cleanup
#     }
# }
