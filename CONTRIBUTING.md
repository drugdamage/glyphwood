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
| `--bot` | A simple bot plays (useful to test new rooms) |
| `--seed=N` | Fixed RNG seed: same level layout every time |
| `--level=N` | Start at level N (biomes cycle every level) |
| `--shot=file.png` | Save a screenshot after `--time` seconds, then quit |
| `--time=S` | Delay for `--shot` (default 1 s) |
| `--record=dir` | Save every third frame as PNG into `dir` |
| `--lang=ru` | Force the interface language |

### Checks to run before a PR

CI runs the same steps on every push and pull request:

```sh
pip install "gdtoolkit==4.*"
gdlint scripts                                   # style / naming lint (.gdlintrc)
godot --headless --path . --import               # must print no SCRIPT ERROR
godot --headless --path . --quit-after 1200 -- --play --bot --seed=1   # smoke test
```

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
- Static data (rooms, sprites, enemy stats, biomes, strings) lives in
  `scripts/data.gd`; behaviour lives in the other scripts.
- Any user-visible text goes into `D.STRINGS` in **both** `en` and `ru` and is read
  with `L("key")`.

## Adding a room chunk

Rooms are plain text in `CHUNKS` in [`scripts/data.gd`](scripts/data.gd). Each one
is exactly **30 columns × 20 rows**.

| Glyph | Meaning | Glyph | Meaning |
| --- | --- | --- | --- |
| `.` | empty | `c` | crawler |
| `#` | solid | `b` | bat |
| `=` | one-way platform | `k` | knight |
| `^` | spikes | `s` | spitter |
| `h` | heart pickup | `e` | random ground enemy |

`P` (player start) and `D` (exit door) are used only by the start and end chunks.

Rules so that any chunk can follow any other:

- Rows 0–1 are solid ceiling, rows 16–19 are the floor (spike pits may cut into
  rows 16–17).
- Rows 2–15 must be **open at both the left and right edge** (column 0 and 29).
- The hero jumps about **4 tiles up** and **6 tiles across**; every gap must be
  passable without a dash.
- Place ground enemies (`c`, `k`, `s`, `e`) on the row directly above a solid
  surface. Bats (`b`) can float anywhere.

Add the new array to `CHUNKS` with a short `# name` comment, then test it:

```sh
godot --path . -- --play --seed=7      # try several seeds until your room appears
godot --path . -- --play --bot         # watch the bot run through it
```

Not comfortable with code? Use the **New room** issue form and paste your
30×20 room as text, and we will add it for you.

## Adding an enemy

1. **Stats and sprite** – add an entry to `ENEMIES` in `scripts/data.gd`: `size`,
   `hp`, `speed`, `color` and `frames` (lists of lines, bottom-aligned, facing
   right; they are mirrored automatically). Extra frames for special states (like
   the knight's `lunge`) go in the same dictionary.
2. **Behaviour** – add a `"kind":` branch to `Foes.update()` in
   `scripts/foes.gd`. Use `Physics.move()` for collision, `e.state` / `e.t` for a
   small state machine, `g.fire()` to shoot, and respect `e.stun` so hits feel
   right. Document the behaviour in the comment at the top of the file.
3. **Special frames** – if the enemy has state-specific frames, return them from
   `Foes.frame()`.
4. **Knockback** – if it should react differently to hits, adjust
   `hurt_enemy()` in `scripts/main.gd`.
5. **Spawning** – give it a letter in `Level.build()` (`scripts/level.gd`),
   document the letter in the chunk legend in `data.gd`, `README.md` and this
   file, and place it in at least one room.
6. **Telegraphs** – extra visual tells (like the knight's `!`) belong in
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
3. Commit, then tag and push: `git tag v0.3.0 && git push origin v0.3.0`.
4. The **Release** workflow exports all platforms and publishes the GitHub
   release with the changelog section; **Pages** updates the browser build.

## License

By contributing you agree that your contributions are licensed under the
[MIT License](LICENSE).
