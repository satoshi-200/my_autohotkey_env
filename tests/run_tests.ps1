# Regression tests for the key assignments. ASCII only on purpose (PowerShell 5.1 reads BOM-less files as ANSI).
#
# Usage (run it as an async terminal and read the result file; a sync wait can hang the shell):
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_tests.ps1                 all cases in tests\cases
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_tests.ps1 -Cases space,clicks
# Result: %TEMP%\_t_results.txt  (PASS / FAIL lines and a TOTAL line; also printed at the end)
#
# What it does: suspends the running main.ahk, copies the repo to %TEMP%\_t_run, patches the copy so that
# GetKeyState("vk..","P") reads a flag file (injected keys are never "physical"), runs the copy, then runs each case
# (tests\cases\*.ahk, which #Include ..\harness.ahk) in its own process with a time limit, and finally restores everything.
param(
    [string[]]$Cases = @(),
    [int]$CaseTimeoutSec = 60
)
$ahk   = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
$tests = Split-Path -Parent $MyInvocation.MyCommand.Path
$root  = Split-Path -Parent $tests
$tmp   = Join-Path $env:TEMP '_t_run'
$result = Join-Path $env:TEMP '_t_results.txt'
Remove-Item $result -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:TEMP '_t_down_*'), (Join-Path $env:TEMP '_t_case_*') -ErrorAction SilentlyContinue
function Out-Result($text) { Add-Content -Path $result -Value $text -Encoding UTF8 }

$pids = @()
$suspended = $false
try {
    # 1. copy and patch
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    New-Item $tmp -ItemType Directory | Out-Null
    Copy-Item (Join-Path $root 'main.ahk') $tmp
    Copy-Item (Join-Path $root 'keymap') $tmp -Recurse
    Copy-Item (Join-Path $root 'Lib') $tmp -Recurse
    $pattern = 'GetKeyState\("((?:vk|sc)[0-9A-Fa-f]+)"\s*,\s*"P"\)'
    Get-ChildItem $tmp -Recurse -Filter *.ahk | ForEach-Object {
        $text = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
        $new = [regex]::Replace($text, $pattern, { param($m) 'FileExist(A_Temp "\_t_down_' + $m.Groups[1].Value.ToLower() + '")' })
        if ($new -ne $text) { [IO.File]::WriteAllText($_.FullName, $new, (New-Object Text.UTF8Encoding($false))) }
    }

    # 2. suspend the real script, start the copy
    Start-Process $ahk -ArgumentList "`"$tests\suspend.ahk`"", "`"$root`"" -Wait
    $suspended = $true
    $main = Start-Process $ahk -ArgumentList "`"$tmp\main.ahk`"" -PassThru
    $pids += $main.Id
    Start-Sleep -Seconds 3

    # 3. run the cases
    if ($Cases.Count -eq 0) { $files = Get-ChildItem (Join-Path $tests 'cases') -Filter *.ahk | Sort-Object Name }
    else { $files = $Cases | ForEach-Object { Get-Item (Join-Path $tests ("cases\" + $_ + ".ahk")) } }
    foreach ($f in $files) {
        $name = [IO.Path]::GetFileNameWithoutExtension($f.Name)
        $p = Start-Process $ahk -ArgumentList "`"$($f.FullName)`"" -PassThru
        $pids += $p.Id
        if (-not $p.WaitForExit($CaseTimeoutSec * 1000)) {
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            Out-Result "FAIL ${name}: timed out (a script error dialog may have stopped it)"
            continue
        }
        $rf = Join-Path $env:TEMP "_t_case_$name.txt"
        if (Test-Path $rf) { Out-Result ((Get-Content $rf -Encoding UTF8) -join "`n") } else { Out-Result "FAIL ${name}: no result file" }
    }
}
finally {
    foreach ($id in $pids) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
    if ($suspended) { Start-Process $ahk -ArgumentList "`"$tests\suspend.ahk`"", "`"$root`"" -Wait }
    Remove-Item (Join-Path $env:TEMP '_t_down_*') -ErrorAction SilentlyContinue
    $all = if (Test-Path $result) { Get-Content $result -Encoding UTF8 } else { @() }
    $pass = @($all | Where-Object { $_ -like 'PASS*' }).Count
    $fail = @($all | Where-Object { $_ -like 'FAIL*' }).Count
    Out-Result "TOTAL: $pass pass, $fail fail"
    Get-Content $result -Encoding UTF8
}
