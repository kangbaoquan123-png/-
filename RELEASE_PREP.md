# Victoria Release Prep

## Windows build

1. Install Godot 4.6.1 export templates:
   Godot > Editor > Manage Export Templates > Install from official release.
   Or run the build script with `-InstallTemplates` to download the official template package automatically.
2. Close the Godot editor before exporting.
   The Godot LLM GDExtension DLL can stay locked while the editor is open.
3. Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_windows_release.ps1
```

If export templates are not installed yet:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_windows_release.ps1 -InstallTemplates
```

The build output is:

```text
build/windows/Victoria.exe
```

## Android build

Run once to install Android command-line tools, SDK packages, and a Godot debug keystore:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\setup_android_export.ps1
```

Then export the test APK:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_windows_release.ps1 -Target Android
```

The APK output is:

```text
build/android/Victoria.apk
```

## Release notes

- The packaged build does not include a default online API key.
- Players enter their own API config from the main menu.
- The local embedding model is included through `models/*.gguf`.
- Development screenshots, logs, and tool scripts are excluded from the Windows preset.
