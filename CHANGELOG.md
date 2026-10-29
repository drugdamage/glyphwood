# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.13.0] - 2026-10-29

### Added

- **The skill tree splits into paths.** Each branch now has a trunk of
  three tiers (Iron Hide, Quake or Shoulder Charge, Last Stand for the
  bulwark) and then splits into two paths of four nodes, side by side.
  Taking the first node of a path seals the other path of that branch, the
  way a fork does. A full branch still costs seven points.
  - **Bulwark:** the **Guardian** (Bastion, Aegis, Vengeance, Unbreakable)
    soaks up blows; the **Warlord** (Heavy Mastery, Juggernaut, Rend,
    Titan) hits with a heavy weapon.
  - **Alchemist:** the **Poisoner** (Hex, Quicksilver, Venom Glass, Pyre)
    burns; the **Knife Thrower** (Light Mastery, Blade Storm, Finishing
    Throw, Philosopher's Stone) throws harder. Siphon is in the trunk.
  - **Shade:** the **Duelist** (Blade Mastery, Iaido, Hemorrhage, Dance of
    Death) crits; the **Assassin** (Long Lunge, Shadow Step, Evasion,
    Ambush) strikes first and is hard to hit. Reaper is in the trunk.
- Six new skills:
  - **Aegis** (Guardian): a ward of 20 % of maximum health soaks up blows
    before health does. It fills again, even mid-fight, after 3 seconds
    without being hit, and shows as a pale line under the health blade.
  - **Unbreakable** (Guardian): the parry window is half again as long; a
    parry refills the ward, a block refills half of it.
  - **Finishing Throw** (Knife Thrower): thrown weapons deal 80 % more
    damage to foes below a third of their health.
  - **Pyre** (Poisoner): a foe that dies burning bursts into flame; foes
    nearby catch fire and take half a blow (and may burst in turn).
  - **Evasion** (Assassin): a 15 % chance to slip any blow (not spikes).
  - **Ambush** (Assassin): the first blow on an unhurt foe deals 2.5 times
    the damage (not bosses).
- `--browse` takes `.` to wait a step, for recordings.

### Changed

- **Titan** belongs to the Warlord now: +20 % damage and +10 % reach with
  heavy weapons (was +15 % and 10 % less damage taken).
- Last Stand, Siphon and Reaper moved into the trunks, so every build of
  their branch can take them.
- A save from before the paths keeps the path with more points in each
  branch; points of skills the new tree no longer allows come back, and a
  message says how many.
- The skill tree names each path above it and puts the branch name between
  the two paths; the help text explains paths.
- Armour shows **Run speed** instead of just "Speed", so it is not mixed
  up with attack speed.
- The gameplay GIF shows the new tree: learning the Guardian path.

### Fixed

- The merchant's Haste said "running speed +0%": it showed what was
  already bought, not what you buy. It now reads "Haste +5% running speed ·
  Bought 0 of 6 · for good", like Vigor and the Whetstone.
- In full screen the skill tree's labels sat on other text: the Alchemist
  name ran into the title, the rank numbers of Vitality and Keen Edge sat
  on their selection ring and the core's edge, and the middle branch's
  first node sat on the core's lid. The tree has a row for path names, a
  lower lid and a taller core now, so nothing overlaps.

## [0.12.1] - 2026-10-25

### Changed

- The app icon is the G of the title logo, drawn the same way, and sits on
  a tile with the usual margin so it is no bigger than other icons.
- Interface size goes up to 125 % (was 150 %), and the window can't be made
  smaller than 960 × 600.
- A short README; the gameplay GIF now shows several biomes, the inventory,
  the skill tree, buying in the shop and a boss fight.

### Fixed

- With a big interface in a small window the inventory, the skill tree,
  the pause menu, the world list and the moves page were cut off or
  squeezed; they now shrink to fit the screen. The skill tree gives its
  tiers more room.

## [0.12.0] - 2026-10-25

### Changed

- **Glyphwood is now drawn in pixels.** The text picture is gone: the whole
  game is small, grimy pixels in the spirit of White Knuckle, from the world
  to the HUD, the inventory and every menu. The game is drawn at a low
  resolution and blown up without smoothing, then graded dark (bruised violet
  in the shade, a sickly warm in the light), cut to a few colours with an
  ordered dither and roughened by a faint grain. It runs faster than the text
  picture did (about 500 frames a second instead of 300–400 on the same Mac
  with V-Sync off).
  - The hero, every foe and every boss are hand-drawn pixel sprites with a
    dark outline: a horned knight in blackened steel and a tattered crimson
    cloak, a corpse rat with its spine through the skin, a ghoul, skeletons
    with shields and bows, a black knight, a penitent with a scourge of
    hooks, the Gravemaw's ribs and skull, the Wraith's hood, the Colossus's
    molten core and the rest. Foes die in a burst of their own pixels.
  - Rock, brick, ledges, spikes and back walls are pixel textures; lanterns,
    chests, the merchant, lore stones, the exit arch, torches, graves,
    candles, pews, reeds and the other decorations are small pixel pictures;
    chains, vines, roots, banners, webs, icicles, grass, water, lava and
    gates are drawn pixel by pixel.
  - The backdrop is pixel shapes: a mountain ridge with ruined chapels, bare
    crooked trees, cave teeth, lava falls, and pillars with hanging chains.
  - Every weapon has pixel art of its own, held in a fist at the end of an
    arm that swings with every cut, and its icon is the same picture: a
    notched rusty sword, a curved saber with glowing glyphs, a black
    greatsword with a red vein, a spear with a hollow leaf head, a black
    flamberge with a molten edge, a tombstone on a haft, a curved spider
    fang, a katana with a red edge, a cross-hilted sword with prayer beads, a
    blade of ice with icicles, a long blade with a blood-red fuller and
    quillons swept like a bat's wings, a bone scythe
    with a skull, a halberd with a bronze bell and a headsman's axe with a
    cross cut through it. They turn in steps of their own pixels, so they
    stay crisp at every angle; heavy weapons are held upright before the body
    instead of over the face, swords point forward and down, and a weapon at
    rest stays still instead of flicking up and down as the hero walks.
  - Armour changes the hero's shape, not only its colour: the Pilgrim's Hood
    is a pointed cowl with the face in shadow, the Iron Sallet is now the
    **Iron Helm**, a pointed helm with a nasal bar, the Plague Mask a beaked
    mask under a dark hood; the Gambeson is quilted, the Chain Hauberk is
    mail under a crimson surcoat and the Cathedral Plate a ridged
    breastplate with faulds. Without a helmet the hero wears a lower,
    rounder horned helm.
  - Every item picture is pixel art: helmets and body armour as they are
    worn, boots, thrown weapons, every charm and the merchant's services.
  - Blocking raises a crimson heater shield with a pale bend across it; its
    rim burns gold while a blow would still be parried.
  - The guide dagger is drawn in pixels too.
  - Sword swings are crescents of short pixel strokes along the arc, thin
    and faint at the tail, thick and bright at the head, like the glyphs of
    the text picture; thrown weapons, bolts, fire pillars, warnings, foes'
    health bars, the scarf and every spark and shard are pixels too.
  - Text in the HUD and menus is crisp, without smoothing, and never smaller
    than a readable size; the FPS counter is larger and brighter. On small
    windows the HUD no longer squeezes its text into boxes too small for it
    (numbers stay inside the health blade and rows no longer overlap).
  - Pixels are always fine and every one is the same size: each pixel of the
    art covers the same whole number of screen pixels, chosen from the
    window and the camera setting, so there is no pixel size setting (and no
    Picture or Scanlines either). The HUD and menus take the same share of
    the screen in a window as in full screen, and the crosshair and the
    guide dagger are smaller.
  - **A living title screen.** The GLYPHWOOD logo is drawn in square pixels
    of blood red instead of text blocks, with a wet sheen along the tops of
    its letters; it swells with a slow heartbeat and blood drips from the
    ends of its runs. The tagline and the line of best results are gone;
    Continue no longer names the world, and Worlds shows how many there are
    when there is more than one.
  - The world list says plainly what it counts: "Depth 15 · Hero level 20 ·
    Played 1 h 28 min" (it was "Level 15 · Hero LV 20 · 1:28"). The level
    of the descent is called **Depth** everywhere, so it is no longer
    mixed up with the hero's level.
  - A new app icon: a blood red pixel G dripping onto a dark tile.
- **Bigger, crueller bosses.** Every boss is two to three times the hero's
  height and drawn anew without a single box head: the Gravemaw is a beast
  with bone spikes along its spine and a horned skull with its jaw hanging
  open; the Wraith grins from a hooked hood and reaches with bone claws; the
  Colossus is a hunched brute of slag with crags on its back, great horns
  and a jaw of lava; the Hangman wears a tall bent hood with burning
  eyeholes, skulls on his belt and a bloody axe; the Drowned Abbess weeps
  black water under a torn veil with a cross hung upside down; the Frost
  King is a lich with a jagged crown of ice. Their bodies are as big as
  their pictures. The maw totem is now a swollen pod of flesh on roots with
  a toothed maw and a cluster of red eyes, and the black knight wears a
  pointed hounskull helm.
- **Darker and crueller.** Less ambient light in every biome, a heavier
  vignette, and glow only on truly bright things. Struck foes bleed (bone,
  stone and spirits shed dust instead). The blood moon is bigger, banded like
  dried blood, with a skull in its craters; a great slit eye now peers out of
  the eclipse shadow, half shut, following you, and crows circle it.
- **A weapon belt.** The second weapon on the back is now a belt of three:
  keys 1, 2 and 3 take a weapon in hand (rebindable in Settings → Controls),
  on a gamepad L3 takes the next one, and changing waits 0.6 s instead of a
  second. In the inventory the belt sits beside the hero; a weapon in the
  bag or on the belt goes into a slot with the same keys. Saved runs move
  their second weapon onto the belt.
- **No more endless swinging.** Holding attack no longer keeps swinging by
  itself (it did since 0.11.0); every cut takes its own press again, and a
  press just before a swing ends is still kept. After the third cut of Triple
  Cut there is a short pause (shorter with faster weapons) before the next
  swing, so mashing can't chain combos without a break either.
- Armour sits in riveted iron plates with cut corners, charms in round
  medallions.
- **Settings.**
  - One key per action instead of two. Settings → Controls switches between
    the keyboard and mouse and the gamepad, where every button can be
    rebound (moving stays on the left stick and the d-pad). The arrow keys
    always work in menus. New defaults: attack on the left mouse button,
    block on the right, dash on Shift, thrown weapon on F. Saved bindings
    keep the first key of each action.
  - The settings window is compact: the rows of a tab that don't fit scroll
    (mouse wheel, touchpad or the keys), and explanations show only as a
    tooltip when the mouse rests on an option, with no notes under the list.
  - **Reset settings**, small in the window's bottom left corner, puts
    every setting and binding back (not the language) after a second press; the old reset of keys only and
    "Show tutorial hints again" are gone: turning **Show hints** back on shows
    all of them again.
  - "Mute in background" is now **Sound when the window is inactive**.
  - Interface size runs from 50 % to 150 % (was 80–130 %).
- **HUD.** It shows only the weapon belt, in square slots with the keys
  1 2 3 under them; the thrown weapon and the charms are in the inventory.
  Weapon pictures are made to fill their slot, so none sticks out and a
  halberd is as big as a dagger. The level, ink and cooldown rows have more room between them
  and the keys under the cooldown seals are set further down.
- **A plainer inventory.** The hero stands on the left with the level,
  health, damage and armour under it; beside it are rows of slots without
  captions (head, body and legs; the three belt slots and, a little apart,
  the thrown weapon; the charms) and on the right the bag, which scrolls.
  What an item is and does shows in a box when the cursor is over it (or it
  is selected with the keys). Items can be dragged with the mouse onto a
  slot or into the bag, and a weapon taken from the bag goes into an empty
  belt slot instead of replacing the one in hand. Anything worn can be taken
  off without something to put on instead: the thrown weapon too, and the
  weapon in hand when another is on the belt (the hand takes that one).
  Armour shows how much it protects as "Armour +8%", like the hero's total.
- **Reforging is now Reinforcing**, and says what it gives: the hint on a
  piece of armour reads e.g. "F reinforce: armour +2%, health +4 ◆ 120".
- **The merchant.** A list that doesn't fit scrolls with the mouse wheel or
  the touchpad instead of running off the screen; weapons and armour show
  their numbers (damage, attack speed, reach; armour, health) instead of
  their lore; Sell and Leave are buttons along the bottom; "Sold" and other
  messages take the greeting's place instead of covering the list; every
  service has a picture.
- **Menus** no longer list the keys along the bottom, the pause menu no
  longer shows kills, shards and time, and the skill tree's entry in it no
  longer counts the free points.
- **Swimming.** Water slows the hero down and holds it up: it drifts to the
  surface and floats there, jump (or up) swims up, down dives, and a jump
  from the surface is only enough to climb onto the bank.
- **Smoother and cooler.** Weapon pictures for every angle are made ahead of
  time and kept, and creature pictures are no longer thrown away all at
  once, which caused short freezes in long runs; in the background the game
  draws only 15 frames a second.
- Resizing the window fits the picture again even when the change comes
  without notice (full screen on macOS), and the view is never wider or
  taller than the level, so no black bars appear beside it.
- The Glyph Saber deals 9 damage instead of 11 (it outdid dearer weapons) and
  the Bell Halberd 19 instead of 17.

### Fixed

- A foe or prop facing left was drawn a whole sprite's width to the right of
  where it really was, so foes seemed to stand inside walls; and foes wider
  than a tile no longer appear inside a wall next to them.
- Attacking with the mouse aimed above the hero no longer throws them into
  the air: only the up key with attack makes a Rising Crescent.

## [0.11.1] - 2026-10-23

### Changed

- **Armour has a ceiling.** Armour, charms and skills together never take off
  more than half of a blow (Last Stand still comes on top). Before, a fully
  reforged set with Iron Shroud, Iron Hide, Bastion and Titan let only about
  a third through.
- **Parry is harder to farm.** The parry window is 0.15 s instead of 0.18 s,
  a parried foe reels for 0.7 s instead of 1 s, and the same foe can't be
  parried again for 3 seconds (its next blow is only blocked), so slow
  walkers can no longer be stun-locked.
- Night Katana 14 → 15 damage, so it stays ahead of the cheaper Glyph Saber.

### Performance

- The blood moon is drawn in cached layers: only its clouds, eye and drips
  are repainted each frame, the halo's heartbeat is a fade. The sky costs
  about half as much per frame.
- Water and lava skip the wave maths for the cells that stay empty.

## [0.11.0] - 2026-10-23

### Added

- **Block and parry** (Q or L, gamepad LT). Raise a short guard against blows
  from the front; you walk slowly behind it and it lasts at most 1.2 seconds.
  A blow that lands in the first instant is **parried**: no damage, the foe
  reels, your next hit is a sure critical and enemy shots fly back at them. A
  late block still lets 35% through and breaks the guard, and there is a short
  cooldown before the next one, so it is a timing skill, not a free wall.
  Spikes, pits and hazards ignore it.
- **A second weapon** (R or U, gamepad L3). The second weapon you pick up goes
  on your back; the swap key draws it. Drawing takes a quarter of a second,
  the combo starts over and the next swap waits a second.
- **Armour.** Nine pieces for the head, body and legs, from the Pilgrim's
  Hood to Cathedral Plate. Heavier pieces protect more but slow your run and
  (the plate) your dash, a few add something of their own (more health,
  crits, ink, thorns). What you wear dyes the hero, and each piece can be
  reforged three times for shards in the inventory. Armour is sold by the
  merchant and found like other items.
- **Cooldown seals** under the health bar for dash, block, the weapon swap,
  Blade Storm and Juggernaut: they darken while recharging and flash when
  ready.
- Block and swap on the Moves screen and in the hints.

### Changed

- **New inventory.** The hero stands in a gothic niche wearing what you
  equipped, with armour slots on one side and the weapon, second weapon and
  throwing slots on the other, then the charms and the bag. Equip, carry as
  second weapon or reforge right from the details line.
- **Item pictures are drawn, not typed**: every weapon, throwing weapon,
  charm, armour piece and merchant service has its own small picture in the
  inventory, the shop and the HUD.
- **Weapon balance.** The Bell-Tower Halberd no longer beats everything:
  19 → 17 damage, attack speed ×0.8 → ×0.74, reach ×1.6 → ×1.5. Glyph Saber
  13 damage at ×1.2 → 11 at ×1.55; Widow's Fangs 7 at ×1.65 → 8 at ×2.0;
  Bloodletter ×1.45 → ×1.7; Hollow Spear and Ember Brand 12 → 13 damage.
- **Dash cooldown** 0.55 → 0.9 seconds.
- Holding attack keeps swinging, and a press just before a swing ends is kept
  for the next one.
- Enemy blows hit about 10% harder to make room for armour: without any you
  take a little more than before, with a full set somewhat less.
- English is the default language on the first start (change it in Settings).

### Fixed

- You can swim up and leap out of water at the surface instead of having to
  wall-jump out.
- Health no longer comes back in the middle of a fight: not on a wall above
  an arena, not beside a foe that has seen you. Arena gates in open-sky rooms
  reach the top of the room, so you can't jump over them to escape.
- The left and right arrows of a setting (language, difficulty, …) step back
  and forward instead of always going forward.
- The shop shows what reforged armour really sells for.

## [0.10.0] - 2026-10-21

### Changed

- **The exit is entered on purpose.** Walking into an open portal no longer
  takes you down at once: stand in it and press Interact (E, gamepad B) or Up.
  A "Descend" prompt shows above it, so you can't fall through by accident
  while fighting or looting near the door.
- **Gothic weapons.** Every weapon in the hand was redrawn: arming swords with
  drooping quillons, a red gem and a wheel pommel; a wavy flamberge; a winged
  partisan with a blood-red tassel; a flanged mace; a rondel dagger; a
  dark-steel katana; a swept-hilt rapier; a bone scythe bound with a skull; a
  halberd and a headsman's axe with a cross cut through the blade. The
  inventory icons follow the same style.

### Performance

- Foes far outside the view sleep until you come near (bosses and foes that
  have already seen you never do), so deep, crowded levels simulate about a
  third as much each frame.
- Glyph sprites are turned into flat lists once and reused, instead of being
  parsed from text every frame: drawing the hero and foes costs about 20% less.
- Level loading is more than twice as fast (about 150 ms down to about 60 ms on
  the biggest levels): the wall-depth shading is computed in two sweeps instead
  of four slow passes.
- The exit door is no longer drawn when it is off screen.

## [0.9.0] - 2026-10-21

### Added

- **Six new weapons**, each with its own silhouette in the hand: Pilgrim's
  Sword, Frost Brand (chills), Bloodletter (a rapier that heals a little on
  every hit), Bone Scythe (wide sweeps that also cut behind you), Bell-Tower
  Halberd (the longest reach) and Headsman's Axe (+60% damage to foes below a
  third of their health). A new throwing weapon, the **Grave Javelin**, flies
  fast through every foe and shield in a line.
- **A bigger skill tree.** Every branch grows to seven tiers with a third fork
  and a new capstone: *Bulwark* gets Bastion or Rend and Titan, *Alchemist*
  Venom Glass or Quicksilver and the Philosopher's Stone, *Shade* Shadow Step
  or Hemorrhage and the Dance of Death. Vitality and Keen Edge go to eight
  ranks. Maxing everything now takes 37 points instead of 25.

### Changed

- **Longer biomes and levels.** Each biome has three levels (the boss waits at
  the end of the third), so a full cycle is 18 levels. Levels grow wider and
  taller as you go down, long levels get a second arena, and lanterns stand
  every three or four rooms. Saved worlds keep their level number, which may
  now fall in a different biome.
- **Difficulty curve.** The first levels are a gentle start; from the fourth
  level on, enemy health and damage climb faster. Bosses grow with depth from
  the first one (they used to stay the same until the second cycle). Rooms
  and arenas hold a few more foes, and elites appear more often deeper down.
- **Hard and Nightmare are really hard.** Hard: enemies hit 50% harder, have
  45% more health, move 8% faster and are elite more often; health returns
  slower. Nightmare: 2.2 times the damage, twice the health, 16% faster, many
  elites, health returns at half speed.
- **Slower growth.** Each hero level gives +4% damage (was 6%) and needs more
  experience; Keen Edge gives +3% per rank (was 4%). Burning damage now grows
  with your blows so fire stays useful deep down.
- **Thrown weapons have their own damage**, which grows with the hero's level,
  instead of a multiple of the melee weapon's: a great sword no longer turns
  every knife into a cannon. Ink Knife 14, Bone Boomerang 8, Thorn Chakram 9,
  Bile Flask 16, Grave Javelin 22 at level 1, +6% per level.
- **Bone Boomerang** hits each foe at most twice per throw (once out, once
  back) instead of every third of a second while it overlaps, so it no longer
  shreds bosses.
- **Night Katana** loses its extra critical chance and swings a bit slower.
- **Blade Storm** (free throw on the Triple Cut finisher) fires at most every
  2.5 s and at 60% damage. **Juggernaut**'s ground wave is shorter, weaker and
  rolls at most every 1.5 s. **Siphon** gives 8 ink per hit, at most 16 per
  throw.

## [0.8.0] - 2026-10-21

### Added

- **Skill tree** (T, LB on a gamepad, or the pause menu). Every hero level
  gives a skill point. The core holds the basic moves and two stat nodes
  (Vitality, Keen Edge, five ranks each); three branches climb from it:
  *Bulwark* (heavy weapons and toughness: Quake dive, Shoulder Charge, Last
  Stand, Vengeance, Juggernaut ground wave), *Alchemist* (daggers, thrown
  weapons and ink: Twin Throw, Ricochet, Hex, Siphon, Blade Storm) and *Shade*
  (mobility and blades: Phantom Dash, Wind Walker, Iaido, Long Lunge, Reaper).
  Tiers 2 and 4 fork, and only one side can be learned; a merchant makes you
  forget everything for a price.
- **Three new biomes**, six in all: the Gallows Mire, the Drowned Cathedral and
  the Frostbound Crypt, each with its own colours, decorations, music,
  ambience, enemies (bog toads, the hanged, choir skulls, penitents, frost
  wights) and boss (the Hangman, the Drowned Abbess, the Frost King). The
  world stays endless: after the twelfth level the biomes come back deeper,
  in a new order for every cycle.
- **Weapons in the hero's hands.** Each weapon has its own silhouette (sword,
  great sword, spear, mace, twin daggers, katana) that swings with the
  attacks, so a mace never looks like a sword. New weapons: Grave Maul (breaks
  shields), Widow's Fangs (twin daggers), Night Katana.
- **Throwing weapons** in their own slot: Ink Knife, Bone Boomerang (comes back,
  cuts both ways), Thorn Chakram (pierces and rebounds) and Bile Flask (bursts
  in a burning cloud).
- Eleven new charms, among them the Funeral Bell, Blood Rosary, Iron Shroud,
  Raven Quill and a charm from each new boss.
- The merchant buys what you no longer need (Sell), sells **Haste** (+5%
  running speed, six times) and lets you forget your skills.
- A charm slot opens every fifth hero level (up to eight).

### Changed

- **Smoother frames.** The world is simulated once per frame (in small steps
  when frames are long) instead of at a fixed tick that drifted against the
  display; the terrain is cached in smaller pieces painted one per frame
  ahead of the camera; breaking a wall repaints only its surroundings; the
  minimap repaints only rooms that changed; the status panel is cached and
  redrawn only when something on it changes; health-orb pull no longer
  depends on the frame rate.
- The crosshair is about a third smaller.
- + and − no longer change the interface size; it is only in Settings.

## [0.7.0] - 2026-10-20

### Changed

- **Mouse while playing.** The mouse is captured and the game moves its own
  cursor, kept inside the window, so a click can't leave the game. The
  crosshair is drawn every frame again (at 180 FPS it moves 180 times a
  second) and follows the mouse at the same speed as the desktop cursor on
  any display scale. Menus give the cursor back where the crosshair was.
  This replaces 0.6's cursor confinement, which on macOS made the crosshair
  stutter and could show it at the wrong size.
- **Gothic HUD.** The crosshair is a reticle of four bone thorns, a broken
  ring of blood that turns (and tightens and reddens during combos) and a
  bone diamond. The health blade wears cemetery-fence spikes and bleeds from
  its underside below half health; ink charges are small hanging daggers;
  equipment slots are lancet arches with crosses; the experience line ends in
  gold diamonds; the arrow that shows the way is a bone dagger over an ember
  glow.
- Menus sit in wrought-iron frames with a crown of spikes and crosses on the
  corners, under headings flanked by iron lines and blood diamonds; the
  selected inventory item is marked in blood.

## [0.6.3] - 2026-10-20

### Changed

- The aiming crosshair is now the system cursor: the OS draws it at the
  display's refresh rate with no lag, so it moves as smoothly as the desktop
  cursor at any frame rate. It looks the same as before.
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

[Unreleased]: https://github.com/drugdamage/glyphwood/compare/v0.13.0...HEAD
[0.13.0]: https://github.com/drugdamage/glyphwood/compare/v0.12.1...v0.13.0
[0.12.1]: https://github.com/drugdamage/glyphwood/compare/v0.12.0...v0.12.1
[0.12.0]: https://github.com/drugdamage/glyphwood/compare/v0.11.1...v0.12.0
[0.11.1]: https://github.com/drugdamage/glyphwood/compare/v0.11.0...v0.11.1
[0.11.0]: https://github.com/drugdamage/glyphwood/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/drugdamage/glyphwood/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/drugdamage/glyphwood/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/drugdamage/glyphwood/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/drugdamage/glyphwood/compare/v0.6.3...v0.7.0
[0.6.3]: https://github.com/drugdamage/glyphwood/compare/v0.6.1...v0.6.3
[0.6.1]: https://github.com/drugdamage/glyphwood/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/drugdamage/glyphwood/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/drugdamage/glyphwood/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/drugdamage/glyphwood/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/drugdamage/glyphwood/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/drugdamage/glyphwood/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/drugdamage/glyphwood/releases/tag/v0.2.0
