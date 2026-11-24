$ErrorActionPreference = 'Stop'
$target = 'x86_64-pc-windows-msvc'
$python = (Get-Command python -ErrorAction Stop).Source
$version = (Get-Content src-tauri/tauri.conf.json -Raw | ConvertFrom-Json).version
$installers = @(Get-ChildItem "src-tauri/target/$target/release/bundle/nsis/*-setup.exe")
if ($installers.Count -ne 1) { throw 'Expected exactly one Windows installer' }
$setup = $installers[0]
New-Item -ItemType Directory -Path release-assets, windows-evidence -Force | Out-Null

function Install-Mumble([string]$Destination, [bool]$Portable) {
    $arguments = if ($Portable) { "/S /PORTABLE /D=$Destination" } else { "/S /D=$Destination" }
    $process = Start-Process $setup.FullName -ArgumentList $arguments -PassThru
    if (-not $process.WaitForExit(180000)) { $process.Kill(); throw 'Installer timed out' }
    if ($process.ExitCode -ne 0) { throw "Installer exited with $($process.ExitCode)" }
    foreach ($file in @(
        'karen-voice.exe', 'onnxruntime.dll', 'onnxruntime_providers_shared.dll',
        'msvcp140.dll', 'vcruntime140.dll',
        'resources/licenses/LICENSE', 'resources/licenses/THIRD_PARTY_NOTICES.md',
        'resources/licenses/onnxruntime/LICENSE', 'resources/licenses/onnxruntime/ThirdPartyNotices.txt'
    )) {
        if (-not (Test-Path (Join-Path $Destination $file))) { throw "Installer omitted $file" }
    }
    foreach ($pattern in @('*transcribe*.dll', '*ggml*cpu*.dll', '*ggml*vulkan*.dll')) {
        if (-not (Get-ChildItem $Destination -Filter $pattern)) { throw "Missing runtime: $pattern" }
    }
    $exe = Join-Path $Destination 'karen-voice.exe'
    if ((Get-Item $exe).VersionInfo.ProductName -ne 'Mumble') { throw 'Wrong Windows product identity' }
    return $exe
}

$normal = Join-Path $env:RUNNER_TEMP 'Mumble-installed'
$normalExe = Install-Mumble $normal $false
if (-not (Test-Path "$normal/uninstall.exe")) { throw 'Normal install has no uninstaller' }
$portable = Join-Path $env:RUNNER_TEMP 'portable/Mumble'
$portableExe = Install-Mumble $portable $true
if ((Get-Content "$portable/portable" -Raw).Trim() -ne 'Karen Voice Portable Mode') {
    throw 'Portable installer and runtime disagree about the marker'
}
if (Test-Path "$portable/uninstall.exe") { throw 'Portable install should not create an uninstaller' }

# Archive the fresh portable install before adding any verification models/data.
Copy-Item $setup.FullName "release-assets/Mumble_${version}_windows_x64-setup.exe"
Compress-Archive -Path $portable -DestinationPath "release-assets/Mumble_${version}_windows_x64_portable.zip"
Copy-Item LICENSE, THIRD_PARTY_NOTICES.md release-assets/

# Use installed files, not build-directory dependencies, for every runtime check.
$env:PATH = "$env:SystemRoot/system32;$env:SystemRoot;$env:SystemRoot/System32/WindowsPowerShell/v1.0"
$env:ORT_LIB_LOCATION = $null
$env:ORT_PREFER_DYNAMIC_LINK = $null
$env:VULKAN_SDK = $null
if (-not (Test-Path $python)) { throw 'Python runtime was not found' }

# A bounded process launch catches native startup failures. It does not establish
# microphone, shortcut or paste acceptance on a user's Windows desktop.
$app = Start-Process $normalExe -ArgumentList '--start-hidden' -PassThru
Start-Sleep -Seconds 8
try {
    $app.Refresh()
    if ($app.HasExited) { throw "Installed GUI process exited early: $($app.ExitCode)" }
} finally {
    if (-not $app.HasExited) { Stop-Process -Id $app.Id -Force }
}

$modelDir = Join-Path $portable 'Data/models'
New-Item -ItemType Directory -Path $modelDir -Force | Out-Null
$model = Join-Path $modelDir 'parakeet-tdt-0.6b-v3-Q8_0.gguf'
Invoke-WebRequest 'https://blob.handy.computer/handy-computer/parakeet-tdt-0.6b-v3-gguf/85ac09ea12fc4b1112fa76810059364bc6adc9de/parakeet-tdt-0.6b-v3-Q8_0.gguf' -OutFile $model -TimeoutSec 900
if ((Get-FileHash $model -Algorithm SHA256).Hash.ToLowerInvariant() -ne '5859f77944efcd8eafa23a6350731960b2b55b2203df51f319665c807d802cc7') {
    throw 'Speech model checksum mismatch'
}
@{ settings = @{ number_formatting_enabled = $true; email_formatting_enabled = $true } } |
    ConvertTo-Json -Depth 4 | Set-Content "$portable/Data/settings_store.json" -Encoding utf8NoBOM
$audio = Join-Path $env:RUNNER_TEMP 'mumble-speech.wav'
powershell.exe -NoProfile -File scripts/ci/generate-windows-speech.ps1 -OutputPath $audio
if ($LASTEXITCODE -ne 0) { throw 'Speech generation failed' }
& $python scripts/verify-built-transcription.py $portableExe $audio
if ($LASTEXITCODE -ne 0) { throw 'Installed app failed speech recognition' }
$result = Get-Content transcription-result.json -Raw | ConvertFrom-Json
if ($result.text -notmatch '25 chairs' -or $result.text -notmatch 'john@gmail\.com') {
    throw "Spoken-number/email verification failed: $($result.text)"
}
Copy-Item transcription-result.json windows-evidence/

$verification = @{
    source_revision = $env:GITHUB_SHA
    platform = $target
    normal_install = 'passed'
    portable_install = 'passed'
    native_startup = 'passed'
    generated_speech = $result.text
    microphone_shortcuts_paste = 'manual acceptance pending'
    windows_arm64 = 'not included'
    authenticode_signed = $false
    binary_sha256 = (Get-FileHash $portableExe -Algorithm SHA256).Hash.ToLowerInvariant()
}
$verification | ConvertTo-Json -Depth 4 | Set-Content windows-evidence/verification.json -Encoding utf8NoBOM
$verification | ConvertTo-Json -Depth 4 | Set-Content release-assets/Windows-verification.json -Encoding utf8NoBOM
Get-ChildItem release-assets -File | Where-Object { $_.Name -notlike 'SHA256SUMS*' } | Sort-Object Name | ForEach-Object {
    "$((Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())  $($_.Name)"
} | Set-Content release-assets/SHA256SUMS-windows-x64.txt -Encoding ascii
