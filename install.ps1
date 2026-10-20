# Installs (or updates) the latest Glyphwood release on Windows and starts it.
#   irm https://raw.githubusercontent.com/drugdamage/glyphwood/main/install.ps1 | iex
# Nothing else is needed: the game is a self-contained program, Godot is not required.
$ErrorActionPreference = "Stop"
$repo = "drugdamage/glyphwood"

Write-Host ":: Looking up the latest release" -ForegroundColor Red
$release = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest"
$asset = $release.assets | Where-Object { $_.name -like "*-windows.zip" } | Select-Object -First 1
if (-not $asset) { throw "No Windows build found in the latest release" }

$dest = Join-Path $env:LOCALAPPDATA "Programs\Glyphwood"
$zip = Join-Path $env:TEMP "glyphwood.zip"
Write-Host ":: Downloading $($asset.name)" -ForegroundColor Red
Invoke-WebRequest $asset.browser_download_url -OutFile $zip -UseBasicParsing
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Expand-Archive $zip -DestinationPath $dest -Force
Remove-Item $zip
# Files from the internet are flagged; clear it so Windows does not block the game.
Get-ChildItem $dest -Recurse | Unblock-File

# Start menu and desktop shortcuts
$exe = Join-Path $dest "Glyphwood.exe"
$shell = New-Object -ComObject WScript.Shell
foreach ($dir in @([Environment]::GetFolderPath("Programs"), [Environment]::GetFolderPath("Desktop"))) {
	$lnk = $shell.CreateShortcut((Join-Path $dir "Glyphwood.lnk"))
	$lnk.TargetPath = $exe
	$lnk.WorkingDirectory = $dest
	$lnk.Save()
}

Write-Host ":: Installed to $dest (shortcuts on the desktop and in the Start menu)" -ForegroundColor Red
Start-Process $exe
