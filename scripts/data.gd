## Static game data: world constants, biomes, enemy stats and hand-made rooms.
## Sprite art lives in sprites.gd, items in items.gd, interface text in strings.gd.
extends RefCounted

const TILE := 16.0
## Every glyph sits on a fine text grid: 4 columns and 3 rows per tile.
const GW := 4.0
const GH := TILE / 3.0

## Levels are a grid of rooms, each ROOM_W x ROOM_H tiles.
const ROOM_W := 40
const ROOM_H := 24
## Row of the floor surface where rooms connect left and right (first solid row).
const EDGE_FLOOR := ROOM_H - 5
## Height of the opening in a side wall above EDGE_FLOOR.
const DOOR_H := 7
const SHAFT_W := 4

## Two levels per biome; the second one ends with the biome's boss. After the
## last biome the world starts over deeper, with the biomes in a new order.
const LEVELS_PER_BIOME := 2
const FINAL_LEVEL := 12

## look: which family of backdrop, back wall and rock details a biome borrows.
const BIOMES := [
	{
		"id": "wood", "look": "wood", "boss": "warden", "sky": true,
		"sky_top": Color(0.018, 0.012, 0.03), "sky_bot": Color(0.075, 0.03, 0.05),
		"fill": Color(0.03, 0.026, 0.034), "deep": Color(0.11, 0.1, 0.12), "edge": Color(0.34, 0.31, 0.36),
		"top": Color(0.64, 0.62, 0.58), "grass": Color(0.42, 0.42, 0.36), "far": Color(0.08, 0.04, 0.08),
		"mid": Color(0.11, 0.07, 0.12), "mote": Color(0.75, 0.72, 0.95), "ambient": 0.74,
		"light": Color(0.9, 0.84, 0.95), "torch": Color(1.0, 0.55, 0.28), "water": Color(0.22, 0.28, 0.42),
		"pits": ["spikes", "water", "spikes"], "brick": false,
		"glyphs_edge": "#%&#8#", "glyphs_deep": "%:;&.'`#", "glyphs_top": "~-=~-_",
		"foes": ["crawler", "crawler", "hopper", "bat", "spitter"],
	},
	{
		"id": "hollow", "look": "hollow", "boss": "wraith", "sky": false,
		"sky_top": Color(0.012, 0.01, 0.012), "sky_bot": Color(0.03, 0.025, 0.025),
		"fill": Color(0.042, 0.038, 0.036), "deep": Color(0.26, 0.23, 0.2), "edge": Color(0.48, 0.44, 0.38),
		"top": Color(0.8, 0.74, 0.62), "grass": Color(0.42, 0.4, 0.34), "far": Color(0.08, 0.065, 0.06),
		"mid": Color(0.12, 0.1, 0.09), "mote": Color(1.0, 0.82, 0.55), "ambient": 0.66,
		"light": Color(1.0, 0.9, 0.76), "torch": Color(1.0, 0.72, 0.38), "water": Color(0.42, 0.06, 0.08),
		"pits": ["spikes", "water", "spikes", "spikes"], "brick": true,
		"glyphs_edge": "[]#=|_", "glyphs_deep": ".:'", "glyphs_top": "=_-=__",
		"foes": ["bat", "knight", "shield", "wisp", "archer", "crawler"],
	},
	{
		"id": "ember", "look": "ember", "boss": "colossus", "sky": false,
		"sky_top": Color(0.03, 0.008, 0.008), "sky_bot": Color(0.08, 0.018, 0.012),
		"fill": Color(0.05, 0.02, 0.02), "deep": Color(0.17, 0.06, 0.05), "edge": Color(0.44, 0.2, 0.17),
		"top": Color(0.85, 0.36, 0.26), "grass": Color(0.6, 0.2, 0.15), "far": Color(0.13, 0.03, 0.03),
		"mid": Color(0.2, 0.05, 0.04), "mote": Color(1.0, 0.45, 0.22), "ambient": 0.7,
		"light": Color(1.0, 0.72, 0.56), "torch": Color(1.0, 0.42, 0.16), "water": Color(0.3, 0.32, 0.36),
		"pits": ["lava", "lava", "spikes"], "brick": false,
		"glyphs_edge": "#X%#&#", "glyphs_deep": "X%:;.,*#", "glyphs_top": "^-~^_-",
		"foes": ["knight", "archer", "bomber", "hopper", "spitter", "shield"],
	},
	{
		"id": "mire", "look": "wood", "boss": "hangman", "sky": true,
		"sky_top": Color(0.012, 0.022, 0.018), "sky_bot": Color(0.045, 0.065, 0.04),
		"fill": Color(0.024, 0.03, 0.022), "deep": Color(0.1, 0.12, 0.08), "edge": Color(0.3, 0.34, 0.24),
		"top": Color(0.55, 0.6, 0.4), "grass": Color(0.36, 0.45, 0.25), "far": Color(0.04, 0.06, 0.04),
		"mid": Color(0.07, 0.09, 0.06), "mote": Color(0.7, 0.95, 0.5), "ambient": 0.7,
		"light": Color(0.85, 0.95, 0.75), "torch": Color(0.65, 1.0, 0.4), "water": Color(0.16, 0.22, 0.1),
		"pits": ["water", "water", "spikes"], "brick": false,
		"glyphs_edge": "#%&~#%", "glyphs_deep": "%:;~.,'", "glyphs_top": "~,-~_'",
		"foes": ["toad", "hanged", "crawler", "bat", "bomber", "toad"],
	},
	{
		"id": "cathedral", "look": "hollow", "boss": "abbess", "sky": false,
		"sky_top": Color(0.01, 0.012, 0.03), "sky_bot": Color(0.025, 0.03, 0.07),
		"fill": Color(0.03, 0.032, 0.05), "deep": Color(0.16, 0.17, 0.26), "edge": Color(0.38, 0.4, 0.55),
		"top": Color(0.7, 0.72, 0.88), "grass": Color(0.3, 0.4, 0.45), "far": Color(0.05, 0.055, 0.1),
		"mid": Color(0.08, 0.085, 0.15), "mote": Color(0.6, 0.75, 1.0), "ambient": 0.64,
		"light": Color(0.8, 0.85, 1.0), "torch": Color(1.0, 0.8, 0.45), "water": Color(0.1, 0.2, 0.35),
		"pits": ["water", "water", "spikes", "water"], "brick": true,
		"glyphs_edge": "[]#=|+", "glyphs_deep": ".:'", "glyphs_top": "=_-=+_",
		"foes": ["choir", "penitent", "shield", "wisp", "archer", "penitent"],
	},
	{
		"id": "crypt", "look": "crypt", "boss": "frost_king", "sky": false,
		"sky_top": Color(0.015, 0.02, 0.03), "sky_bot": Color(0.04, 0.055, 0.07),
		"fill": Color(0.035, 0.042, 0.05), "deep": Color(0.2, 0.25, 0.3), "edge": Color(0.5, 0.6, 0.68),
		"top": Color(0.85, 0.93, 1.0), "grass": Color(0.6, 0.75, 0.85), "far": Color(0.06, 0.08, 0.1),
		"mid": Color(0.09, 0.12, 0.15), "mote": Color(0.85, 0.95, 1.0), "ambient": 0.7,
		"light": Color(0.85, 0.92, 1.0), "torch": Color(0.55, 0.8, 1.0), "water": Color(0.45, 0.6, 0.75),
		"pits": ["spikes", "water", "spikes"], "brick": false,
		"glyphs_edge": "#%*#&#", "glyphs_deep": "*:.'`#", "glyphs_top": "^-*^_-",
		"foes": ["wight", "bat", "shield", "wisp", "knight", "wight"],
	},
]

## Enemy stats. hp is in sword damage units (the starting blade deals 10).
## Sprites are in sprites.gd under the same key.
const ENEMIES := {
	"crawler": {"size": Vector2(20, 14), "hp": 30, "speed": 40.0, "shards": 3, "fly": false},
	"hopper": {"size": Vector2(18, 14), "hp": 30, "speed": 110.0, "shards": 3, "fly": false},
	"bat": {"size": Vector2(20, 12), "hp": 20, "speed": 95.0, "shards": 2, "fly": true},
	"spitter": {"size": Vector2(18, 20), "hp": 30, "speed": 0.0, "shards": 4, "fly": false},
	"knight": {"size": Vector2(14, 28), "hp": 60, "speed": 36.0, "shards": 6, "fly": false},
	"shield": {"size": Vector2(16, 28), "hp": 50, "speed": 30.0, "shards": 6, "fly": false},
	"wisp": {"size": Vector2(14, 14), "hp": 25, "speed": 48.0, "shards": 4, "fly": true},
	"archer": {"size": Vector2(14, 26), "hp": 40, "speed": 50.0, "shards": 5, "fly": false},
	"bomber": {"size": Vector2(16, 16), "hp": 30, "speed": 85.0, "shards": 4, "fly": false},
	"toad": {"size": Vector2(18, 14), "hp": 35, "speed": 100.0, "shards": 4, "fly": false},
	"hanged": {"size": Vector2(14, 26), "hp": 40, "speed": 70.0, "shards": 5, "fly": false},
	"choir": {"size": Vector2(14, 14), "hp": 30, "speed": 40.0, "shards": 4, "fly": true},
	"penitent": {"size": Vector2(14, 26), "hp": 55, "speed": 45.0, "shards": 6, "fly": false},
	"wight": {"size": Vector2(14, 26), "hp": 50, "speed": 42.0, "shards": 6, "fly": false},
	"warden": {"size": Vector2(56, 40), "hp": 360, "speed": 60.0, "shards": 60, "fly": false},
	"wraith": {"size": Vector2(40, 44), "hp": 440, "speed": 90.0, "shards": 80, "fly": true},
	"colossus": {"size": Vector2(52, 52), "hp": 560, "speed": 70.0, "shards": 100, "fly": false},
	"hangman": {"size": Vector2(40, 50), "hp": 700, "speed": 75.0, "shards": 120, "fly": false},
	"abbess": {"size": Vector2(40, 48), "hp": 820, "speed": 85.0, "shards": 140, "fly": true},
	"frost_king": {"size": Vector2(52, 52), "hp": 960, "speed": 70.0, "shards": 160, "fly": false},
}

const BOSSES := ["warden", "wraith", "colossus", "hangman", "abbess", "frost_king"]

## Hand-made side rooms (ROOM_W x ROOM_H). Used for treasure rooms when one fits.
## Legend:
##   .  empty        #  solid          =  one-way platform   ^  spikes
##   ~  water        %  cracked wall   C  chest              *  shard cluster
##   T  torch        h  heart          e  random biome enemy b  bat
## Both side openings (rows EDGE_FLOOR-DOOR_H .. EDGE_FLOOR-1) must be open and the
## floor at the edge columns must be at row EDGE_FLOOR; the unused side is sealed.
const VAULTS := [
	[ # tower
		"########################################",
		"########################################",
		"########################################",
		"################.......C.###############",
		"##############......=======.############",
		"############.................###########",
		"##########........T...........##########",
		"#########...........=====........#######",
		"########...........................#####",
		"#######..................*..........####",
		"######.....................=====.....###",
		"#####...............................####",
		"........................................",
		"........b...........=====...............",
		"........................................",
		"........................................",
		"...........................=====........",
		"........................................",
		".......e..........................e.....",
		"##############^^^^######################",
		"########################################",
		"########################################",
		"########################################",
		"########################################",
	],
	[ # flooded cellar
		"########################################",
		"########################################",
		"########################################",
		"########################################",
		"########################################",
		"########################################",
		"########.....T..............T.....######",
		"#######............................#####",
		"######..............................####",
		"#####................b...............###",
		"####.................................###",
		"###...................................##",
		"........................................",
		"........................................",
		"........................................",
		"..........=====.........=====...........",
		"........................................",
		"........................................",
		"........................................",
		"########~~~~~~~~~~~~~~~~~~~~~~~#########",
		"########~~~~~~~~~~*~~~~~~~~~~~~#########",
		"########~~~~~~~~~~~~~~~~~~~C~~~#########",
		"########################################",
		"########################################",
	],
	[ # hidden alcove behind a cracked wall
		"########################################",
		"########################################",
		"########################################",
		"########################################",
		"########################################",
		"#####################%%%%%%#############",
		"##########...........%....*#############",
		"########.............%.C...#############",
		"#######..............%%%%%%#.....#######",
		"######......T.......................####",
		"#####................................###",
		"####...........======.................##",
		"........................................",
		"........................................",
		"........................................",
		"........=====...........................",
		"........................................",
		"...........e..................e.........",
		"..........h.............................",
		"########################################",
		"########################################",
		"########################################",
		"########################################",
		"########################################",
	],
]
