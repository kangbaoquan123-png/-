param(
    [string]$SdkDir = "C:\Android\Sdk",
    [string]$JdkBin = "C:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot\bin",
    [string]$CommandLineToolsUrl = "https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip"
)

$ErrorActionPreference = "Stop"

$downloadDir = "C:\baidunetdiskdownload\android-sdk-download"
$toolsZip = Join-Path $downloadDir "commandlinetools-win_latest.zip"
$extractDir = Join-Path $downloadDir "extract"
$cmdlineToolsDir = Join-Path $SdkDir "cmdline-tools"
$latestDir = Join-Path $cmdlineToolsDir "latest"
$keystoreDir = Join-Path $env:APPDATA "Godot\keystores"
$debugKeystore = Join-Path $keystoreDir "debug.keystore"

New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null
New-Item -ItemType Directory -Force -Path $SdkDir | Out-Null

if (-not (Test-Path -LiteralPath $toolsZip)) {
    curl.exe -L --fail --retry 5 --retry-delay 5 -o $toolsZip $CommandLineToolsUrl
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to download Android command-line tools."
    }
}

if (Test-Path -LiteralPath $extractDir) {
    Remove-Item -LiteralPath $extractDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
Expand-Archive -LiteralPath $toolsZip -DestinationPath $extractDir -Force

if (Test-Path -LiteralPath $latestDir) {
    Remove-Item -LiteralPath $latestDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $cmdlineToolsDir | Out-Null
Move-Item -LiteralPath (Join-Path $extractDir "cmdline-tools") -Destination $latestDir

$sdkManager = Join-Path $latestDir "bin\sdkmanager.bat"
if (-not (Test-Path -LiteralPath $sdkManager)) {
    throw "sdkmanager was not found after extracting command-line tools."
}

$env:ANDROID_SDK_ROOT = $SdkDir
$env:ANDROID_HOME = $SdkDir
$env:Path = "$JdkBin;$($env:Path)"

$licensesDir = Join-Path $SdkDir "licenses"
New-Item -ItemType Directory -Force -Path $licensesDir | Out-Null
Set-Content -Path (Join-Path $licensesDir "android-sdk-license") -Encoding ASCII -Value @(
    "24333f8a63b6825ea9c5514f83c2829b004d1fee",
    "8933bad161af4178b1185d1a37fbf41ea5269c55",
    "d56f5187479451eabf01fb78af6dfcb131a6481e"
)
Set-Content -Path (Join-Path $licensesDir "android-sdk-preview-license") -Encoding ASCII -Value "84831b9409646a918e30573bab4c9c91346d8abd"

& $sdkManager --sdk_root=$SdkDir "platform-tools" "build-tools;35.0.1" "platforms;android-35"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to install Android SDK packages."
}

New-Item -ItemType Directory -Force -Path $keystoreDir | Out-Null
if (-not (Test-Path -LiteralPath $debugKeystore)) {
    $keytool = Join-Path $JdkBin "keytool.exe"
    & $keytool -genkeypair -v -keystore $debugKeystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create Godot debug keystore."
    }
}

Write-Host "Android export environment ready."
Write-Host "SDK: $SdkDir"
Write-Host "Debug keystore: $debugKeystore"
