$ErrorActionPreference = 'Stop'
$work = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { Join-Path ([IO.Path]::GetTempPath()) 'mumble-build' }
New-Item -ItemType Directory -Path $work -Force | Out-Null
function Set-BuildEnvironment([string]$Name, [string]$Value) {
    [Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
    if ($env:GITHUB_ENV) { "$Name=$Value" | Out-File $env:GITHUB_ENV -Append -Encoding utf8 }
}

# Microsoft's CPU runtime avoids the AVX2-only baseline of other prebuilt ORT
# distributions. Pin and verify the official NuGet package before using it.
$version = '1.24.2'
$sha256 = '782564d3d68e87269ea1812cc94710ad06fe014faf093f01a6f89d0bd58719d3'
$package = Join-Path $work 'onnxruntime.zip'
Invoke-WebRequest "https://api.nuget.org/v3-flatcontainer/microsoft.ml.onnxruntime/$version/microsoft.ml.onnxruntime.$version.nupkg" -OutFile $package
if ((Get-FileHash $package -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sha256) {
    throw 'ONNX Runtime package checksum mismatch'
}
$ortRoot = Join-Path $work 'onnxruntime'
Expand-Archive -LiteralPath $package -DestinationPath $ortRoot -Force
$ortLib = Join-Path $ortRoot 'runtimes/win-x64/native'
foreach ($file in @('onnxruntime.dll', 'onnxruntime.lib', 'onnxruntime_providers_shared.dll')) {
    if (-not (Test-Path (Join-Path $ortLib $file))) { throw "Missing ONNX Runtime file: $file" }
}
Set-BuildEnvironment 'ORT_LIB_LOCATION' $ortLib
Set-BuildEnvironment 'ORT_PREFER_DYNAMIC_LINK' '1'

# Include the binary distribution's own legal notices in the installed app.
$notices = 'src-tauri/resources/licenses/onnxruntime'
New-Item -ItemType Directory -Path $notices -Force | Out-Null
Copy-Item (Join-Path $ortRoot 'LICENSE') $notices
Copy-Item (Join-Path $ortRoot 'ThirdPartyNotices.txt') $notices

# Ship the MSVC runtime from the same Visual Studio installation as the build.
$vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
$vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'Visual C++ Build Tools are required' }
$redist = Get-ChildItem (Join-Path $vs 'VC/Redist/MSVC') -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$crt = Get-ChildItem (Join-Path $redist.FullName 'x64') -Directory -Filter '*.CRT' | Select-Object -First 1
if (-not $crt) { throw 'Visual C++ redistributable directory was not found' }
Set-BuildEnvironment 'HANDY_VC_REDIST_DIRS' $crt.FullName

# ggml's Vulkan build needs the CMake package as well as SDK headers/glslc.
vcpkg install spirv-headers:x64-windows
if ($LASTEXITCODE -ne 0) { throw 'SPIRV-Headers installation failed' }
$prefix = "$env:VCPKG_INSTALLATION_ROOT/installed/x64-windows" -replace '\\', '/'
Set-BuildEnvironment 'CMAKE_PREFIX_PATH' $prefix
