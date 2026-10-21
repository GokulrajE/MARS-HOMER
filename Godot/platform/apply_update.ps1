# Copies a downloaded MARS HOMER update over the install folder, then starts the app again.
# Started by core/updater.gd after the app has quit. Old files are kept in .previous and put
# back if anything fails, so a broken update never leaves the app half-installed.
param([int]$ProcessId, [string]$Stage, [string]$Install, [string]$Exe)
$ErrorActionPreference = 'Stop'
try { Wait-Process -Id $ProcessId -Timeout 60 -ErrorAction SilentlyContinue } catch {}
Start-Sleep -Milliseconds 700
$backup = Join-Path $Install '.previous'
if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
New-Item -ItemType Directory -Force -Path $backup | Out-Null
$stageRoot = $Stage.TrimEnd('\')
$copied = New-Object System.Collections.Generic.List[string]
function Copy-Retry($from, $to) {
    for ($i = 0; $i -lt 20; $i++) {
        try { Copy-Item -LiteralPath $from -Destination $to -Force; return } catch { Start-Sleep -Milliseconds 500 }
    }
    Copy-Item -LiteralPath $from -Destination $to -Force
}
try {
    Get-ChildItem -LiteralPath $Stage -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($stageRoot.Length).TrimStart('\')
        $dest = Join-Path $Install $rel
        if (Test-Path -LiteralPath $dest) {
            $saved = Join-Path $backup $rel
            New-Item -ItemType Directory -Force -Path (Split-Path $saved) | Out-Null
            Copy-Item -LiteralPath $dest -Destination $saved -Force
        }
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        Copy-Retry $_.FullName $dest
        $copied.Add($rel)
    }
} catch {
    # Put every file we touched back the way it was.
    foreach ($rel in $copied) {
        $saved = Join-Path $backup $rel
        $dest = Join-Path $Install $rel
        if (Test-Path -LiteralPath $saved) { Copy-Item -LiteralPath $saved -Destination $dest -Force }
    }
}
Start-Process -FilePath $Exe -WorkingDirectory $Install
