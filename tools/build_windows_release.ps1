param(
    [string]$GodotExe = "C:\baidunetdiskdownload\Godot_v4.6.1-stable_win64.exe",
    [string]$ProjectDir = "",
    [string]$OutputExe = "",
    [switch]$InstallTemplates,
    [ValidateSet("Windows", "Android")]
    [string]$Target = "Windows"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectDir)) {
    $ProjectDir = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
}

if ([string]::IsNullOrWhiteSpace($OutputExe)) {
    if ($Target -eq "Android") {
        $OutputExe = Join-Path $ProjectDir "build\android\Victoria.apk"
    } else {
        $OutputExe = Join-Path $ProjectDir "build\windows\Victoria.exe"
    }
}

if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot executable not found: $GodotExe"
}

if (-not (Test-Path -LiteralPath (Join-Path $ProjectDir "project.godot"))) {
    throw "Godot project not found: $ProjectDir"
}

$templateVersion = "4.6.1.stable"
$templateRoot = Join-Path $env:APPDATA "Godot\export_templates"
$templateDir = Join-Path $templateRoot $templateVersion

if ($InstallTemplates -and -not (Test-Path -LiteralPath (Join-Path $templateDir "windows_release_x86_64.exe"))) {
    $templateUrl = "https://downloads.godotengine.org/?flavor=stable&platform=templates&slug=export_templates.tpz&version=4.6.1"
    $archivePath = Join-Path $env:TEMP "Godot_v4.6.1-stable_export_templates.tpz"
    $extractDir = Join-Path $env:TEMP "Godot_v4.6.1-stable_export_templates"

    Write-Host "Downloading Godot 4.6.1 export templates. This is about 1.25 GB."
    Invoke-WebRequest -Uri $templateUrl -OutFile $archivePath

    if (Test-Path -LiteralPath $extractDir) {
        Remove-Item -LiteralPath $extractDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractDir -Force

    New-Item -ItemType Directory -Force -Path $templateDir | Out-Null
    Copy-Item -Path (Join-Path $extractDir "templates\*") -Destination $templateDir -Recurse -Force
}

$templateFiles = @()
if (Test-Path -LiteralPath $templateDir) {
    $templateFiles = Get-ChildItem -LiteralPath $templateDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "windows_release*" -or $_.Name -like "windows_debug*" }
}

if ($templateFiles.Count -eq 0) {
    throw "Godot Windows export templates are not installed. Run this script with -InstallTemplates, or open Godot > Editor > Manage Export Templates and install templates for 4.6.1."
}

$openGodotEditors = Get-Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.ProcessName -like "Godot*" -and
        -not [string]::IsNullOrWhiteSpace($_.MainWindowTitle)
    }

if ($openGodotEditors.Count -gt 0) {
    throw "Close the Godot editor for this project before exporting. The Godot LLM GDExtension DLL can stay locked while the editor is open."
}

$outputDir = Split-Path -Parent $OutputExe
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$presetName = "Windows Desktop"
if ($Target -eq "Android") {
    $presetName = "Android APK"
}

& $GodotExe --headless --path $ProjectDir --export-release $presetName $OutputExe
if ($LASTEXITCODE -ne 0) {
    throw "Godot export failed with exit code $LASTEXITCODE"
}

Write-Host "Release build created: $OutputExe"
