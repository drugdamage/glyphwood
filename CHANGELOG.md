# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.2] - 2026-10-20

### Changed

- The aiming crosshair is now the system cursor: the OS draws it at the
  display's refresh rate with no lag, so it moves as smoothly as the desktop
  cursor at any frame rate.
- The frame rate limit no longer turns V-Sync off by itself; its tip says that
  with V-Sync on the display's refresh rate is the most you get.

## [0.6.1] - 2026-10-20

### Changed

- While you play in a window the cursor stays inside it (and stays hidden
  when it aims), so a click can no longer land on the desktop or another app.
  Pause and the other menus set it free.
- Switching to another app pauses the game.
- Raising the frame rate limit above the display's refresh rate, or to
  Unlimited, turns V-Sync off and says so: V-Sync held frames at the refresh
  rate, so the limit did nothing. The setting's tip explains this.

### Fixed

- Long slider values such as "Unlimited" no longer overlap the bar; slider
  values share one column so the bars line up.

## [0.6.0] - 2026-10-20

### Added

- **Name your world.** New world opens with the name field ready: type any name
  (up to 20 characters), Backspace erases, Enter or Tab moves on. The game no
  longer suggests names; every new world still gets its own layout.
- **Boss stagger.** Each time a boss loses a quarter of its health it stands
  dazed for 1.8 seconds, takes 50% more damage and drops a health orb.

### Changed

- **Performance.** On macOS the game renders through Metal instead of OpenGL,
  which roughly doubles the frame rate and cuts power use. The game now steps
  as often as frames are shown (60 to 240 times a second, following the frame
  limit, V-Sync and the display), so high frame rates are really smooth instead
  of repeating 60 Hz positions.
- **Balance.** Bosses have about 30% less health (Moss Warden 360, Bell Wraith
  440, Ember Colossus 560); each hero level adds 6% damage instead of 4%; ink
  knives hit for twice the blade's damage instead of 1.2×.
- The blood moon is angrier: a burning slit eye in its skull follows the hero
  and blinks under a scowling brow, blood drips from its rim and its halo
  throbs like a heartbeat.

### Fixed

- The bat crossing the moon printed an error every frame instead of drawing.

## [0.5.0] - 2026-10-20

### Added

- **Worlds.** Keep up to five worlds, each with its own hero, layout and
  difficulty. The title screen continues the last one you played; **Worlds**
  lists them all (play or delete), and **New world** picks a name (each name is
  a new layout) and a difficulty. Your 0.4 save becomes the first world.
- **Difficulty:** Easy, Normal, Hard and Nightmare change enemy damage and
  health, how many shards a fall costs (15%, 30%, 50%, all) and the experience
  you earn (up to +50%).
- Number settings move one unit at a time: volumes, screen shake and interface
  size by 1%, the frame limit by 1 FPS from 30 to 360 (then no limit). Holding
  ←/→ speeds up, Shift moves by 10, and slider bars can be dragged with the
  mouse.

### Changed

- Gothic HUD: health is a blade of dark blood with iron rivets and a pale trail,
  beside a pierced heart that beats faster and bleeds as health runs out;
  experience is tarnished gold and ink is a row of small blades.
- The moon is a blood moon with an eclipse shadow, craters, cracks, drifting
  black clouds and the odd bat.
- Menus fit their text: long labels shrink, descriptions wrap, and panels grow
  with their content, so nothing runs past a panel or the window in any language
  or interface size.
- The version number on the title screen moved to the bottom left, so the FPS
  counter no longer covers it.
- Changing a setting only applies that setting; volume and shake no longer
  redraw the whole level.

### Fixed

- Background glyphs of the previous level could be drawn once more right after
  a new level was built.

## [0.4.0] - 2026-10-20

### Added

- **Endless descent.** After the third boss the biomes start over with tougher
  enemies; there is no final screen any more.
- **Lanterns** (checkpoints) in the start room, halfway along the level and
  before the exit or boss. Falling sends you back to the last one you lit with
  full health; you lose 30% of the shards you carry and keep everything else.
  The death screen and starting over are gone.
- **Hero levels.** Kills give experience (more during long combos); each level
  adds 6 health and 4% damage for good, levels 10 and 20 add a charm slot.
- **Moves:** Triple Cut (the third cut lunges, hits 2.2× and breaks shields),
  Dash Lunge (attack during a dash, pierces a line of enemies) and Rising
  Crescent (up + attack on the ground, launches enemies). Critical hits (8%
  base) freeze the frame with a flash and a ring of sparks. A combo counter
  shows chained hits. Pause → Moves lists every move with your keys.
- **Guidance:** an arrow next to the hero points to the exit or the boss, and
  the HUD shows the current goal.
- Merchant upgrades: Mend (full health), Vigor (+10 max health) and Whetstone
  (+5% damage), bought again and again at rising prices.
- A **Graphics quality** setting (Low / Medium / High) and a **Path arrow**
  toggle.
- Every setting shows an explanation when hovered or selected.
- Chinese and Japanese (system fonts are used for their glyphs).
- `install.sh` (macOS, Linux) and `install.ps1` (Windows): one command downloads,
  installs and starts the latest release; Godot is never needed to play.

### Changed

- **Health** is a number (100 to start) shown as a bar with a damage trail, and
  it comes back by itself after a few seconds without being hit. Enemies hit
  harder the deeper you go. Healing flasks, the heal key and shrines are gone;
  killed enemies sometimes drop health orbs.
- The ink bar is labelled with its key; a new experience bar sits under health.
- Scarier enemies: corpse rats, ghouls with glowing eyes, fanged bats, a maw
  totem, screaming skull wisps, and the first boss is now **the Gravemaw**, a
  skull-headed beast (it replaces the antlered Wendigo). Enemies' eyes cast a
  faint light.
- The minimap is a picture of the explored terrain with lanterns, merchant,
  chests, exit and boss; the full map uses it too.
- Inventory and shop show detailed glyph icons; the bag is a grid.
- Rock is shaded by depth with things buried in it.
- Languages: English, German, Russian, Chinese, Spanish, French, Japanese
  (Ukrainian was removed).
- The macOS app icon has the standard margin, so it is no longer larger than
  other icons in the Dock.

### Performance

- The parallax background is split into buckets and only the visible ones are
  drawn (before, every background glyph of the whole level was submitted each
  frame). Together with sparser deep rock this roughly halves the primitives per
  frame.
- The glow uses 8 texture reads instead of 16, and turned-off glow or lighting
  no longer costs anything in the post-process shader.

## [0.3.1] - 2026-10-20

### Fixed

- Crash in the renderer after dashing, jumping or opening the inventory a few
  times: a frame drew more glyphs than the renderer's item buffer holds, and
  overflowing it crashes Godot 4.5's Compatibility renderer. The buffer is now
  large enough for every frame.
- Wall jump: holding toward the wall now jumps up along it instead of throwing
  you the other way; otherwise you kick off the wall, with a shorter input lock.

### Changed

- The hero, black knights and skeletons are drawn with smaller glyphs at a
  higher level of detail (nine rows instead of five or six).
- New application icon: the dripping G from the title logo.

## [0.3.0] - 2026-10-19

### Added

- **Bigger levels:** each level is a grid of rooms (up to 5 × 3) with a path from
  the top row to the exit, drops through shafts in the floor, side rooms (merchant,
  shrine, treasure rooms, hand-made vaults), arena rooms that lock until every
  wave is beaten, and secret pockets behind cracked walls.
- **Bosses:** Moss Warden, Bell Wraith and Ember Colossus guard the end of each
  biome, each with its own attacks and a faster second phase. Beating the third
  one wins the run; you can then keep going into endless, harder levels.
- **Inventory and equipment:** five weapons and thirteen charms (double jump,
  dash through enemies, lifesteal, thorns, more shards...). Find them in chests,
  buy them from the merchant, or take them from bosses.
- **Ink knives:** sword hits fill an ink bar that is spent on thrown knives.
- **Five new enemies:** imp (hops at you), skeleton with a tower shield
  (blocks frontal hits), lost soul (drifts through walls), skeleton archer
  (lobs arrows) and bloated corpse (explodes). Elite variants with
  double health and more shards.
- **Water and lava**, swimming, arena gates and breakable walls.
- **Menus:** title screen with Continue, pause menu, and Settings with Game,
  Video (display mode, V-Sync, frame rate limit, camera distance, lighting,
  glow, scanlines, vignette, interface size, FPS counter), Audio (master, music,
  effects, ambience) and Controls tabs.
- **Rebindable controls** with two slots per action, mouse support (attack,
  dash and knives aim at the cursor) and gamepad support.
- **Tutorial hints** at the top of the screen that show your current keys and
  disappear once you have done the thing; they can be reset or turned off.
- **Sound and music:** every effect, the music for each biome and the boss,
  and ambient loops are synthesised in-game.
- **Map** (`M`) and a minimap of explored rooms.
- **Saving:** the run is saved at the start of each level; Continue resumes it.
  The title screen shows your runs, wins and deepest level.
- Ukrainian, German, Spanish and French translations.
- Debug flags `--god`, `--boss`, `--zoo`, `--menu=`, `--tab=` and `--nopost`.

### Changed

- **Gothic look:** a horned knight in a crimson cloak; plague rats, imps,
  gargoyles, black knights, skeletons and lost souls; Gravewood with graves,
  crosses, dead trees and ruined spires under a blood moon, the Ossuary with
  bone-coloured masonry, candles and pools of blood, and the Ashen Abyss. New
  title logo, menu colours, darker music, and the Wendigo as the first boss.
- **Visuals:** everything is drawn on a finer grid of smaller glyphs (four by
  three per tile): textured ground, masonry and back walls in caves, swaying
  grass and vines, lanterns and torches, animated water and lava, multi-colour
  sprites with outlines, parallax forests, ruins and lava falls, a moonlit sky,
  and dynamic coloured lighting.
- The dash no longer makes you invulnerable (the Phantom Step charm does), so
  enemies have to be fought rather than dashed through.
- Damage numbers, enemy health pips, crits and burning.
- Static terrain is cached in chunks and drawn in a few batched draw calls;
  new chunks are painted ahead of the camera, one per frame.
- Music and ambience are synthesised on a background thread, so there are no
  hitches while they are prepared.
- Shorter README.

### Fixed

- The application icon was blank because it was drawn with SVG text, which
  Godot does not render.

### Removed

- The browser (Web) build and its GitHub Pages deployment.

## [0.2.0] - 2026-10-18

First public release.

### Added

- **Movement:** run, variable-height jump, coyote time and jump buffering, dash with
  invulnerability frames (one air dash, refreshed on landing, wall jump and pogo),
  wall slide and wall jump, drop through one-way platforms.
- **Combat:** three-hit side combo (the third hit deals double damage), up slash,
  down slash that pogos off enemies, projectiles and spikes, hit-stop, screen shake
  and knockback.
- **Enemies:** crawler (patrols ledges), bat (hovers, then chases), knight
  (telegraphs with `!` and lunges), spitter (fires projectiles that can be slashed).
  Enemy health scales with depth.
- **Roguelite runs:** every level is assembled from hand-made 30×20 text chunks, so
  each run is different; levels get longer as you go deeper; permadeath with a run
  summary (depth, kills, shards, time).
- **Three biomes** that cycle with depth: Glyphwood, The Hollows and Ember Depths.
- **Items:** healing flasks (2 per run), heart pickups, collectible shards dropped
  by enemies.
- **ASCII presentation:** everything is drawn with text glyphs: parallax
  background, grass that bends around the hero, a trailing scarf, death particles
  made of the sprite's own characters, and a glow/scanline/vignette post-process
  shader that can be toggled with `G`.
- **Interface:** title, pause and death screens; zoom levels (`+` / `-`);
  fullscreen (`F`); English and Russian UI, switchable with `L`.
- **Debug options:** `--play`, `--bot`, `--seed`, `--level`, `--shot`, `--time`,
  `--record`, `--lang` command-line flags for testing and capturing media.
- **Builds:** Windows, Linux, macOS (universal) and Web exports via GitHub Actions;
  the Web build is playable on GitHub Pages.
- Bundled DejaVu Sans Mono font, used in the Web build (where system fonts are
  unavailable) and as a fallback for glyphs missing from the system font.

[Unreleased]: https://github.com/drugdamage/glyphwood/compare/v0.6.2...HEAD
[0.6.2]: https://github.com/drugdamage/glyphwood/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/drugdamage/glyphwood/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/drugdamage/glyphwood/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/drugdamage/glyphwood/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/drugdamage/glyphwood/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/drugdamage/glyphwood/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/drugdamage/glyphwood/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/drugdamage/glyphwood/releases/tag/v0.2.0
