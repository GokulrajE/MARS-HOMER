param([Parameter(Mandatory=$true)][string]$GodotExecutable,
      [string]$OutputDirectory)
$ErrorActionPreference='Stop'
$projectDirectory=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $OutputDirectory) { $OutputDirectory=Join-Path $projectDirectory '../dist/MARS_HOMER' }
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$pack=Join-Path $OutputDirectory 'MARS_HOMER.pck'
& $GodotExecutable --headless --path $projectDirectory --export-pack Windows $pack
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $pack)) { throw 'Godot pack export failed.' }
# A matching engine binary plus the project pack is a portable distribution.
# Prefer the non-console executable from the same official Godot release.
$runtime=$GodotExecutable.Replace('_console.exe','.exe')
if (-not (Test-Path -LiteralPath $runtime)) { $runtime=$GodotExecutable }
Copy-Item -LiteralPath $runtime -Destination (Join-Path $OutputDirectory 'MARS_HOMER.exe') -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory 'README.md') -Destination (Join-Path $OutputDirectory 'README.md') -Force
Write-Output "Portable build: $OutputDirectory"
