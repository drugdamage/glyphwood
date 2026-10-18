# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/drugdamage/glyphwood/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/drugdamage/glyphwood/releases/tag/v0.2.0
