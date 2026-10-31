extends SceneTree

func _initialize() -> void:
    call_deferred("_make_snapshot")

func _make_snapshot() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    var scene := packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    for i in range(90):
        await process_frame
    var img: Image = root.get_texture().get_image()
    if img == null or img.is_empty():
        push_error("Rendered frame is empty")
        quit(1)
        return
    var code: Error = img.save_png("/tmp/kul-tahti-visual-check.png")
    if code != OK:
        push_error("Could not write screenshot: " + str(code))
        quit(1)
        return
    var world: SubViewport = scene.get_node("WorldViewport")
    world.get_texture().get_image().save_png("/tmp/kul-tahti-world-source.png")
    print("Screenshots saved")
    quit()
