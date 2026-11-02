## Export existing pixel art for the README animation without opening the game.
## godot --headless --path . --script tools/export_update_art.gd -- /tmp/glyphwood-art
extends SceneTree

const Gear := preload("res://scripts/gear_sprites.gd")
const Items := preload("res://scripts/items.gd")
const Sprites := preload("res://scripts/sprites.gd")
const Cache := preload("res://scripts/sprite_cache.gd")
const Hero := preload("res://scripts/hero.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Pass an output directory after --")
		quit(1)
		return
	var dest: String = args[0]
	DirAccess.make_dir_recursive_absolute(dest)
	for id in ["glyph_saber", "hollow_spear", "ember_brand", "widow_fangs", "bell_halberd", "frost_brand",
		"cinder_veil", "marsh_wrap", "choir_hood", "rime_mail"]:
		var rows: Array
		var pal: Array
		if Gear.WEAPONS.has(id):
			rows = Gear.WEAPONS[id].rows
			pal = Gear.WEAPONS[id].pal
		else:
			var part: String = Items.def(id).part
			rows = Gear.HEADS[id] if part == "head" else Gear.BODIES[id]
			pal = Sprites.HERO_PAL.duplicate()
			pal[1 if part == "head" else 0] = Hero.dye(part, Items.def(id).color)
		var width := 0
		for row in rows:
			width = maxi(width, row.length())
		var img := Image.create(width, rows.size(), false, Image.FORMAT_RGBA8)
		for y in rows.size():
			for x in rows[y].length():
				var ch: String = rows[y][x]
				if ch != "." and ch != " ":
					img.set_pixel(x, y, Cache.color(ch, pal))
		if img.save_png(dest.path_join(id + ".png")) != OK:
			quit(1)
			return
	print("Exported README art; no game scene was loaded.")
	quit()
