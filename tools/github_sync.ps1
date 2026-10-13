[CmdletBinding()]
param(
    [ValidateSet('Start', 'Stop', 'Status', 'Once', 'Watch')]
    [string]$Action = 'Status',
    [string]$RepositoryPath = '',
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._/-]*$')]
    [string]$Branch = 'main',
    [ValidateRange(5, 3600)]
    [int]$IntervalSeconds = 60,
    [string]$WorkerToken = ''
)

$ErrorActionPreference = 'Stop'
$env:GIT_TERMINAL_PROMPT = '0'
$env:GCM_INTERACTIVE = 'Never'
if (-not $RepositoryPath) { $RepositoryPath = Split-Path -Parent $PSScriptRoot }
$script:Repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
$script:Git = (Get-Command git.exe -ErrorAction Stop).Source
$script:LastMessage = ''

# Quote arguments for Windows PowerShell 5.1 as well as PowerShell 7.
function Quote-Argument([string]$Value) {
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Invoke-Git([string[]]$Arguments, [switch]$AllowFailure) {
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $script:Git
    $info.Arguments = (@('-c', 'credential.interactive=false', '-C', $script:Repo) + $Arguments |
        ForEach-Object { Quote-Argument $_ }) -join ' '
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(45000)) {
            $process.Kill()
            $process.WaitForExit()
            throw 'Git timed out after 45 seconds; the next cycle will retry.'
        }
        $output = ($stdout.Result + $stderr.Result).Trim()
        if ($process.ExitCode -ne 0 -and -not $AllowFailure) {
            throw "Git failed ($($process.ExitCode)): $output"
        }
        return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $output }
    }
    finally { $process.Dispose() }
}

$gitDirectory = (Invoke-Git @('rev-parse', '--absolute-git-dir')).Output
$script:StateDirectory = Join-Path $gitDirectory 'github-sync'
[void][System.IO.Directory]::CreateDirectory($script:StateDirectory)
$script:StateFile = Join-Path $script:StateDirectory 'state.json'
$script:LogFile = Join-Path $script:StateDirectory 'sync.log'
$lockFile = Join-Path $script:StateDirectory 'worker.lock'

function Get-State {
    if (Test-Path -LiteralPath $script:StateFile) {
        try { return Get-Content -LiteralPath $script:StateFile -Raw | ConvertFrom-Json }
        catch { return $null }
    }
    return $null
}

function Get-Worker {
    $state = Get-State
    if ($null -eq $state -or -not $state.WorkerToken) { return $null }
    $worker = Get-CimInstance Win32_Process -Filter "ProcessId = $($state.ProcessId)" -ErrorAction SilentlyContinue
    if ($null -ne $worker -and $worker.CommandLine -and $worker.CommandLine.Contains($state.WorkerToken)) {
        return $state
    }
    return $null
}

function Write-SyncStatus([string]$Message) {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $state = [ordered]@{
        ProcessId = $PID
        WorkerToken = $WorkerToken
        Branch = $Branch
        IntervalSeconds = $IntervalSeconds
        CheckedAt = $timestamp
        Message = $Message
    }
    $temporaryState = "$($script:StateFile).$PID.tmp"
    $state | ConvertTo-Json | Set-Content -LiteralPath $temporaryState -Encoding UTF8
    Move-Item -LiteralPath $temporaryState -Destination $script:StateFile -Force
    if ($Message -ne $script:LastMessage) {
        Add-Content -LiteralPath $script:LogFile -Value "[$timestamp] $Message" -Encoding UTF8
        Write-Host "[$timestamp] $Message"
        $script:LastMessage = $Message
    }
}

function Sync-Repository {
    $current = Invoke-Git @('symbolic-ref', '--quiet', '--short', 'HEAD') -AllowFailure
    if ($current.ExitCode -ne 0 -or $current.Output -ne $Branch) {
        Write-SyncStatus "Paused: switch the local checkout to $Branch to resume."
        return
    }
    $changes = (Invoke-Git @('status', '--porcelain', '--untracked-files=normal')).Output
    if ($changes) {
        Write-SyncStatus 'Paused: local changes found. Commit or stash them to resume; no files were overwritten.'
        return
    }
    [void](Invoke-Git @('fetch', '--quiet', '--no-tags', 'origin', "refs/heads/${Branch}:refs/remotes/origin/$Branch"))
    $local = (Invoke-Git @('rev-parse', 'HEAD')).Output
    $remote = (Invoke-Git @('rev-parse', "refs/remotes/origin/$Branch")).Output
    if ($local -eq $remote) {
        Write-SyncStatus "Up to date: $Branch @ $($local.Substring(0, 7))."
        return
    }
    $ancestor = Invoke-Git @('merge-base', '--is-ancestor', 'HEAD', "refs/remotes/origin/$Branch") -AllowFailure
    if ($ancestor.ExitCode -eq 1) {
        Write-SyncStatus "Paused: local commits differ from origin/$Branch. Resolve them manually; no history was replaced."
        return
    }
    if ($ancestor.ExitCode -ne 0) { throw "Cannot compare Git history: $($ancestor.Output)" }
    [void](Invoke-Git @('merge', '--ff-only', '--no-edit', "refs/remotes/origin/$Branch"))
    Write-SyncStatus "Updated: $Branch @ $($remote.Substring(0, 7)). Restart the game to test the changes."
}

switch ($Action) {
    'Start' {
        if ($null -ne (Get-Worker)) {
            Write-Host 'GitHub synchronization is already running.'
            exit 0
        }
        $token = [guid]::NewGuid().ToString('N')
        $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath,
            '-Action', 'Watch', '-RepositoryPath', $script:Repo, '-Branch', $Branch,
            '-IntervalSeconds', "$IntervalSeconds", '-WorkerToken', $token)
        $worker = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
            -ArgumentList (($arguments | ForEach-Object { Quote-Argument $_ }) -join ' ') -WindowStyle Hidden -PassThru
        for ($attempt = 0; $attempt -lt 30; $attempt++) {
            Start-Sleep -Milliseconds 200
            $state = Get-Worker
            if ($null -ne $state -and $state.WorkerToken -eq $token) {
                Write-Host "GitHub synchronization started: origin/$Branch, every $IntervalSeconds seconds."
                Write-Host "Log: $script:LogFile"
                exit 0
            }
            if ($worker.HasExited) { break }
        }
        throw "Could not confirm startup. See $script:LogFile"
    }
    'Stop' {
        $state = Get-Worker
        if ($null -eq $state) { Write-Host 'GitHub synchronization is stopped.'; exit 0 }
        $stopFile = Join-Path $script:StateDirectory "stop-$($state.WorkerToken)"
        Set-Content -LiteralPath $stopFile -Value 'stop' -Encoding ASCII
        for ($attempt = 0; $attempt -lt 30; $attempt++) {
            Start-Sleep -Milliseconds 200
            if ($null -eq (Get-Worker)) { Write-Host 'GitHub synchronization stopped.'; exit 0 }
        }
        Write-Host 'Stop requested. Synchronization will stop after the current Git operation (up to 45 seconds).'
        exit 0
    }
    'Status' {
        $state = Get-State
        if ($null -ne (Get-Worker)) {
            Write-Host "Running: origin/$($state.Branch), every $($state.IntervalSeconds) seconds."
        }
        else { Write-Host 'GitHub synchronization is stopped.' }
        if ($null -ne $state) { Write-Host "Last check: $($state.CheckedAt). $($state.Message)" }
        Write-Host "Log: $script:LogFile"
        if (Test-Path -LiteralPath $script:LogFile) { Get-Content -LiteralPath $script:LogFile -Tail 8 }
        exit 0
    }
}

try { $lock = [System.IO.File]::Open($lockFile, 'OpenOrCreate', 'ReadWrite', 'None') }
catch { throw 'Another synchronization process already holds the repository lock.' }
try {
    if ($Action -eq 'Once') {
        Sync-Repository
        exit 0
    }
    if (-not $WorkerToken) { $WorkerToken = [guid]::NewGuid().ToString('N') }
    $stopFile = Join-Path $script:StateDirectory "stop-$WorkerToken"
    Write-SyncStatus 'Starting GitHub synchronization.'
    while (-not (Test-Path -LiteralPath $stopFile)) {
        try { Sync-Repository }
        catch { Write-SyncStatus "Retry next cycle: $($_.Exception.Message)" }
        for ($second = 0; $second -lt $IntervalSeconds; $second++) {
            if (Test-Path -LiteralPath $stopFile) { break }
            Start-Sleep -Seconds 1
        }
    }
    Write-SyncStatus 'Synchronization stopped.'
}
finally {
    $lock.Dispose()
    if ($Action -eq 'Watch' -and (Test-Path -LiteralPath $stopFile)) {
        Remove-Item -LiteralPath $stopFile
    }
}
