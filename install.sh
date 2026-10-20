#!/bin/sh
# Installs (or updates) the latest Glyphwood release on macOS or Linux and starts it.
#   curl -fsSL https://raw.githubusercontent.com/drugdamage/glyphwood/main/install.sh | sh
# Nothing else is needed: the game is a self-contained program, Godot is not required.
set -eu

REPO="drugdamage/glyphwood"
API="https://api.github.com/repos/$REPO/releases/latest"

say() { printf '\033[1;31m::\033[0m %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || die "curl is required"
command -v unzip >/dev/null 2>&1 || die "unzip is required"

case "$(uname -s)" in
	Darwin) platform=macos ;;
	Linux) platform=linux ;;
	*) die "this script supports macOS and Linux; on Windows run install.ps1" ;;
esac

say "Looking up the latest release"
url=$(curl -fsSL "$API" | grep -o "\"browser_download_url\": *\"[^\"]*-$platform\.zip\"" | head -n 1 | sed 's/.*"\(http[^"]*\)"/\1/')
[ -n "$url" ] || die "no $platform build found in the latest release"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
say "Downloading $(basename "$url")"
curl -fL --progress-bar "$url" -o "$tmp/glyphwood.zip"
unzip -q "$tmp/glyphwood.zip" -d "$tmp/out"

if [ "$platform" = macos ]; then
	dest="/Applications"
	[ -w "$dest" ] || dest="$HOME/Applications"
	mkdir -p "$dest"
	app=$(find "$tmp/out" -maxdepth 2 -name '*.app' | head -n 1)
	[ -n "$app" ] || die "Glyphwood.app not found in the download"
	rm -rf "$dest/Glyphwood.app"
	mv "$app" "$dest/Glyphwood.app"
	# The build is not notarized: clear the quarantine flag so it opens normally.
	xattr -cr "$dest/Glyphwood.app" 2>/dev/null || true
	say "Installed to $dest/Glyphwood.app"
	open "$dest/Glyphwood.app"
else
	dest="${XDG_DATA_HOME:-$HOME/.local/share}/glyphwood"
	bin="$HOME/.local/bin"
	apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
	mkdir -p "$dest" "$bin" "$apps"
	cp -R "$tmp/out/." "$dest/"
	chmod +x "$dest/glyphwood.x86_64"
	ln -sf "$dest/glyphwood.x86_64" "$bin/glyphwood"
	curl -fsSL "https://raw.githubusercontent.com/$REPO/main/icon.svg" -o "$dest/icon.svg" || true
	cat > "$apps/glyphwood.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Glyphwood
Comment=A gothic action platformer drawn with text characters
Exec=$dest/glyphwood.x86_64
Icon=$dest/icon.svg
Categories=Game;ActionGame;
Terminal=false
EOF
	say "Installed to $dest (run 'glyphwood' or find it in your app menu)"
	nohup "$dest/glyphwood.x86_64" >/dev/null 2>&1 &
fi
