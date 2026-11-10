@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "OPENSLIDE_LAUNCHER=%~f0"
set "OPENSLIDE_ACTION=%~1"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:OPENSLIDE_LAUNCHER); & ([scriptblock]::Create($s.Substring($s.LastIndexOf('# POWERSHELL PAYLOAD'))))"
set "result=%errorlevel%"
if "%~1"=="" pause
exit /b %result%
# POWERSHELL PAYLOAD
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$action = $env:OPENSLIDE_ACTION
if (!$action) { $action = 'auto' }
function Confirm-Action($message, $word) {
    return (Read-Host "$message Type $word to confirm") -ceq $word
}
if ($action -notin @('auto','install','start','repair','check','update','uninstall','help')) { Write-Host 'Unknown command. Use install/start/repair/check/update/uninstall/help.'; exit 2 }
if ($action -eq 'help') { Write-Host 'OpenSlide Launcher 1.0.0: install | start | repair | check | update | uninstall'; exit 0 }
$base = Join-Path $env:LOCALAPPDATA 'OpenSlide'
function Set-NodeVersion($version) {
    $script:nodeVersion = $version
    $script:nodeDir = Join-Path $base "node-v$version"
    $script:node = Join-Path $nodeDir 'node.exe'
    $script:npm = Join-Path $nodeDir 'node_modules/npm/bin/npm-cli.js'
}
# Reuse the installed runtime for start/repair; resolve latest LTS on first install.
$installedNode = Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^node-v\d+\.\d+\.\d+$' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'node.exe')) } |
    Sort-Object { [version]$_.Name.Substring(6) } -Descending | Select-Object -First 1
if ($installedNode) { Set-NodeVersion $installedNode.Name.Substring(6) }
else { Set-NodeVersion 'uninstalled' }
$tools = Join-Path $base 'tools'
$global = Join-Path $base 'npm-global'
$codex = Join-Path $global 'node_modules/@openai/codex/bin/codex.js'
$project = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'OpenSlideProjects'
if ($action -eq 'auto') {
    if ((Test-Path -LiteralPath $node) -and (Test-Path -LiteralPath (Join-Path $project 'package.json'))) { $action = 'start' } else { $action = 'install' }
}
$logDir = Join-Path $base 'logs'
$lock = $null
$transcribing = $false
if ($action -eq 'uninstall') {
    $uninstallLock = $null
    try {
        $localRoot = [IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\')
        $target = [IO.Path]::GetFullPath($base).TrimEnd('\')
        if ($target -ne ($localRoot + '\OpenSlide')) { throw 'Unexpected uninstall path. Stopped.' }
        Write-Host "Remove installed tools, cache, backups and logs: $target"
        Write-Host "Keep slide project: $project"
        Write-Host 'Keep shared Codex login/settings and this BAT file.'
        if (!(Test-Path -LiteralPath $target)) { Write-Host 'Already uninstalled.'; exit 0 }
        $cursor = Get-Item -LiteralPath $target -Force
        while ($cursor) {
            if ($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Uninstall path contains a link or junction. Check its target and remove manually.' }
            $cursor = $cursor.Parent
        }
        $links = @(Get-ChildItem -LiteralPath $target -Force -Recurse -Attributes ReparsePoint)
        if ($links.Count) { throw 'Installation contains links or junctions. Check their targets and remove manually.' }
        $running = @(Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($target + '\', [StringComparison]::OrdinalIgnoreCase) })
        if ($running.Count) { throw 'Installed tools are running. Stop Open Slide and Codex before uninstalling.' }
        $lockPath = Join-Path $target 'launcher.lock'
        $uninstallLock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
        if (!(Confirm-Action "移除工具、快取、備份和日誌？`n$target`n簡報專案與共用 Codex 登入設定會保留。" 'UNINSTALL')) { Write-Host 'Uninstall cancelled.'; exit 0 }
        # Retain the installation lock while removing other entries.
        Get-ChildItem -LiteralPath $target -Force | Where-Object { $_.FullName -ne $lockPath } | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force
        }
        $uninstallLock.Dispose()
        $uninstallLock = $null
        Remove-Item -LiteralPath $lockPath -Force
        Remove-Item -LiteralPath $target -Force
        Write-Host 'Uninstalled. Slide project and shared Codex settings were kept.'
        exit 0
    } catch {
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host 'Uninstall may be incomplete. Check the installation folder before retrying.'
        exit 1
    } finally {
        if ($uninstallLock) { $uninstallLock.Dispose() }
    }
}
function Run-Node([string[]]$Arguments) {
    & $node @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Node command failed (exit $LASTEXITCODE): $($Arguments[0])" }
}
function Npm([string[]]$Arguments) { Run-Node (@($npm) + $Arguments) }
function Json-File($path) { Get-Content -LiteralPath $path -Raw | ConvertFrom-Json }
function Save-Json($value, $path) { [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 50), (New-Object Text.UTF8Encoding $false)) }
function Fetch($url) { Invoke-RestMethod -Uri $url -TimeoutSec 60 }
function Latest-Package($name) {
    $version = (Fetch "https://registry.npmjs.org/$name/latest").version
    if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "Invalid release version for $name." }
    return $version
}
function Ensure-Node {
    if (!(Test-Path -LiteralPath $node)) {
        $release = Fetch 'https://nodejs.org/dist/index.json' | Where-Object { $_.lts -and $_.files -contains 'win-x64-zip' } | Select-Object -First 1
        if (!$release -or $release.version -notmatch '^v\d+\.\d+\.\d+$') { throw 'No valid Windows x64 Node LTS release found.' }
        Set-NodeVersion $release.version.Substring(1)
        $archiveName = "node-v$nodeVersion-win-x64.zip"
        $checksums = (Invoke-WebRequest "https://nodejs.org/dist/v$nodeVersion/SHASUMS256.txt" -UseBasicParsing -TimeoutSec 60).Content
        $hashMatch = [regex]::Match($checksums, ('(?m)^([a-fA-F0-9]{64})\s+' + [regex]::Escape($archiveName) + '\r?$'))
        if (!$hashMatch.Success) { throw 'Official Node ZIP SHA256 is missing. Installation stopped.' }
        $nodeHash = $hashMatch.Groups[1].Value
        $work = Join-Path $base ('stage-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $work | Out-Null
        $zip = Join-Path $work 'node.zip'
        Write-Host "Downloading verified Node.js $nodeVersion..."
        Invoke-WebRequest "https://nodejs.org/dist/v$nodeVersion/node-v$nodeVersion-win-x64.zip" -UseBasicParsing -OutFile $zip -TimeoutSec 300
        $stream = [IO.File]::OpenRead($zip)
        try { $actualHash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($stream)).Replace('-','') } finally { $stream.Dispose() }
        if ($actualHash -ne $nodeHash) { throw 'Node ZIP SHA256 mismatch. Installation stopped.' }
        Expand-Archive -LiteralPath $zip -DestinationPath $work
        Move-Item -LiteralPath (Join-Path $work "node-v$nodeVersion-win-x64") -Destination $nodeDir
        # Only this unique directory, created by this invocation, is removed.
        Remove-Item -LiteralPath $work -Recurse -Force
    }
    $env:PATH = "$nodeDir;" + $env:PATH
    if (!(Test-Path -LiteralPath $npm)) { throw 'Portable npm is missing. Remove the damaged version directory and run repair.' }
    $actual = & $node --version
    if ($LASTEXITCODE -ne 0 -or $actual -ne "v$nodeVersion") { throw 'Portable Node version verification failed.' }
}
function Validate-Project {
    $manifest = Join-Path $project 'package.json'
    if (!(Test-Path -LiteralPath $manifest)) { throw "Project not installed: $project. Run install." }
    $pkg = Json-File $manifest
    if (!$pkg.dependencies.'@open-slide/core' -or !(Test-Path -LiteralPath (Join-Path $project 'open-slide.config.ts'))) { throw 'Existing directory is not a valid Open Slide project. No files overwritten.' }
}
function Dependencies {
    Push-Location -LiteralPath $project
    try {
        if (Test-Path -LiteralPath 'package-lock.json') { Npm @('ci','--include=optional') }
        else { Npm @('install','--include=optional') }
    } finally { Pop-Location }
}
function Install-Codex($version) {
    # Validate both packages before changing the installed CLI.
    $null = Fetch "https://registry.npmjs.org/@openai%2fcodex/$version"
    $null = Fetch "https://registry.npmjs.org/@openai%2fcodex/$version-win32-x64"
    Npm @('install','--global','--prefix',$global,"@openai/codex@$version", "@openai/codex-win32-x64@npm:@openai/codex@$version-win32-x64",'--include=optional')
    Run-Node @($codex,'--version')
}
try {
    if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -and $env:PROCESSOR_ARCHITEW6432 -ne 'AMD64') { throw 'This launcher supports Windows x64 only.' }
    New-Item -ItemType Directory -Force -Path $base,$logDir | Out-Null
    $lock = [IO.File]::Open((Join-Path $base 'launcher.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    $log = Join-Path $logDir ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $PID + '.log')
    Start-Transcript -Path $log | Out-Null
    $transcribing = $true
    Write-Host "OpenSlide Launcher 1.0.0 - $action"
    Write-Host "Project: $project"
    $env:PATH = "$nodeDir;$global;" + $env:PATH
    $env:npm_config_cache = Join-Path $base 'npm-cache'
    $env:npm_config_registry = 'https://registry.npmjs.org/'
    $env:npm_config_prefix = $global
    if ($action -eq 'check') {
        foreach ($item in @(@('Node LTS', 'https://nodejs.org/dist/index.json'), @('Open Slide','https://registry.npmjs.org/@open-slide%2fcore/latest'), @('Codex','https://registry.npmjs.org/@openai%2fcodex/latest'))) {
            $data = Fetch $item[1]
            if ($item[0] -eq 'Node LTS') { $data = $data | Where-Object { $_.lts -and $_.files -contains 'win-x64-zip' } | Select-Object -First 1 }
            Write-Host "$($item[0]) available: $($data.version)"
        }
        Write-Host 'Install defaults: latest Node LTS; latest stable Open Slide CLI/core and Codex.'
        if (Test-Path -LiteralPath $node) { Run-Node @('--version') }
        if (Test-Path -LiteralPath $codex) { Run-Node @($codex,'--version') }
        $installedCore = Join-Path $project 'node_modules/@open-slide/core/package.json'
        if (Test-Path -LiteralPath $installedCore) { Write-Host "Installed Open Slide: $((Json-File $installedCore).version)" }
    } elseif ($action -in @('install','repair')) {
        Ensure-Node
        if (!(Test-Path -LiteralPath (Join-Path $project 'package.json'))) {
            if ((Test-Path -LiteralPath $project) -and @(Get-ChildItem -LiteralPath $project -Force).Count) { throw 'Project directory is not empty. Refusing to overwrite.' }
            $cliVersion = Latest-Package '@open-slide%2fcli'
            $slideVersion = Latest-Package '@open-slide%2fcore'
            Write-Host "Installing Open Slide CLI $cliVersion; core $slideVersion"
            Npm @('install','--prefix',$tools,"@open-slide/cli@$cliVersion",'--include=optional')
            New-Item -ItemType Directory -Force -Path $project | Out-Null
            $template = Join-Path $tools 'node_modules/@open-slide/cli/template'
            Get-ChildItem -LiteralPath $template -Force | Copy-Item -Destination $project -Recurse -Force
            [IO.File]::WriteAllText((Join-Path $project '.gitignore'), "node_modules/`ndist/`n")
            $manifest = Join-Path $project 'package.json'
            $pkg = Json-File $manifest
            $pkg.name = 'open-slide-projects'
            $pkg.dependencies.'@open-slide/core' = $slideVersion
            Save-Json $pkg $manifest
        }
        Validate-Project
        if ($action -eq 'repair' -or !(Test-Path -LiteralPath (Join-Path $project 'node_modules/@open-slide/core/dist/cli/bin.js'))) { Dependencies }
        if (!(Test-Path -LiteralPath $codex)) { Install-Codex (Latest-Package '@openai%2fcodex') }
        elseif ($action -eq 'repair') { Install-Codex (Json-File (Join-Path $global 'node_modules/@openai/codex/package.json')).version }
        else { Run-Node @($codex,'--version') }
        Write-Host 'Ready. Double-click this BAT again to start Open Slide.'
    } elseif ($action -eq 'update') {
        if (!(Test-Path -LiteralPath $node)) { throw 'Run install before update.' }
        Validate-Project
        $newSlide = (Fetch 'https://registry.npmjs.org/@open-slide%2fcore/latest').version
        $newCodex = (Fetch 'https://registry.npmjs.org/@openai%2fcodex/latest').version
        if ($newSlide -notmatch '^\d+\.\d+\.\d+$' -or $newCodex -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid release version.' }
        $coreManifest = Join-Path $project 'node_modules/@open-slide/core/package.json'
        $codexManifest = Join-Path $global 'node_modules/@openai/codex/package.json'
        if (!(Test-Path -LiteralPath $coreManifest) -or !(Test-Path -LiteralPath $codexManifest)) { throw 'Installed versions missing. Run repair before update.' }
        $currentSlide = (Json-File $coreManifest).version
        $currentCodex = (Json-File $codexManifest).version
        if ($currentSlide -notmatch '^\d+\.\d+\.\d+$' -or $currentCodex -notmatch '^\d+\.\d+\.\d+$') { throw 'Cannot compare installed versions safely. No changes made.' }
        $updateSlide = [version]$newSlide -gt [version]$currentSlide
        $updateCodex = [version]$newCodex -gt [version]$currentCodex
        Write-Host "Open Slide: installed $currentSlide; available $newSlide"
        Write-Host "Codex: installed $currentCodex; available $newCodex"
        if (!$updateSlide -and !$updateCodex) {
            Write-Host 'No newer versions available. Nothing to update.'
        } else {
        if ($updateSlide) { Write-Host "Update Open Slide: $currentSlide -> $newSlide" }
        if ($updateCodex) { Write-Host "Update Codex: $currentCodex -> $newCodex" }
        if (Confirm-Action 'Install the newer versions listed above?' 'UPDATE') {
            $backup = Join-Path $base ('backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
            New-Item -ItemType Directory -Path $backup | Out-Null
            Copy-Item -LiteralPath (Join-Path $project 'package.json') -Destination $backup
            if (Test-Path -LiteralPath (Join-Path $project 'package-lock.json')) { Copy-Item -LiteralPath (Join-Path $project 'package-lock.json') -Destination $backup }
            Write-Host "Manifest backup: $backup"
            Push-Location -LiteralPath $project
            try { if ($updateSlide) { Npm @('install','--save-exact',"@open-slide/core@$newSlide",'--include=optional') } } finally { Pop-Location }
            if ($updateCodex) { Install-Codex $newCodex }
            Write-Host 'Update complete. Start manually with OpenSlide.bat start.'
        } else { Write-Host 'Update cancelled.' }
        }
    } elseif ($action -eq 'start') {
        if (!(Test-Path -LiteralPath $node)) { throw 'Node is missing. Run install.' }
        Validate-Project
        $cli = Join-Path $project 'node_modules/@open-slide/core/dist/cli/bin.js'
        if (!(Test-Path -LiteralPath $cli)) { throw 'Dependencies missing. Run repair.' }
        $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Any,5173)
        $listener.Server.ExclusiveAddressUse = $true
        try { $listener.Start() } catch { throw 'Port 5173 is occupied. Close the other server before starting.' } finally { $listener.Stop() }
        Push-Location -LiteralPath $project
        try { Run-Node @($cli,'dev','--host','127.0.0.1','--port','5173','--open') } finally { Pop-Location }
    }
    exit 0
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    if ($log) { Write-Host "Log: $log" }
    exit 1
} finally {
    if ($transcribing) { Stop-Transcript | Out-Null }
    if ($lock) { $lock.Dispose() }
}
