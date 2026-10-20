# Glyphwood

A gothic action platformer drawn entirely with text characters.

Descend through a graveyard forest, an ossuary and an ashen abyss, procedurally
built levels of rooms with shafts, secret walls, arenas and a merchant, with a
boss at the end of every biome. The descent never ends: after the third boss
the biomes start over, darker and harder, while your hero keeps growing.

- **Simple goal:** a small arrow next to the hero always points to the exit, and
  the minimap marks it with `>`.
- **Checkpoints:** walk past a lantern to light it. If you fall, you wake at the
  last lantern with full health and lose only some shards.
- **Progress that stays:** kills give experience; every level adds health and
  damage for good, levels 10 and 20 open extra charm slots, and the merchant
  sells permanent upgrades. Good for a few minutes or a few hours.
- **Moves:** Triple Cut, Dash Lunge, Rising Crescent, pogo strike, ink knives
  and critical hits (Pause → Moves lists them with your keys).
- Keyboard, mouse and gamepad; every key can be rebound. Every setting explains
  itself when you hover it.
- Seven languages: English, German, Russian, Chinese, Spanish, French, Japanese.

![Glyphwood](docs/gameplay.gif)

## Install and play

**You do not need Godot or anything else.** The game is a ready-to-run program
for Windows, macOS and Linux.

The fastest way is one command, which downloads the latest version, installs it
and starts it (run it again later to update):

- **macOS / Linux** (Terminal):
  ```sh
  curl -fsSL https://raw.githubusercontent.com/drugdamage/glyphwood/main/install.sh | sh
  ```
- **Windows** (PowerShell):
  ```powershell
  irm https://raw.githubusercontent.com/drugdamage/glyphwood/main/install.ps1 | iex
  ```

Or grab the zip for your system from the
[latest release](https://github.com/drugdamage/glyphwood/releases/latest), unzip
it and run the game. If macOS says the app **can't be opened** (it isn't
notarized), right-click it and choose **Open**, or run `xattr -cr Glyphwood.app`
once. The install script does this for you.

Controls are shown in-game as you need them, and all of them are listed (and
can be changed) in **Settings → Controls**. If the game stutters on an older
laptop, set **Settings → Video → Graphics quality** to Low.

## Run from source

Only needed if you want to change the game.

1. Install [Godot 4.5](https://godotengine.org/download) or newer (the standard build, not .NET).
2. Clone this repository: `git clone https://github.com/drugdamage/glyphwood.git`
3. Open `project.godot` in Godot and press **F5**.

See [CONTRIBUTING.md](CONTRIBUTING.md) to add rooms, enemies or translations.

## License

[MIT](LICENSE)
