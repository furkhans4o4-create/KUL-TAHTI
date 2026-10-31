extends Control

const FOREST = preload("res://scripts/forest3d.gd")
const ASCII = preload("res://shaders/ascii.gdshader")
const FONT_ATLAS = preload("res://scripts/glyph_atlas.gd")
var viewport: SubViewport
var forest: Node3D
var screen: TextureRect
var top_label: Label
var bottom_label: Label
var header_background: ColorRect
var footer_background: ColorRect
var effect: ShaderMaterial
var ui_visible := true

func _ready() -> void:
    viewport = SubViewport.new()
    viewport.name = "WorldViewport"
    viewport.size = Vector2i(1280,720)
    viewport.disable_3d = false
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(viewport)
    forest = FOREST.new()
    viewport.add_child(forest)
    screen = TextureRect.new()
    screen.name = "ASCII_WORLD"
    screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    screen.stretch_mode = TextureRect.STRETCH_SCALE
    screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
    screen.texture = viewport.get_texture()
    effect = ShaderMaterial.new()
    effect.shader = ASCII
    effect.set_shader_parameter("atlas_tex", FONT_ATLAS.new().make_texture())
    screen.material = effect
    add_child(screen)
    header_background = ColorRect.new()
    header_background.color = Color(0.012, 0.025, 0.024, 0.91)
    header_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(header_background)
    footer_background = ColorRect.new()
    footer_background.color = Color(0.012, 0.025, 0.024, 0.91)
    footer_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(footer_background)
    top_label = Label.new()
    top_label.add_theme_font_size_override("font_size", 14)
    top_label.add_theme_color_override("font_color", Color("e5d5ac"))
    top_label.position = Vector2(20, 14)
    top_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(top_label)
    bottom_label = Label.new()
    bottom_label.add_theme_font_size_override("font_size", 13)
    bottom_label.add_theme_color_override("font_color", Color("c1d6cd"))
    bottom_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bottom_label)
    _resize()
    get_viewport().size_changed.connect(_resize)

func _resize() -> void:
    var s = get_viewport_rect().size
    viewport.size = Vector2i(maxi(640, int(s.x)), maxi(360, int(s.y)))
    effect.set_shader_parameter("glyph_grid", Vector2(maxf(100.0,s.x/6.6),maxf(64.0,s.y/8.8)))
    if bottom_label != null:
        bottom_label.position = Vector2(20,s.y-56.0)
    if header_background != null:
        header_background.position = Vector2(12, 10)
        header_background.size = Vector2(s.x-24.0, 64)
    if footer_background != null:
        footer_background.position = Vector2(12, s.y-68.0)
        footer_background.size = Vector2(s.x-24.0, 64)

func _process(_dt: float) -> void:
    top_label.visible = ui_visible
    bottom_label.visible = ui_visible
    header_background.visible = ui_visible
    footer_background.visible = ui_visible
    var hours: int = int(forest.day_time * 24.0)
    var minutes: int = int(fposmod(forest.day_time * 24.0,1.0)*60.0)
    top_label.text = "K Ü L   T A H T I    /    THE ASHEN FOREST      %02d:%02d     %s\nHP %d   MP %d   %s   WOOD %d   KILLS %d" % [hours, minutes, "RAIN" if forest.rain else "CLEAR", int(forest.hp),int(forest.mp),forest.weapon_names[forest.weapon],forest.wood,forest.kills]
    bottom_label.text = "WASD MOVE    SHIFT RUN    1/2/3 WEAPONS    SPACE ATTACK    Q MAGIC    E CHOP    R RAIN    T TIME    H HUD\n> " + forest.status

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_H:
            ui_visible = not ui_visible
        else:
            forest.action(event.keycode)
