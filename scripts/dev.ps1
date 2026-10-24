#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('init', 'db-up', 'db-down', 'prepare', 'start')]
    [string] $Action = 'start',
    [ValidateRange(1024, 65535)]
    [int] $Port = 5000,
    [ValidateRange(1024, 65535)]
    [int] $DatabasePort = 13306
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$local = Join-Path $repo '.local'
$runtime = Join-Path $local 'app'
$composeEnv = Join-Path $repo '.env'
$appEnv = Join-Path $local 'dev.env'

function Invoke-Checked {
    param([string] $Command, [string[]] $Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Command failed (exit $LASTEXITCODE)." }
}

function Get-FreePort([int] $Preferred) {
    for ($candidate = $Preferred; $candidate -le [Math]::Min(65535, $Preferred + 100); $candidate++) {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $candidate)
        try { $listener.Start(); return $candidate }
        catch [Net.Sockets.SocketException] { }
        finally { $listener.Stop() }
    }
    throw "No free loopback port near $Preferred."
}

function New-Secret {
    [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
}

function Initialize-Local {
    if ((Test-Path $composeEnv) -and (Test-Path $appEnv)) { return }
    if ((Test-Path $composeEnv) -or (Test-Path $appEnv)) {
        throw 'Incomplete local configuration. Preserve existing secrets and restore the missing file before continuing.'
    }
    $httpPort = Get-FreePort $Port
    $dbPort = Get-FreePort $DatabasePort
    if ($dbPort -eq $httpPort) { $dbPort = Get-FreePort ($dbPort + 1) }
    New-Item -ItemType Directory -Force $local, $runtime, (Join-Path $runtime 'config') | Out-Null
    $dbPassword = New-Secret
    $rootPassword = New-Secret
    @(
        "MEMTLY_DEV_DB_PORT=$dbPort"
        "MEMTLY_DEV_DB_PASSWORD=$dbPassword"
        "MEMTLY_DEV_DB_ROOT_PASSWORD=$rootPassword"
    ) | Set-Content $composeEnv -Encoding utf8NoBOM
    @(
        'ASPNETCORE_ENVIRONMENT=Development'
        "ASPNETCORE_URLS=http://127.0.0.1:$httpPort"
        "Memtly__Base_Url=http://localhost:$httpPort"
        'Memtly__Force_Https=false'
        'Memtly__Database__Type=mariadb'
        "Memtly__Database__Connection_String=Server=127.0.0.1;Port=$dbPort;Database=memtly_dev;User=memtly_dev;Password=$dbPassword"
        'Memtly__Database__Sync_From_Config=false'
        "Memtly__Security__Encryption__Key=$(New-Secret)"
        "Memtly__Security__Encryption__Salt=$(New-Secret)"
        'Memtly__Account__Admin__Email=admin@memtly.local'
        "Memtly__Account__Admin__Password=$(New-Secret)"
        'Memtly__Account__Registration__Enabled=false'
        'Memtly__Logging__Graylog__Enabled=false'
        'Memtly__Email_Report=false'
        'Memtly__Reports__Email__Enabled=false'
        'Memtly__Notifications__Smtp__Enabled=false'
        'Memtly__Notifications__Ntfy__Enabled=false'
        'Memtly__Notifications__Gotify__Enabled=false'
        'Memtly__Sponsors__Url=http://127.0.0.1:1'
        "FFMPEG__InstallPath=$(Join-Path $local 'ffmpeg')"
    ) | ForEach-Object {
        # Memtly's ConfigHelper checks these aliases before ASP.NET configuration.
        # Set them explicitly so inherited settings cannot select another database.
        if ($_ -match '^Memtly__(.+?)=(.*)$') {
            "$($Matches[1].Replace('__', '_').ToUpperInvariant())=$($Matches[2])"
        }
        elseif ($_ -match '^FFMPEG__InstallPath=(.*)$') { "INSTALLPATH=$($Matches[1])" }
        else { $_ }
    } | Set-Content $appEnv -Encoding utf8NoBOM
    # The files inherit the user's workspace permissions; additionally restrict Unix modes.
    if (-not $IsWindows) { Invoke-Checked chmod @('600', $composeEnv, $appEnv) }
    Write-Host "Local configuration created. URL: http://localhost:$httpPort"
    Write-Host 'Admin credentials: .local/dev.env (ignored by Git). Keep both secret files and the database together.'
}

function Invoke-Database([string[]] $ComposeArguments) {
    # Never inherit a remote Docker context or DOCKER_HOST from the calling shell.
    if ($env:DOCKER_HOST -or $env:DOCKER_CONTEXT) {
        throw 'Unset DOCKER_HOST and DOCKER_CONTEXT before using the local development database.'
    }
    $dockerContext = if ($IsWindows) { 'desktop-linux' } else { 'default' }
    $endpoint = (& docker context inspect $dockerContext --format '{{.Endpoints.docker.Host}}')
    if ($LASTEXITCODE -ne 0 -or $endpoint -notmatch '^(npipe:|unix:)') {
        throw 'A local Docker Desktop / Unix socket is required.'
    }
    Invoke-Checked docker (@('--context', $dockerContext, 'compose', '--project-name', 'memtly-wedding-dev',
        '--env-file', $composeEnv, '-f', (Join-Path $repo 'compose.dev.yaml')) + $ComposeArguments)
}

function Read-LocalSettings {
    $values = @{}
    foreach ($line in Get-Content $appEnv) {
        if ($line -match '^([^#=]+)=(.*)$') { $values[$Matches[1]] = $Matches[2] }
    }
    if ($values['DATABASE_TYPE'] -ne 'mariadb' -or
        $values['DATABASE_CONNECTION_STRING'] -notmatch '^Server=127\.0\.0\.1;Port=\d+;Database=memtly_dev;User=memtly_dev;Password=[A-F0-9]{64}$' -or
        $values['ASPNETCORE_URLS'] -notmatch '^http://127\.0\.0\.1:\d+$') {
        throw 'This launcher only accepts the generated loopback memtly_dev database and HTTP endpoint.'
    }
    return $values
}

function Protect-LocalFiles {
    if ($IsWindows) {
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        Invoke-Checked icacls @($local, '/inheritance:r', '/grant:r', "*${sid}:(OI)(CI)F", '*S-1-5-18:(OI)(CI)F')
        Invoke-Checked icacls @($composeEnv, '/inheritance:r', '/grant:r', "*${sid}:F", '*S-1-5-18:F')
    }
}

Push-Location $repo
try {
    Initialize-Local
    Protect-LocalFiles
    $localSettings = Read-LocalSettings
    switch ($Action) {
        'init' { break }
        'db-down' { Invoke-Database @('down'); break }
        'db-up' { Invoke-Database @('up', '-d', '--wait', '--wait-timeout', '180'); break }
        default {
            Invoke-Database @('up', '-d', '--wait', '--wait-timeout', '180')
            Invoke-Checked dotnet @('restore', 'Memtly.Community.sln', '--locked-mode')
            Invoke-Checked dotnet @('publish', 'Memtly.Community/Memtly.Community.csproj', '-c', 'Debug',
                '--no-restore', '-o', $runtime)
            if ($Action -eq 'prepare') { break }
            foreach ($name in $localSettings.Keys) {
                [Environment]::SetEnvironmentVariable($name, $localSettings[$name], 'Process')
            }
            Push-Location $runtime
            try { Invoke-Checked dotnet @('Memtly.Community.dll') }
            finally { Pop-Location }
        }
    }
}
finally { Pop-Location }
