# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/drugdamage/glyphwood/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/drugdamage/glyphwood/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/drugdamage/glyphwood/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/drugdamage/glyphwood/releases/tag/v0.2.0
