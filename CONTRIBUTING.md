# Contributing to Glyphwood

Thanks for your interest in Glyphwood! New rooms, enemies, items, sound, bug fixes
and documentation improvements are all welcome. This guide covers running the
project, our code style, and how to send a pull request.

By participating you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting started

1. Install **[Godot 4.5](https://godotengine.org/download)** or newer (the standard
   build, not .NET). CI and releases use **Godot 4.5.1**.
2. Fork and clone the repository:
   ```sh
   git clone https://github.com/<you>/glyphwood.git
   cd glyphwood
   ```
3. Open the project: in the Project Manager choose **Import** and select
   `project.godot`, or run it directly from the command line:
   ```sh
   godot --path .                # run the game
   godot --editor --path .       # open the editor
   ```
4. Press **F5** in the editor to play.

### Useful debug flags

Arguments after `--` are read by `scripts/main.gd`:

```sh
godot --path . -- --play --bot --seed=42 --level=2 --time=10 --shot=out.png
```

| Flag | Effect |
| --- | --- |
| `--play` | Skip the title screen |
| `--bot` | A simple bot plays (useful to test levels) |
| `--god` | The hero takes no damage |
| `--seed=N` | Fixed seed: same level layout every time |
| `--level=N` | Start at level N (two levels per biome; even levels end with a boss) |
| `--boss` | Start next to the boss arena (with an even `--level`) |
| `--zoo` | Spawn one enemy of every type next to the start |
| `--menu=NAME` | Open a menu: `settings`, `inventory`, `map`, `pause`, `shop`, `sell`, `moves`, `skills`, `worlds`, `new_world` |
| `--hero=N` | Start with a hero of level N (N - 1 skill points) |
| `--skills=a,b` | Learn these skill tree nodes at the start, e.g. `quake,edge,edge` |
| `--equip=a,b` | Give and equip these items at the start, e.g. `grave_maul,bone_boomerang` |
| `--tab=N` | Settings tab to open (0 game, 1 video, 2 audio, 3 controls) |
| `--lang=CODE` | Interface language: `en`, `de`, `ru`, `zh`, `es`, `fr`, `ja` |
| `--shot=file.png` | Save a screenshot after `--time` seconds, print frame timings per section, then quit |
| `--time=S` | Delay for `--shot` (default 1 s) |
| `--record=dir` | Save every third frame as PNG into `dir` |
| `--nopost` | Disable the post-processing shader |
| `--uiscale=X` | Interface size for this run, e.g. `1.3` |
| `--uicheck[=X]` | Open every menu in every language (at interface size X) and print text that leaves its panel or the window, then quit |

### Checks to run before a PR

CI runs the same steps on every push and pull request:

```sh
pip install "gdtoolkit==4.*"
gdlint scripts                                   # style / naming lint (.gdlintrc)
godot --headless --path . --import               # must print no SCRIPT ERROR
godot --headless --path . --quit-after 1200 -- --play --bot --seed=1   # smoke test
```

If you change menu or HUD text, also run `godot --path . -- --uicheck=1.3` (it
needs a window): it prints every text that leaves its panel or the window.

## Code style

We follow the official
[GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html),
enforced by `gdlint` with the settings in [`.gdlintrc`](.gdlintrc).

- **Indent with tabs** in `.gd` and `.gdshader` files; LF line endings; UTF-8.
  [`.editorconfig`](.editorconfig) sets this up in most editors.
- **Static typing where possible:** typed function arguments and return values
  (`func hurt_enemy(e: Dictionary, dmg: int, kdir: Vector2) -> void`), and `:=`
  for locals when the type is obvious. Use explicit types when reading from a
  `Dictionary` (`var col: Color = D.ENEMIES[e.kind].color`).
- `snake_case` for functions and variables, `CONSTANT_CASE` for constants,
  `PascalCase` for preloaded scripts (`const Hero := preload(...)`). A leading
  underscore marks private helpers.
- Keep lines under 140 columns.
- Start every script with a `##` doc comment that says what it is for.
- Game objects are plain `Dictionary` records updated by static functions
  (`Hero.update`, `Foes.update`). Keep to this data-oriented style rather than
  introducing nodes per entity.
- Static data lives in its own scripts: world constants, biomes, enemy stats and
  hand-made rooms in `scripts/data.gd`, ASCII art in `scripts/sprites.gd`, items
  in `scripts/items.gd`, the skill tree in `scripts/skills.gd`. Behaviour lives
  in the other scripts.
- Keep every script under 1500 lines (gdlint checks it): drawing helpers that
  grow large move into their own file, like `weapon_art.gd` and `decor_art.gd`.
- Any user-visible text goes into `scripts/strings.gd` (or `scripts/strings_more.gd`
  once the first is full) with **all seven**
  translations (English, German, Russian, Chinese, Spanish, French, Japanese) and is read
  with `L("key")`. If you can't translate, copy the English text and say so in
  the PR.

## How levels are built

`scripts/level.gd` lays out a level as a grid of rooms, each **40 × 24 tiles**.
A path runs from the start room in the top row to the exit (or boss) room in the
bottom row, moving sideways through openings in the walls and down through
shafts in the floor. Path rooms are generated from a floor and ceiling height
line with pits, platforms, secret pockets and decorations; one of them becomes an
arena. Three lanterns (checkpoints) are placed along the path: in the start room,
halfway and in the last room. Rooms next to the path become side rooms: the
merchant, treasure rooms and hand-made **vaults**.

## Adding a vault

Vaults are plain text in `VAULTS` in [`scripts/data.gd`](scripts/data.gd). Each one
is exactly **40 columns × 24 rows**.

| Glyph | Meaning | Glyph | Meaning |
| --- | --- | --- | --- |
| `.` | empty | `C` | chest |
| `#` | solid | `*` | shard cache |
| `=` | one-way platform | `h` | heart |
| `^` | spikes | `T` | torch |
| `~` | water | `e` | biome enemy |
| `%` | cracked wall (breakable) | `b` | bat |

Rules (rows and columns counted from 0):

- Rows 12–18 must be **open at both the left and right edge** (columns 0 and 39),
  and row 19 must be solid at both edges. The room is joined to the path on one
  side; the other side is sealed automatically.
- The hero jumps about **4 tiles up** and **6 tiles across**; every platform you
  want reachable must be reachable without the Feather charm or a dash.
- Chests and enemies stand on the cell above a solid tile.

Add the new array to `VAULTS` with a short `# name` comment, then look at it:

```sh
godot --path . -- --play --seed=7      # try a few seeds and open the map (M)
godot --path . -- --play --bot --god   # watch the bot run through levels
```

Not comfortable with code? Use the **New room** issue form and paste your
40 × 24 vault as text, and we will add it for you.

## Adding an enemy

1. **Stats** – add an entry to `ENEMIES` in `scripts/data.gd`: `size`, `hp`
   (the starting sword deals 10), `speed`, `shards` and `fly`.
2. **Sprite** – add art to `FOES` in `scripts/sprites.gd`: a palette (`pal`), a
   glyph-to-colour map (`cmap`), the centre column (`a`) and lists of frames per
   animation (rows bottom-aligned, facing right; they are mirrored
   automatically).
3. **Behaviour** – add a `"kind":` branch to `Foes.update()` in
   `scripts/foes.gd` and pick its animation in `Foes.frame()`. Use
   `Physics.move()` for collision, `e.state` / `e.t` for a small state machine,
   `g.fire()` to shoot, and respect `e.stun` so hits feel right. Document the
   behaviour in the comment at the top of the file.
4. **Spawning** – add the kind to a biome's `foes` list in `scripts/data.gd`
   (and to the `--zoo` list in `_build_level()` in `scripts/main.gd`).
5. **Telegraphs** – extra visual tells (like the knight's `!`) belong in
   `_draw_enemy()` in `scripts/renderer.gd`.

## Commit messages

We use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(<optional scope>): <short summary in the imperative>
```

| Type | Use for |
| --- | --- |
| `feat` | new gameplay, rooms, enemies, items |
| `fix` | bug fixes |
| `perf` | performance improvements |
| `refactor` | code changes that do not change behaviour |
| `docs` | README, guides, comments |
| `style` | formatting only |
| `test` | tests and test tooling |
| `ci` | GitHub Actions, export presets |
| `chore` | maintenance, project settings |

Examples:

```
feat(rooms): add "chasm" chunk with a one-way bridge
fix(hero): keep the air dash after a wall jump
docs: explain the chunk legend in CONTRIBUTING
```

Mark breaking changes with `!` (`feat!: ...`) or a `BREAKING CHANGE:` footer.

## Pull requests

1. Open an issue first for larger changes (new mechanics, bosses, refactors) so we
   can agree on the approach. Small fixes and new rooms can go straight to a PR.
2. Create a branch from `main` (`feat/spitter-variants`, `fix/wall-jump`).
3. Keep each PR focused on one change. Run the checks above.
4. Add an entry under `## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md) for
   user-visible changes.
5. Include a screenshot or GIF for visual or gameplay changes
   (`--shot` and `--record` help).
6. Fill in the pull request template. A maintainer will review it, and PRs are
   usually squash-merged with a Conventional Commit title.

## Releases (maintainers)

1. Move the `Unreleased` entries in `CHANGELOG.md` into a new version section.
2. Bump `config/version` in `project.godot`.
3. Commit, then tag and push: `git tag v0.5.0 && git push origin v0.5.0`.
4. The **Release** workflow exports all platforms and publishes the GitHub
   release with the changelog section.

## License

By contributing you agree that your contributions are licensed under the
[MIT License](LICENSE).
