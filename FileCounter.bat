@echo off
setlocal enabledelayedexpansion

:menu
cls
echo ================= GitHub Repo Counter Menu ================
echo 1) Count all items (files + directories)
echo 2) Count all files (excluding directories)
echo 3) Count all directories (excluding files)
echo 4) Count files by user-specified extensions
echo 5) Group and count files by extension
echo 6) Check if API response is truncated
echo 0) Exit
echo ==========================================================
set /p option=Choose an option [0-6]: 

if "%option%"=="0" exit /B

set /p repo_url=Paste the GitHub repo URL (e.g. https://github.com/user/repo): 

rem --- More Robust URL Parsing ---
set "path_part=%repo_url%"
set "path_part=%path_part:https://github.com/=%"
set "path_part=%path_part:http://github.com/=%"
set "path_part=%path_part:www.github.com/=%"
set "path_part=%path_part:github.com/=%"
if "%path_part:~-1%"=="/" set "path_part=%path_part:~0,-1%"
if /i "%path_part:~-4%"==".git" set "path_part=%path_part:~0,-4%"
for /f "tokens=1,2 delims=/" %%a in ("%path_part%") do (
  set "owner=%%a"
  set "repo=%%b"
)
if not defined repo (
    echo. & echo ERROR: Invalid GitHub URL format. & goto pause_return
)

echo.
echo Finding default branch for %owner%/%repo%...
set "branch="
powershell -ExecutionPolicy Bypass -NoProfile -Command "$r=Invoke-RestMethod -Uri 'https://api.github.com/repos/%owner%/%repo%' -Headers @{'User-Agent'='PowerShell'} -ErrorAction SilentlyContinue; if($r){$r.default_branch}" > "%TEMP%\gh_branch.tmp"
set /p branch=<"%TEMP%\gh_branch.tmp"
del "%TEMP%\gh_branch.tmp"

if not defined branch (
    echo. & echo ERROR: Repository not found or private. Check the URL. & goto pause_return
)

set "api_url=https://api.github.com/repos/%owner%/%repo%/git/trees/%branch%?recursive=1"
echo Querying repository: %owner%/%repo% (branch: %branch%)
echo.

if "%option%"=="1" goto count_all
if "%option%"=="2" goto count_files
if "%option%"=="3" goto count_dirs
if "%option%"=="4" goto count_by_ext
if "%option%"=="5" goto group_by_ext
if "%option%"=="6" goto check_truncated
goto menu

:count_all
echo Counting all items...
set "temp_file=%TEMP%\gh_result.tmp"
powershell -ExecutionPolicy Bypass -NoProfile -Command "$r=Invoke-RestMethod -Uri '%api_url%' -Headers @{'User-Agent'='PowerShell'} -ErrorAction SilentlyContinue; if($r.tree){$r.tree.Count}else{Write-Host 0}" > "%temp_file%"
set /p result=<"%temp_file%"
del "%temp_file%"
if not defined result set result=0
echo. & echo Result: Found %result% total item(s).
goto pause_return

:count_files
echo Counting all files...
set "temp_file=%TEMP%\gh_result.tmp"
powershell -ExecutionPolicy Bypass -NoProfile -Command "$r=Invoke-RestMethod -Uri '%api_url%' -Headers @{'User-Agent'='PowerShell'} -ErrorAction SilentlyContinue; if($r.tree){($r.tree | Where-Object {$_.type -eq 'blob'}).Count}else{Write-Host 0}" > "%temp_file%"
set /p result=<"%temp_file%"
del "%temp_file%"
if not defined result set result=0
echo. & echo Result: Found %result% file(s).
goto pause_return

:count_dirs
echo Counting all directories...
set "temp_file=%TEMP%\gh_result.tmp"
powershell -ExecutionPolicy Bypass -NoProfile -Command "$r=Invoke-RestMethod -Uri '%api_url%' -Headers @{'User-Agent'='PowerShell'} -ErrorAction SilentlyContinue; if($r.tree){($r.tree | Where-Object {$_.type -eq 'tree'}).Count}else{Write-Host 0}" > "%temp_file%"
set /p result=<"%temp_file%"
del "%temp_file%"
if not defined result set result=0
echo. & echo Result: Found %result% director(y/ies).
goto pause_return

:count_by_ext
set /p ext=Enter file extensions to count (comma-separated, e.g. .sv,.v,.bat): 
set "regex="
for %%e in (%ext%) do (
  set "e=%%~e"
  if "!e:~0,1!"=="." set "e=!e:~1!"
  if defined regex (set "regex=!regex!|!e!") else (set "regex=!e!")
)
echo Counting files with extensions: %ext%
set "temp_file=%TEMP%\gh_result.tmp"
powershell -ExecutionPolicy Bypass -NoProfile -Command "$r=Invoke-RestMethod -Uri '%api_url%' -Headers @{'User-Agent'='PowerShell'} -ErrorAction SilentlyContinue; if($r.tree){($r.tree | Where-Object {$_.type -eq 'blob' -and $_.path -match '\.(%regex%)$'}).Count}else{Write-Host 0}" > "%temp_file%"
set /p result=<"%temp_file%"
del "%temp_file%"
if not defined result set result=0
echo. & echo Result: Found %result% matching file(s).
goto pause_return

:group_by_ext
echo Grouping files by extension...
powershell -ExecutionPolicy Bypass -NoProfile -Command ^
"$r=Invoke-RestMethod -Uri '%api_url%' -Headers @{'User-Agent'='PowerShell'} -ErrorAction SilentlyContinue; if($r.tree){$r.tree | Where-Object {$_.type -eq 'blob' -and $_.path -match '\.'} | Group-Object {[System.IO.Path]::GetExtension($_.path)} | Select-Object Name,Count | Format-Table -AutoSize}else{Write-Host 'No data found.'}"
goto pause_return

:check_truncated
echo Checking if API response was truncated...
set "temp_file=%TEMP%\gh_result.tmp"
powershell -ExecutionPolicy Bypass -NoProfile -Command "$r=Invoke-RestMethod -Uri '%api_url%' -Headers @{'User-Agent'='PowerShell'} -ErrorAction SilentlyContinue; if($r){$r.truncated}else{Write-Host 'Error'}" > "%temp_file%"
set /p result=<"%temp_file%"
del "%temp_file%"
if not defined result set result=Error
echo. & echo Result: Is response truncated? %result%
goto pause_return

:pause_return
echo.
pause
goto menu