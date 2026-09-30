@echo off
setlocal EnableExtensions DisableDelayedExpansion
title OfflineKit - Offline Archive Downloader
mode con: cols=120 lines=42 >nul 2>&1

rem ==============================================================
rem  OfflineKit - self-contained BAT launcher
rem
rem  The BAT is intentionally a thin wrapper around an embedded
rem  PowerShell program. This avoids fragile CMD blocks, CALL
rem  recursion, repeated ECHO expansion, and ampersand/percent
rem  escaping bugs found in the previous version.
rem
rem  It DOWNLOADS/ARCHIVES. It does not silently install software.
rem ==============================================================

set "OFFLINEKIT_SELF=%~f0"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$raw=[IO.File]::ReadAllText($env:OFFLINEKIT_SELF);" ^
  "$marker='### OFFLINEKIT' + ' POWERSHELL ###';" ^
  "$idx=$raw.IndexOf($marker);" ^
  "if($idx -lt 0){Write-Host 'OfflineKit error: embedded engine not found.' -ForegroundColor Red; exit 2};" ^
  "$ps=$raw.Substring($idx+$marker.Length);" ^
  "$tmp=Join-Path $env:TEMP ('OfflineKit_'+[guid]::NewGuid().ToString('N')+'.ps1');" ^
  "[IO.File]::WriteAllText($tmp,$ps,(New-Object Text.UTF8Encoding($false)));" ^
  "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $tmp;" ^
  "$code=$LASTEXITCODE;" ^
  "Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue;" ^
  "exit $code"

exit /b %ERRORLEVEL%

### OFFLINEKIT POWERSHELL ###
$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest

# --------------------------- UI ---------------------------
$esc = [char]27
$Colors = @{
    Header = "${esc}[96m"
    Accent = "${esc}[95m"
    Green  = "${esc}[92m"
    Yellow = "${esc}[93m"
    Red    = "${esc}[91m"
    Gray   = "${esc}[90m"
    White  = "${esc}[97m"
    Cyan   = "${esc}[96m"
    Reset  = "${esc}[0m"
}

function Write-Color([string]$Text, [string]$Color = $Colors.White, [switch]$NoNewLine) {
    if ($NoNewLine) { Write-Host ($Color + $Text + $Colors.Reset) -NoNewline }
    else { Write-Host ($Color + $Text + $Colors.Reset) }
}

function Write-Title {
    param(
        [string]$Stage = 'READY',
        [int]$Current = 0,
        [int]$Total = 0
    )

    Clear-Host

    Write-Color '+======================================================================================================================+' $Colors.Header
    Write-Color '|                                  O F F L I N E K I T                                                              |' $Colors.Header
    Write-Color '|                         Offline AI / Dev Survival Archive                                                        |' $Colors.Header
    Write-Color '+======================================================================================================================+' $Colors.Header
    Write-Host ''

    $pct = if($Total -gt 0){ [math]::Round(($Current/$Total)*100) } else { 0 }
    $barWidth = 48
    $filled = [math]::Floor($barWidth*$pct/100)
    $bar = ('#' * $filled) + ('.' * ($barWidth-$filled))

    Write-Color ("  STAGE   : {0,-16}  PROGRESS : [{1}] {2,3}%    ITEM {3}/{4}" -f $Stage,$bar,$pct,$Current,$Total) $Colors.White
    Write-Host ''
}

function Write-StatusLine {
    param(
        [int]$Index,
        [int]$Total,
        [string]$Name,
        [string]$Status,
        [string]$Detail = ''
    )

    $tag = switch ($Status) {
        'WAITING'     { '[  ]' }
        'DOWNLOADING' { '[>>]' }
        'OK'          { '[OK]' }
        'SKIP'        { '[--]' }
        'FAILED'      { '[!!]' }
        'DEFERRED'    { '[..]' }
        'RUNNING'     { '[>>]' }
        default       { '[??]' }
    }

    $color = switch ($Status) {
        'OK'          { $Colors.Green }
        'SKIP'        { $Colors.Gray }
        'FAILED'      { $Colors.Red }
        'DEFERRED'    { $Colors.Yellow }
        'DOWNLOADING' { $Colors.Cyan }
        'RUNNING'     { $Colors.Cyan }
        default       { $Colors.White }
    }

    $line = '{0,2}. {1,-4} {2,-35} {3}' -f $Index,$tag,$Name,$Detail
    Write-Color $line $color
}

# ----------------------- Destination -----------------------
Write-Title -Stage 'CONFIGURATION'

$defaultRoot = if(Test-Path 'D:\'){ 'D:\OfflineKit' } else { Join-Path $env:USERPROFILE 'OfflineKit' }

Write-Color '  STORAGE LOCATION' $Colors.Accent
Write-Color ("  Default: {0}" -f $defaultRoot) $Colors.Gray
Write-Host ''
$rootInput = Read-Host '  Enter destination (ENTER = default)'
if([string]::IsNullOrWhiteSpace($rootInput)){ $root = $defaultRoot }
else { $root = $rootInput.Trim().TrimEnd('\','/') }

try { $root = [IO.Path]::GetFullPath($root) }
catch {
    Write-Color 'Invalid destination path.' $Colors.Red
    Read-Host 'Press ENTER to exit'
    exit 3
}

try {
    $probeRoot = Split-Path -Qualifier $root
    $drive = Get-PSDrive -Name ($probeRoot.TrimEnd(':')) -ErrorAction Stop
    $freeGB = [math]::Round($drive.Free / 1GB, 1)
}catch{
    $freeGB = -1
}

# ------------------------- Package plan -------------------------
# Direct downloads are deliberately explicit.
# Runtime-dependent jobs are attempted only when the relevant
# runtime already exists; otherwise they become DEFERRED and a
# helper BAT is generated.

$items = @(
    [pscustomobject]@{ Id=1;  Name='Ollama';                 Group='Installer';  Type='Download'; Url='https://ollama.com/download/OllamaSetup.exe'; Dest='00_Installers\OllamaSetup.exe'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=2;  Name='Python 3.14.7 x64';     Group='Installer';  Type='Download'; Url='https://www.python.org/ftp/python/3.14.7/python-3.14.7-amd64.exe'; Dest='00_Installers\python-3.14.7-amd64.exe'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=3;  Name='Node.js 24.20.0 LTS';  Group='Installer';  Type='Download'; Url='https://nodejs.org/dist/v24.20.0/node-v24.20.0-x64.msi'; Dest='00_Installers\node-v24.20.0-x64.msi'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=4;  Name='Docker Desktop';        Group='Installer';  Type='Download'; Url='https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe'; Dest='00_Installers\Docker Desktop Installer.exe'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=5;  Name='Git for Windows';       Group='Installer';  Type='GitHub';   Repo='git-for-windows/git'; Pattern='^Git-[0-9].*-64-bit\.exe$'; DestDir='00_Installers'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=6;  Name='Wireshark x64';         Group='Installer';  Type='Download'; Url='https://www.wireshark.org/download/win64/Wireshark-win64-latest.exe'; Dest='00_Installers\Wireshark-win64-latest.exe'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=7;  Name='WireGuard';             Group='Security';   Type='Download'; Url='https://download.wireguard.com/windows-client/wireguard-installer.exe'; Dest='00_Installers\wireguard-installer.exe'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=8;  Name='SQLite tools';          Group='Security';   Type='Download'; Url='https://www.sqlite.org/2026/sqlite-tools-win-x64-3530400.zip'; Dest='06_Security\sqlite-tools-win-x64-3530400.zip'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=9;  Name='Kiwix Desktop';         Group='Docs';       Type='GitHub';   Repo='kiwix/kiwix-desktop'; Pattern='kiwix-desktop.*windows.*(x64|64).*\.zip$'; DestDir='04_Documentation\Kiwix'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=10; Name='llama.cpp CUDA 12';     Group='AI Runtime'; Type='GitHub';   Repo='ggml-org/llama.cpp'; Pattern='llama-.*-bin-win-cuda-12\.4-x64\.zip$'; DestDir='01_AI\llama.cpp'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=11; Name='OpenCode Windows';     Group='Coding';     Type='GitHub';   Repo='anomalyco/opencode'; Pattern='.*(windows|win).*(x64|amd64).*\.(exe|zip)$'; DestDir='00_Installers'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=12; Name='Continue 2.0.0 VSIX';  Group='Coding';     Type='GitHubTag';Repo='continuedev/continue'; Tag='v2.0.0'; Pattern='.*\.vsix$'; DestDir='03_Development\VSIX'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=13; Name='yt-dlp';               Group='Media';      Type='Download'; Url='https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe'; Dest='08_MediaCourses\yt-dlp.exe'; Status='WAITING'; Detail='' }

    [pscustomobject]@{ Id=14; Name='Qwen3 4B';              Group='Model'; Type='Ollama'; Model='qwen3:4b'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=15; Name='Qwen3 1.7B';            Group='Model'; Type='Ollama'; Model='qwen3:1.7b'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=16; Name='DeepSeek-R1 7B';        Group='Model'; Type='Ollama'; Model='deepseek-r1:7b'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=17; Name='Gemma 3 4B';            Group='Model'; Type='Ollama'; Model='gemma3:4b'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=18; Name='BGE-M3';                Group='Embedding'; Type='Ollama'; Model='bge-m3'; Status='WAITING'; Detail='' }

    [pscustomobject]@{ Id=19; Name='n8n 2.37.9 image';       Group='Docker'; Type='Docker'; Image='docker.n8n.io/n8nio/n8n:2.37.9'; File='n8n_2.37.9.tar'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=20; Name='Open WebUI image';      Group='Docker'; Type='Docker'; Image='ghcr.io/open-webui/open-webui:v0.11.1'; File='open-webui_v0.11.1.tar'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=21; Name='Forgejo 16.0.3 image';  Group='Docker'; Type='Docker'; Image='codeberg.org/forgejo/forgejo:16.0.3'; File='forgejo_16.0.3.tar'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=22; Name='PostgreSQL 18.6 image';  Group='Docker'; Type='Docker'; Image='postgres:18.6'; File='postgres_18.6.tar'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=23; Name='Redis 8.10.1 image';    Group='Docker'; Type='Docker'; Image='redis:8.10.1'; File='redis_8.10.1.tar'; Status='WAITING'; Detail='' }

    [pscustomobject]@{ Id=24; Name='Python wheelhouse';     Group='Development'; Type='PythonCache'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=25; Name='npm cache helper';      Group='Development'; Type='NpmCache'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=26; Name='Obsidian backup helper'; Group='Backup'; Type='HelperOnly'; Status='WAITING'; Detail='' }
    [pscustomobject]@{ Id=27; Name='n8n backup helper';      Group='Backup'; Type='HelperOnly'; Status='WAITING'; Detail='' }
)

$total = $items.Count

# ------------------------ Confirmation ------------------------
Write-Title -Stage 'PLAN' -Current 0 -Total $total
Write-Color '  DOWNLOAD PLAN' $Colors.Accent
Write-Host ''
foreach($i in $items){
    Write-StatusLine -Index $i.Id -Total $total -Name $i.Name -Status $i.Status -Detail $i.Group
}
Write-Host ''
Write-Color '  Destination:' $Colors.Gray
Write-Color ("  {0}" -f $root) $Colors.White
if($freeGB -ge 0){ Write-Color ("  Free space: {0} GB" -f $freeGB) $Colors.Gray }
Write-Host ''
Write-Color '  IMPORTANT: this program downloads/archives. It does NOT silently install software.' $Colors.Yellow
Write-Host ''

$confirm = Read-Host '  Start the OfflineKit archive? [Y/N]'
if($confirm -notmatch '^(?i:y|yes)$'){
    Write-Color 'Cancelled. No downloads were started.' $Colors.Yellow
    exit 0
}

# -------------------- Directory architecture -------------------
$dirs = @(
    '00_Installers',
    '01_AI\Models\Ollama',
    '01_AI\Models\GGUF',
    '01_AI\llama.cpp',
    '01_AI\OpenWebUI',
    '02_n8n\Docker',
    '02_n8n\Workflows',
    '02_n8n\Backup',
    '03_Development\Python',
    '03_Development\PyPI_Wheelhouse',
    '03_Development\Node',
    '03_Development\npm-cache',
    '03_Development\VSIX',
    '03_Development\Git',
    '04_Documentation\Kiwix',
    '04_Documentation\Manifests',
    '05_Obsidian',
    '06_Security',
    '07_DockerImages',
    '08_MediaCourses',
    '99_Recovery',
    '_meta'
)

foreach($d in $dirs){
    New-Item -ItemType Directory -Force -Path (Join-Path $root $d) | Out-Null
}

$logPath     = Join-Path $root '_meta\offlinekit.log'
$failPath    = Join-Path $root '_meta\FAILED_ITEMS.txt'
$sourcePath  = Join-Path $root '_meta\DOWNLOAD_SOURCES.txt'
$hashPath    = Join-Path $root '_meta\SHA256_MANIFEST.txt'
$deferPath   = Join-Path $root '_meta\DEFERRED_RUNTIME_ITEMS.txt'

"OfflineKit started $(Get-Date -Format s)" | Set-Content $logPath -Encoding UTF8
"FAILED ITEMS" | Set-Content $failPath -Encoding UTF8
"OFFICIAL SOURCE / RECOVERY REFERENCES" | Set-Content $sourcePath -Encoding UTF8
"SHA256  PATH" | Set-Content $hashPath -Encoding UTF8
"DEFERRED RUNTIME ITEMS" | Set-Content $deferPath -Encoding UTF8

function Add-Log([string]$Text){
    Add-Content -LiteralPath $logPath -Value $Text -Encoding UTF8
}

function Add-Failure([string]$Text){
    Add-Content -LiteralPath $failPath -Value $Text -Encoding UTF8
}

function Add-Deferred([string]$Text){
    Add-Content -LiteralPath $deferPath -Value $Text -Encoding UTF8
}

function Add-Hash([string]$File){
    try{
        $hash = (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash
        Add-Content -LiteralPath $hashPath -Value ("{0}  {1}" -f $hash,$File) -Encoding UTF8
    }catch{
        Add-Log "HASH FAILED :: $File :: $($_.Exception.Message)"
    }
}

function Render([string]$Stage,[int]$Current){
    Write-Title -Stage $Stage -Current $Current -Total $total
    foreach($i in $items){
        Write-StatusLine -Index $i.Id -Total $total -Name $i.Name -Status $i.Status -Detail $i.Detail
    }
}

function Mark([int]$Id,[string]$Status,[string]$Detail=''){
    $item = $items | Where-Object Id -eq $Id | Select-Object -First 1
    if($null -ne $item){
        $item.Status = $Status
        $item.Detail = $Detail
    }
}

function Invoke-Download {
    param(
        [Parameter(Mandatory)]$Item,
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Destination
    )

    $destDir = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $partial = "$Destination.part"

    if((Test-Path $Destination) -and ((Get-Item $Destination).Length -gt 0)){
        Mark $Item.Id 'SKIP' 'already archived'
        Add-Log "SKIP :: $($Item.Name) :: already exists"
        Add-Hash $Destination
        return $true
    }

    Mark $Item.Id 'DOWNLOADING' $(if(Test-Path $partial){'resuming .part file'}else{'new transfer'})
    Render -Stage 'DOWNLOADING' -Current ($Item.Id-1)

    Write-Color ("`n  >>> {0}" -f $Item.Name) $Colors.Cyan
    Write-Color ("  URL: {0}" -f $Url) $Colors.Gray
    if(Test-Path $partial){
        $sizeMB = [math]::Round((Get-Item $partial).Length/1MB,2)
        Write-Color ("  Resume: {0} MB already downloaded" -f $sizeMB) $Colors.Yellow
    }
    Write-Host ''

    & curl.exe --location --fail --retry 5 --retry-delay 3 --connect-timeout 20 --continue-at - --progress-bar --output $partial $Url
    $code = $LASTEXITCODE

    if($code -eq 0 -and (Test-Path $partial) -and ((Get-Item $partial).Length -gt 0)){
        Move-Item -LiteralPath $partial -Destination $Destination -Force
        Mark $Item.Id 'OK' 'downloaded'
        Add-Log "OK :: $($Item.Name) :: $Url"
        Add-Content -LiteralPath $sourcePath -Value "$($Item.Name) :: $Url" -Encoding UTF8
        Add-Hash $Destination
        return $true
    }

    Mark $Item.Id 'FAILED' 'partial kept for resume'
    Add-Failure "$($Item.Name) :: $Url :: curl exit $code :: partial=$partial"
    Add-Log "FAILED :: $($Item.Name) :: exit $code :: partial kept :: $Url"
    return $false
}

function Get-GitHubAssetUrl {
    param(
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$Pattern,
        [string]$Tag = ''
    )

    $api = if([string]::IsNullOrWhiteSpace($Tag)){
        "https://api.github.com/repos/$Repo/releases/latest"
    }else{
        "https://api.github.com/repos/$Repo/releases/tags/$Tag"
    }

    try{
        $release = Invoke-RestMethod -Headers @{ 'User-Agent'='OfflineKit' } -Uri $api -TimeoutSec 30
        $asset = $release.assets | Where-Object { $_.name -match $Pattern } | Select-Object -First 1
        if($null -eq $asset){ throw "No release asset matched pattern: $Pattern" }
        return [pscustomobject]@{
            Url  = $asset.browser_download_url
            Name = $asset.name
        }
    }catch{
        return $null
    }
}

function Invoke-GitHubDownload {
    param([Parameter(Mandatory)]$Item)

    $asset = Get-GitHubAssetUrl -Repo $Item.Repo -Pattern $Item.Pattern -Tag ($(if($Item.PSObject.Properties.Name -contains 'Tag'){ $Item.Tag }else{ '' }))

    if($null -eq $asset){
        Mark $Item.Id 'FAILED' 'GitHub asset not found'
        Add-Failure "$($Item.Name) :: GitHub asset resolution failed :: $($Item.Repo)"
        Add-Log "FAILED :: $($Item.Name) :: GitHub asset resolution"
        return $false
    }

    $dest = Join-Path $root $Item.DestDir
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $file = Join-Path $dest $asset.Name

    Invoke-Download -Item $Item -Url $asset.Url -Destination $file
}

function Invoke-OllamaPull {
    param([Parameter(Mandatory)]$Item)

    $ollama = Get-Command ollama.exe -ErrorAction SilentlyContinue
    if($null -eq $ollama){
        Mark $Item.Id 'DEFERRED' 'Ollama not installed'
        Add-Deferred "$($Item.Name) :: install Ollama, then run 01_AI\_PULL_OLLAMA_MODELS_AFTER_INSTALL.bat"
        return
    }

    Mark $Item.Id 'RUNNING' 'ollama pull'
    Render -Stage 'LOCAL AI' -Current ($Item.Id-1)
    Write-Color ("`n  >>> Pulling {0}" -f $Item.Model) $Colors.Cyan
    Write-Host ''

    & ollama pull $Item.Model
    $code = $LASTEXITCODE

    if($code -eq 0){
        Mark $Item.Id 'OK' 'model ready'
        Add-Log "OK :: Ollama :: $($Item.Model)"
    }else{
        Mark $Item.Id 'FAILED' 'ollama pull failed'
        Add-Failure "$($Item.Name) :: ollama pull $($Item.Model) :: exit $code"
    }
}

function Invoke-DockerArchive {
    param([Parameter(Mandatory)]$Item)

    $docker = Get-Command docker.exe -ErrorAction SilentlyContinue
    if($null -eq $docker){
        Mark $Item.Id 'DEFERRED' 'Docker not installed'
        Add-Deferred "$($Item.Name) :: install/start Docker Desktop, then run 07_DockerImages\_PULL_AND_SAVE_DOCKER_IMAGES_AFTER_INSTALL.bat"
        return
    }

    Mark $Item.Id 'RUNNING' 'docker pull + save'
    Render -Stage 'DOCKER ARCHIVE' -Current ($Item.Id-1)
    Write-Color ("`n  >>> Pulling {0}" -f $Item.Image) $Colors.Cyan
    Write-Host ''

    & docker pull $Item.Image
    $pullCode = $LASTEXITCODE

    if($pullCode -ne 0){
        Mark $Item.Id 'FAILED' 'docker pull failed'
        Add-Failure "$($Item.Name) :: docker pull $($Item.Image) :: exit $pullCode"
        return
    }

    $dest = Join-Path (Join-Path $root '07_DockerImages') $Item.File
    & docker save -o $dest $Item.Image
    $saveCode = $LASTEXITCODE

    if($saveCode -eq 0 -and (Test-Path $dest)){
        Mark $Item.Id 'OK' 'image archived'
        Add-Log "OK :: Docker :: $($Item.Image)"
        Add-Hash $dest
    }else{
        Mark $Item.Id 'FAILED' 'docker save failed'
        Add-Failure "$($Item.Name) :: docker save $($Item.Image) :: exit $saveCode"
    }
}

# --------------------------- Downloads --------------------------
for($n=1;$n -le 13;$n++){
    $item = $items | Where-Object Id -eq $n
    if($item.Type -eq 'Download'){
        $dest = Join-Path $root $item.Dest
        Invoke-Download -Item $item -Url $item.Url -Destination $dest | Out-Null
    }elseif($item.Type -eq 'GitHub' -or $item.Type -eq 'GitHubTag'){
        Invoke-GitHubDownload -Item $item | Out-Null
    }
}

# -------------------------- Ollama models -----------------------
foreach($n in 14..18){
    Invoke-OllamaPull -Item ($items | Where-Object Id -eq $n)
}

# -------------------------- Docker images ------------------------
foreach($n in 19..23){
    Invoke-DockerArchive -Item ($items | Where-Object Id -eq $n)
}

# ---------------------- Helper generators ------------------------
$ollamaHelper = @"
@echo off
title OfflineKit - Pull Ollama Models
echo.
echo ============================================================
echo OfflineKit - Ollama Models
echo ============================================================
echo.
where ollama >nul 2>&1
if errorlevel 1 (
  echo Ollama is not installed.
  echo Install it from:
  echo %ROOT_REL%\00_Installers\OllamaSetup.exe
  pause
  exit /b 1
)
echo.
echo Pulling qwen3:4b
ollama pull qwen3:4b
echo.
echo Pulling qwen3:1.7b
ollama pull qwen3:1.7b
echo.
echo Pulling deepseek-r1:7b
ollama pull deepseek-r1:7b
echo.
echo Pulling gemma3:4b
ollama pull gemma3:4b
echo.
echo Pulling bge-m3
ollama pull bge-m3
echo.
ollama list
pause
"@

# Replace placeholder with an absolute, quoted path.
$ollamaHelper = $ollamaHelper.Replace('%ROOT_REL%', $root)
Set-Content -LiteralPath (Join-Path $root '01_AI\_PULL_OLLAMA_MODELS_AFTER_INSTALL.bat') -Value $ollamaHelper -Encoding ASCII

$dockerHelper = @"
@echo off
title OfflineKit - Docker Image Archive
echo.
echo ============================================================
echo OfflineKit - Docker Images
echo ============================================================
echo.
where docker >nul 2>&1
if errorlevel 1 (
  echo Docker is not installed.
  pause
  exit /b 1
)
echo Docker Desktop must be RUNNING.
echo.
call :grab "docker.n8n.io/n8nio/n8n:2.37.9" "n8n_2.37.9.tar"
call :grab "ghcr.io/open-webui/open-webui:v0.11.1" "open-webui_v0.11.1.tar"
call :grab "codeberg.org/forgejo/forgejo:16.0.3" "forgejo_16.0.3.tar"
call :grab "postgres:18.6" "postgres_18.6.tar"
call :grab "redis:8.10.1" "redis_8.10.1.tar"
echo.
echo Finished. Check %ROOT_REL%\_meta\FAILED_DOCKER_IMAGES.txt if any item failed.
pause
exit /b 0

:grab
set "IMG=%~1"
set "OUT=%~2"
echo.
echo [>>] Pulling %IMG%
docker pull "%IMG%"
if errorlevel 1 (
  echo [!!] Pull failed: %IMG%
  echo %IMG% >> "%ROOT_REL%\_meta\FAILED_DOCKER_IMAGES.txt"
  exit /b 0
)
docker save -o "%ROOT_REL%\07_DockerImages\%OUT%" "%IMG%"
if errorlevel 1 (
  echo [!!] Save failed: %IMG%
  echo %IMG% >> "%ROOT_REL%\_meta\FAILED_DOCKER_IMAGES.txt"
) else (
  echo [OK] %IMG%
)
exit /b 0
"@
$dockerHelper = $dockerHelper.Replace('%ROOT_REL%', $root)
Set-Content -LiteralPath (Join-Path $root '07_DockerImages\_PULL_AND_SAVE_DOCKER_IMAGES_AFTER_INSTALL.bat') -Value $dockerHelper -Encoding ASCII

$pythonHelper = @"
@echo off
title OfflineKit - Python Wheelhouse
echo.
where py >nul 2>&1
if errorlevel 1 (
  echo Python launcher not found. Install Python first.
  pause
  exit /b 1
)
echo Preparing a reusable Python wheelhouse...
mkdir "%ROOT_REL%\03_Development\PyPI_Wheelhouse" >nul 2>&1
py -m pip download pip setuptools wheel requests httpx python-dotenv rich numpy pandas scipy scikit-learn fastapi uvicorn pydantic jupyter ipykernel -d "%ROOT_REL%\03_Development\PyPI_Wheelhouse"
echo.
echo Offline example:
echo py -m pip install --no-index --find-links "%ROOT_REL%\03_Development\PyPI_Wheelhouse" PACKAGE
pause
"@
$pythonHelper = $pythonHelper.Replace('%ROOT_REL%', $root)
Set-Content -LiteralPath (Join-Path $root '03_Development\_PREPARE_PYTHON_WHEELHOUSE.bat') -Value $pythonHelper -Encoding ASCII

$npmHelper = @"
@echo off
title OfflineKit - npm Offline Cache
echo.
where npm >nul 2>&1
if errorlevel 1 (
  echo npm not found. Install Node.js first.
  pause
  exit /b 1
)
echo Setting npm cache:
npm config set cache "%ROOT_REL%\03_Development\npm-cache" --global
echo.
echo For each project WHILE ONLINE:
echo   cd PROJECT
echo   npm ci
echo This populates the local npm cache for that project.
echo.
echo Later, OFFLINE:
echo   npm ci --offline
echo.
echo For standalone packages:
echo   npm pack PACKAGE
echo.
pause
"@
$npmHelper = $npmHelper.Replace('%ROOT_REL%', $root)
Set-Content -LiteralPath (Join-Path $root '03_Development\_PREPARE_NPM_CACHE.bat') -Value $npmHelper -Encoding ASCII

$obsidianHelper = @"
@echo off
title OfflineKit - Obsidian Vault Backup
echo.
set "DEST=%ROOT_REL%\05_Obsidian"
mkdir "%DEST%" >nul 2>&1
set /p "VAULT=Paste the FULL path of your Obsidian Vault: "
if not exist "%VAULT%" (
  echo Vault not found.
  pause
  exit /b 1
)
echo Backing up Vault...
robocopy "%VAULT%" "%DEST%\Vault" /E /R:2 /W:2 /COPY:DAT /DCOPY:DAT /XJ
echo.
echo Backup complete:
echo %DEST%\Vault
pause
"@
$obsidianHelper = $obsidianHelper.Replace('%ROOT_REL%', $root)
Set-Content -LiteralPath (Join-Path $root '05_Obsidian\_BACKUP_OBSIDIAN_VAULT.bat') -Value $obsidianHelper -Encoding ASCII

$n8nHelper = @"
@echo off
title OfflineKit - n8n Data Backup
echo.
where docker >nul 2>&1
if errorlevel 1 (
  echo Docker not found.
  pause
  exit /b 1
)
mkdir "%ROOT_REL%\02_n8n\Backup" >nul 2>&1
echo Available Docker volumes:
docker volume ls
echo.
set /p "VOL=Enter the n8n Docker volume name: "
if not defined VOL exit /b 1
docker run --rm -v "%VOL%:/data:ro" -v "%ROOT_REL%\02_n8n\Backup:/backup" alpine:latest sh -c "cd /data && tar czf /backup/n8n_data_backup.tgz ."
echo.
echo Backup folder:
echo %ROOT_REL%\02_n8n\Backup
pause
"@
$n8nHelper = $n8nHelper.Replace('%ROOT_REL%', $root)
Set-Content -LiteralPath (Join-Path $root '02_n8n\_BACKUP_N8N_DATA.bat') -Value $n8nHelper -Encoding ASCII

# -------------------- Documentation / manifests -----------------
@'
OFFLINE KNOWLEDGE TO ARCHIVE WITH KIWIX
=======================================
Recommended:
- Python documentation and PEPs
- MDN Web Docs
- Stack Overflow / Stack Exchange
- freeCodeCamp
- Algorithms / Computer Science
- Linux / networking / security references
- Important books, PDFs and legally downloadable course materials

Note:
Kiwix ZIM catalog filenames, languages, sizes and release cadence change.
Do not hard-code arbitrary ZIM URLs. Select the desired ZIM files from the
official Kiwix catalog while Internet access is available.
'@ | Set-Content -LiteralPath (Join-Path $root '04_Documentation\Manifests\Kiwix_RECOMMENDED_ZIMS.txt') -Encoding UTF8

@"
OFFLINEKIT ARCHITECTURE
=======================

Laptop
 |
 +-- Ollama :11434
 |     +-- Qwen3 4B
 |     +-- Qwen3 1.7B
 |     +-- DeepSeek-R1 7B
 |     +-- Gemma3 4B
 |     +-- BGE-M3
 |
 +-- n8n :5678
 +-- Open WebUI
 +-- Kiwix
 +-- Forgejo
 +-- SQLite / PostgreSQL / Redis
 +-- FAISS + Local RAG
 +-- Git / Python / Node

Primary model      : Qwen3 4B
Emergency model    : Qwen3 1.7B
Reasoning model    : DeepSeek-R1 7B
Vision model       : Gemma3 4B
Embedding model    : BGE-M3
Backup runtime     : llama.cpp
"@ | Set-Content -LiteralPath (Join-Path $root '04_Documentation\Manifests\OFFLINE_ARCHITECTURE.txt') -Encoding UTF8

@"
OFFLINE FIRE DRILL
==================
Disconnect Wi-Fi, Ethernet and mobile Internet.

[ ] Ollama starts
[ ] Qwen3 4B responds
[ ] DeepSeek-R1 7B responds
[ ] Gemma 3 4B can process an image
[ ] n8n opens at http://localhost:5678
[ ] n8n reaches Ollama locally
[ ] Open WebUI opens
[ ] Kiwix opens a ZIM
[ ] Python installs from local wheelhouse
[ ] npm works with local cache / packed dependencies
[ ] Git commit/branch/merge works without a remote
[ ] Docker can load archived .tar images
[ ] Obsidian opens with required plugins

Recovery order:
1. Install Ollama
2. Pull models
3. Install Docker Desktop
4. Load Docker images
5. Restore n8n backup
6. Restore Obsidian Vault
7. Use Kiwix for docs
"@ | Set-Content -LiteralPath (Join-Path $root '99_Recovery\OFFLINE_FIRE_DRILL.txt') -Encoding UTF8

@"
OFFLINEKIT RECOVERY GUIDE
=========================
Installers:
  00_Installers

AI:
  01_AI

n8n:
  02_n8n

Development:
  03_Development

Documentation:
  04_Documentation

Obsidian:
  05_Obsidian

Security:
  06_Security

Docker images:
  07_DockerImages

Recovery:
  99_Recovery

Logs:
  _meta

Main failure report:
  _meta\FAILED_ITEMS.txt

Deferred runtime actions:
  _meta\DEFERRED_RUNTIME_ITEMS.txt
"@ | Set-Content -LiteralPath (Join-Path $root '99_Recovery\RECOVERY_GUIDE.txt') -Encoding UTF8

# Re-hash generated/downloaded files one final time.
Write-Title -Stage 'FINALIZING' -Current $total -Total $total
Get-ChildItem -LiteralPath $root -File -Recurse |
    Where-Object { $_.FullName -notlike "$root\_meta\*" } |
    ForEach-Object { Add-Hash $_.FullName }

# ------------------------------ End -----------------------------
$ok = @($items | Where-Object Status -eq 'OK' | Measure-Object).Count
$skip = @($items | Where-Object Status -eq 'SKIP' | Measure-Object).Count
$fail = @($items | Where-Object Status -eq 'FAILED' | Measure-Object).Count
$defer = @($items | Where-Object Status -eq 'DEFERRED' | Measure-Object).Count

Write-Title -Stage 'COMPLETE' -Current $total -Total $total
Write-Color '  FINAL RESULT' $Colors.Accent
Write-Host ''
Write-Color ("  [OK]      {0}" -f $ok) $Colors.Green
Write-Color ("  [SKIP]    {0}" -f $skip) $Colors.Gray
Write-Color ("  [FAILED]  {0}" -f $fail) $Colors.Red
Write-Color ("  [DEFERRED]{0}" -f $defer) $Colors.Yellow
Write-Host ''
Write-Color '  STORAGE' $Colors.Accent
Write-Color ("  {0}" -f $root) $Colors.White
Write-Host ''
Write-Color '  REPORTS' $Colors.Accent
Write-Color ("  Failed      : {0}" -f $failPath) $Colors.Gray
Write-Color ("  Deferred    : {0}" -f $deferPath) $Colors.Gray
Write-Color ("  Log         : {0}" -f $logPath) $Colors.Gray
Write-Color ("  SHA256      : {0}" -f $hashPath) $Colors.Gray
Write-Host ''
Write-Color '  NEXT: run OFFLINE_FIRE_DRILL.txt after you have installed the archived runtimes.' $Colors.Yellow
Write-Host ''
Read-Host '  Press ENTER to close'
