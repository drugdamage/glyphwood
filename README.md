# Glyphwood

A gothic action platformer drawn entirely with text characters.

Descend through a graveyard forest, an ossuary and an ashen abyss, three
biomes of procedurally built levels, each a grid of rooms with shafts, secret
walls, arenas, a merchant and a shrine, and fight a boss at the end of every
biome. Collect weapons and charms, spend shards in
the shop, and keep your five hearts as long as you can. Keyboard, mouse and
gamepad; every key can be rebound. Six languages (English, Russian,
Ukrainian, German, Spanish, French).

![Glyphwood](docs/gameplay.gif)

## How to play

Grab the zip for Windows, macOS or Linux from the
[latest release](https://github.com/drugdamage/glyphwood/releases/latest),
unzip it and run the game.

If macOS says the app **can't be opened**, it's because it isn't notarized.
Right-click it and choose **Open**, or run this once in Terminal:

```sh
xattr -cr Glyphwood.app
```

Controls are shown in-game as you need them, and all of them are listed (and
can be changed) in **Settings → Controls**.

## Run from source

1. Install [Godot 4.5](https://godotengine.org/download) or newer (the standard build, not .NET).
2. Clone this repository: `git clone https://github.com/drugdamage/glyphwood.git`
3. Open `project.godot` in Godot and press **F5**.

See [CONTRIBUTING.md](CONTRIBUTING.md) to add rooms, enemies or translations.

## License

[MIT](LICENSE)
