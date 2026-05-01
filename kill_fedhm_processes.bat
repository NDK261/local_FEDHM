@echo off
setlocal

cd /d "%~dp0"

echo Cleaning old FedHM and FEDHM_PLUS python processes...

powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'python.exe' -and ($_.CommandLine -like '\"D:\\FedHM\\*' -or $_.CommandLine -like '\"D:\\FEDHM_PLUS\\*' -or $_.CommandLine -like '*run_gloo.py*') } | ForEach-Object { Write-Host ('Stopping PID ' + $_.ProcessId + ' :: ' + $_.CommandLine); Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"

echo.
echo Verifying remaining FedHM-related python processes...

powershell -NoProfile -ExecutionPolicy Bypass -Command "$remaining = Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'python.exe' -and ($_.CommandLine -like '\"D:\\FedHM\\*' -or $_.CommandLine -like '\"D:\\FEDHM_PLUS\\*' -or $_.CommandLine -like '*run_gloo.py*') }; if ($remaining) { $remaining | Select-Object ProcessId, ParentProcessId, Name, CommandLine | Format-Table -AutoSize | Out-String -Width 400 | Write-Host } else { Write-Host 'No old FedHM/FEDHM_PLUS Python processes remain.' }"

echo.
pause