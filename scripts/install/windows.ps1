# Install a pinned Mumble preview. Does not change Windows security policy.
[CmdletBinding()]
param(
    [string]$Destination = (Join-Path $env:LOCALAPPDATA 'Programs\Mumble'),
    [switch]$VerifyOnly
)
$ErrorActionPreference = 'Stop'
$release = 'v0.1.0-preview.2'
$asset = 'Mumble_0.1.0_windows_x64-setup.exe'
$base = "https://github.com/OsirisMedici/Mumble/releases/download/$release"
$architecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
if ($env:OS -ne 'Windows_NT' -or $architecture -ne 'AMD64') {
    throw 'This preview supports Windows x64 on Intel/AMD PCs. Windows ARM64 is not included.'
}
if ($Destination.Contains('"') -or $Destination.Contains("`n") -or $Destination.Contains("`r")) {
    throw 'Invalid installation directory.'
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$work = Join-Path ([IO.Path]::GetTempPath()) ('mumble-install-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $setup = Join-Path $work $asset
    Invoke-WebRequest "$base/$asset" -OutFile $setup -UseBasicParsing
    $manifest = (Invoke-WebRequest "$base/SHA256SUMS-windows-x64.txt" -UseBasicParsing).Content
    $pattern = '(?m)^([a-f0-9]{64})\s+' + [Regex]::Escape($asset) + '\r?$'
    $matchesFound = [Regex]::Matches($manifest, $pattern)
    if ($matchesFound.Count -ne 1) { throw 'Release checksum is missing or ambiguous.' }
    $expected = $matchesFound[0].Groups[1].Value
    if ((Get-FileHash $setup -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
        throw 'Download checksum mismatch. Nothing installed.'
    }
    if ((Get-Item $setup).VersionInfo.ProductName -ne 'Mumble') { throw 'Unexpected installer identity.' }
    if ($VerifyOnly) {
        Write-Output "Verified $release for Windows x64. Nothing installed or launched."
        return
    }
    if (Get-Process 'karen-voice' -ErrorAction SilentlyContinue) { throw 'Quit Mumble before installing.' }
    # NSIS requires /D to be the final argument. It may contain spaces, without quotes.
    $process = Start-Process $setup -ArgumentList "/S /D=$Destination" -PassThru
    if (-not $process.WaitForExit(300000)) { throw 'Installer is still running. Check its window before retrying.' }
    if ($process.ExitCode -ne 0) { throw "Installer exited with $($process.ExitCode)." }
    $exe = Join-Path $Destination 'karen-voice.exe'
    if (-not (Test-Path $exe) -or (Get-Item $exe).VersionInfo.ProductName -ne 'Mumble') {
        throw 'Installed app identity could not be verified.'
    }
    Write-Output "Installed $release at $Destination"
    Write-Output 'Open Mumble, allow desktop microphone access if needed, download a model and choose a shortcut.'
    Write-Output 'Preview builds are unsigned. This script does not bypass SmartScreen or change execution policy.'
} finally {
    Remove-Item $work -Recurse -Force
}
