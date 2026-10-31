extends Node3D

# Visual rebuild: procedurally modeled 3D forest, rendered entirely as ASCII.
# All environment geometry is code-created. No non-ASCII image is visible.
var day_time: float = 0.34
var rain: bool = false
var hp: float = 100.0
var mp: float = 100.0
var wood: int = 0
var kills: int = 0
var weapon: int = 0
var weapon_names: Array[String] = ["LONGSWORD", "AXE", "SPEAR"]
var status: String = "THE OLD KING IS DEAD. THE ROOTS REMEMBER."

var hero_position: Vector3 = Vector3.ZERO
var hero_facing: Vector3 = Vector3(0, 0, -1)
var elapsed: float = 0.0
var walk_phase: float = 0.0
var attack_remaining: float = 0.0
var spell_remaining: float = 0.0
var camera: Camera3D
var sunlight: DirectionalLight3D
var environment: Environment
var actor: Node3D
var sword: Node3D
var left_foot: MeshInstance3D
var right_foot: MeshInstance3D
var rain_particles: CPUParticles3D
var trees: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var trunk_instances: MultiMesh
var crown_instances: MultiMesh
var ashes: Array[Dictionary] = []
var ash_node: Node3D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var mat_trunk: StandardMaterial3D
var mat_foliage: StandardMaterial3D

func _ready() -> void:
    rng.seed = 7142001
    _lighting()
    _terrain()
    _grass()
    _trees()
    _stones()
    _player()
    _enemies()
    _camera()
    _rain()
    set_process(true)

func _material(hex: String, roughness_value: float = 0.9, unshaded: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(hex)
    mat.roughness = roughness_value
    mat.vertex_color_use_as_albedo = false
    if unshaded:
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return mat

func _mesh(mesh: Mesh, mat: Material, parent: Node3D, pos: Vector3, size: Vector3) -> MeshInstance3D:
    var obj := MeshInstance3D.new()
    obj.mesh = mesh
    obj.material_override = mat
    obj.position = pos
    obj.scale = size
    obj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(obj)
    return obj

func _sphere(radius: float = 0.5) -> SphereMesh:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 8
    mesh.rings = 4
    return mesh

func _lighting() -> void:
    environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("111c1c")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("b0c9bd")
    environment.ambient_light_energy = 1.25
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    var world_env := WorldEnvironment.new()
    world_env.environment = environment
    add_child(world_env)
    sunlight = DirectionalLight3D.new()
    sunlight.light_color = Color("ffdfaf")
    sunlight.light_energy = 1.7
    sunlight.shadow_enabled = true
    sunlight.rotation_degrees = Vector3(-53, 28, 0)
    add_child(sunlight)

func _terrain() -> void:
    var ground := PlaneMesh.new()
    ground.size = Vector2(130, 130)
    var ground_mat := _material("233a30")
    _mesh(ground, ground_mat, self, Vector3(0, -0.11, 0), Vector3.ONE)

    # Pebbled trail around the ruined road.
    var dust_mat := _material("5d5343")
    var pebble_mesh := _sphere(0.6)
    for i in range(90):
        var x: float = -41.0 + float(i) * 0.92
        var z: float = -2.7 + sin(float(i) * 0.14) * 0.5
        _mesh(pebble_mesh, dust_mat, self, Vector3(x, -0.04, z + rng.randf_range(-0.9, 0.9)), Vector3(rng.randf_range(0.3, 1.5), 0.06, rng.randf_range(0.45, 1.2)))

    # A broad river runs across the southern portion of the camera view.
    var river := PlaneMesh.new()
    river.size = Vector2(135, 25)
    var water_shader := Shader.new()
    water_shader.code = "shader_type spatial;\nrender_mode cull_disabled;\nuniform vec4 water_color : source_color = vec4(0.065, 0.29, 0.42, 1.0);\nvoid fragment(){float wave = sin(UV.x * 110.0 + TIME * 2.0 + sin(UV.y*19.0 + TIME)*1.5); float band=sin(UV.y*34.0+UV.x*8.0-TIME*1.7); ALBEDO = water_color.rgb + vec3(0.04,0.12,0.15) * (wave*wave*0.5+band*band*0.3); ROUGHNESS = 0.14; METALLIC=0.14;}\n"
    var water_mat := ShaderMaterial.new()
    water_mat.shader = water_shader
    _mesh(river, water_mat, self, Vector3(0, -0.03, 20), Vector3.ONE)

    # Bank stones make the shore feel dimensional.
    var stone := _sphere(0.6)
    var bank_mat := _material("6a7871")
    for i in range(115):
        var x: float = rng.randf_range(-56, 56)
        var z: float = 7.5 + rng.randf_range(-1.5, 1.5)
        _mesh(stone, bank_mat, self, Vector3(x, 0.05, z), Vector3(rng.randf_range(0.3, 1.4), 0.2, rng.randf_range(0.4, 1.2)))

func _grass() -> void:
    # Grass uses a single instanced mesh and oscillates in the vertex shader.
    var blade := QuadMesh.new()
    blade.size = Vector2(0.20, 0.78)
    var shader := Shader.new()
    shader.code = "shader_type spatial;\nrender_mode cull_disabled;\nvoid vertex(){VERTEX.x += UV.y * sin(TIME * 2.0 + float(INSTANCE_ID) * 0.61) * 0.11;}\nvoid fragment(){ALBEDO = COLOR.rgb; ROUGHNESS=1.0;}\n"
    var grass_mat := ShaderMaterial.new()
    grass_mat.shader = shader
    blade.material = grass_mat
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = true
    mm.mesh = blade
    mm.instance_count = 16500
    var noise := FastNoiseLite.new()
    noise.seed = 8173
    noise.frequency = 0.078
    for i in range(mm.instance_count):
        var x: float = rng.randf_range(-52, 52)
        var z: float = rng.randf_range(-46, 47)
        var meadow: float = noise.get_noise_2d(x,z)
        # Reserve the player's clearing and stony trail.
        if (absf(x) < 2.5 and absf(z) < 2.6) or absf(z+2.7)<0.9 or z>7.0:
            x = rng.randf_range(-52,52)
            z = rng.randf_range(-43,-4)
        var h: float = rng.randf_range(0.55, 1.28) * (1.0 + maxf(-0.3, meadow))
        var angle: float = rng.randf_range(0, TAU)
        var orient := Basis().rotated(Vector3.UP, angle).scaled(Vector3(rng.randf_range(0.8, 1.5), h, 1.0))
        mm.set_instance_transform(i, Transform3D(orient, Vector3(x, h*0.39, z)))
        var shade: float = rng.randf_range(0.55, 1.0)
        mm.set_instance_color(i, Color(0.22*shade,0.54*shade,0.29*shade,1))
    var grass_field := MultiMeshInstance3D.new()
    grass_field.multimesh = mm
    grass_field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(grass_field)

func _trees() -> void:
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.19
    trunk_mesh.bottom_radius = 0.32
    trunk_mesh.height = 1.0
    trunk_mesh.radial_segments = 7
    var leaf_mesh := _sphere(0.9)
    mat_trunk = _material("6d6251")
    mat_foliage = _material("477b58")
    mat_trunk.vertex_color_use_as_albedo = true
    mat_foliage.vertex_color_use_as_albedo = true
    trunk_instances = MultiMesh.new()
    trunk_instances.transform_format = MultiMesh.TRANSFORM_3D
    trunk_instances.use_colors = true
    trunk_instances.mesh = trunk_mesh
    trunk_instances.instance_count = 135
    crown_instances = MultiMesh.new()
    crown_instances.transform_format = MultiMesh.TRANSFORM_3D
    crown_instances.use_colors = true
    crown_instances.mesh = leaf_mesh
    crown_instances.instance_count = 135 * 5

    var trunk_vis := MultiMeshInstance3D.new()
    trunk_vis.multimesh = trunk_instances
    trunk_vis.material_override = mat_trunk
    add_child(trunk_vis)
    var leaves_vis := MultiMeshInstance3D.new()
    leaves_vis.multimesh = crown_instances
    leaves_vis.material_override = mat_foliage
    add_child(leaves_vis)

    for i in range(135):
        var x: float = rng.randf_range(-51, 51)
        var z: float = rng.randf_range(-44, 40)
        if (absf(x)<4.0 and absf(z)<5.0) or z>6.8 or absf(z+2.7)<1.3:
            x = rng.randf_range(-50, 50)
            z = rng.randf_range(-41, -8)
        var height: float = rng.randf_range(3.7, 6.1)
        var width: float = rng.randf_range(1.6, 2.7)
        var origin := Vector3(x, 0.0, z)
        trees.append({"origin": origin, "hp": 3, "index": i})
        trunk_instances.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1,height,1)), origin + Vector3(0,height*0.5,0)))
        trunk_instances.set_instance_color(i,Color(0.80,0.75,0.64,1.0))
        var crown_centers: Array[Vector3] = [
            Vector3(-0.55,0,0.12),Vector3(0.65,0,0.10),Vector3(0,0,-0.68),
            Vector3(0,0,0.75),Vector3(0,0.66,0)
        ]
        for k in range(5):
            var offset: Vector3 = crown_centers[k]*width
            var leafscale := Vector3(width*0.9, width*0.70, width*0.88)
            var at := origin + Vector3(0,height*0.80,0) + offset
            crown_instances.set_instance_transform(i*5+k,Transform3D(Basis().scaled(leafscale),at))
            var shade: float=rng.randf_range(0.72,1.12)
            crown_instances.set_instance_color(i*5+k,Color(0.32*shade,0.76*shade,0.42*shade,1.0))

func _stones() -> void:
    var mat := _material("627c78")
    var s := _sphere(0.8)
    for i in range(210):
        var x: float = rng.randf_range(-50,50)
        var z: float = rng.randf_range(-45,9)
        if absf(x)<3.0 and absf(z)<3.0:
            continue
        _mesh(s,mat,self,Vector3(x,0.0,z),Vector3(rng.randf_range(0.20,0.60),0.11,rng.randf_range(0.25,0.74)))

func _player() -> void:
    actor = Node3D.new()
    actor.name = "Aren"
    add_child(actor)
    var armor := _material("aebbb0",0.42)
    var cloth := _material("273e43")
    var metal := _material("c5ded4",0.20)
    var face := _material("d4b59a")
    var legs := _material("596066")
    _mesh(CylinderMesh.new(),armor,actor,Vector3(0,1.27,0),Vector3(0.43,0.64,0.32))
    _mesh(_sphere(0.29),face,actor,Vector3(0,2.05,0),Vector3.ONE)
    _mesh(_sphere(0.32),cloth,actor,Vector3(0,2.31,0),Vector3(1.16,0.46,1.08))
    _mesh(_sphere(0.29),armor,actor,Vector3(-0.51,1.59,0),Vector3(0.68,0.93,0.65))
    _mesh(_sphere(0.29),armor,actor,Vector3(0.51,1.59,0),Vector3(0.68,0.93,0.65))
    left_foot = _mesh(_sphere(0.25),legs,actor,Vector3(-0.23,0.35,0),Vector3(0.83,1.75,1.15))
    right_foot = _mesh(_sphere(0.25),legs,actor,Vector3(0.23,0.35,0),Vector3(0.83,1.75,1.15))
    sword = Node3D.new()
    sword.position = Vector3(0.62,1.35,0)
    actor.add_child(sword)
    _mesh(BoxMesh.new(),metal,sword,Vector3(0,0.60,0),Vector3(0.09,1.28,0.08))
    _mesh(BoxMesh.new(),_material("9a794b"),sword,Vector3(0,0.03,0),Vector3(0.47,0.10,0.12))
    actor.position = hero_position

func _enemies() -> void:
    var cloth := _material("724950")
    var face := _material("b4a59b")
    for p in [Vector3(-8,0,-7),Vector3(8,0,-10),Vector3(-4,0,-20),Vector3(14,0,1),Vector3(6,0,-26)]:
        var root := Node3D.new()
        root.position = p
        add_child(root)
        _mesh(CylinderMesh.new(),cloth,root,Vector3(0,0.95,0),Vector3(0.47,0.72,0.41))
        _mesh(_sphere(0.27),face,root,Vector3(0,1.77,0),Vector3.ONE)
        _mesh(_sphere(0.28),cloth,root,Vector3(0,2.01,0),Vector3(1.13,0.43,1.13))
        enemies.append({"node":root,"hp":4,"start":p})

func _camera() -> void:
    camera = Camera3D.new()
    camera.name = "TopDownIsometric"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 22.5
    camera.near = 0.1
    camera.far = 170.0
    camera.current = true
    add_child(camera)
    _sync_camera(1.0)

func _sync_camera(delta: float) -> void:
    var target := hero_position + Vector3(0,0.9,0)
    var at := target + Vector3(0,23,23)
    camera.position = camera.position.lerp(at,minf(1.0,delta*6.0))
    camera.look_at(target,Vector3.UP)

func _rain() -> void:
    rain_particles = CPUParticles3D.new()
    rain_particles.amount = 330
    rain_particles.lifetime = 1.2
    rain_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    rain_particles.emission_box_extents = Vector3(17,6,17)
    rain_particles.direction = Vector3(0,-1,0)
    rain_particles.gravity = Vector3(0,-15,0)
    rain_particles.initial_velocity_min = 2.0
    rain_particles.initial_velocity_max = 6.0
    var drop := SphereMesh.new()
    drop.radius = 0.018
    drop.height = 0.16
    drop.radial_segments = 4
    drop.rings = 2
    rain_particles.mesh = drop
    rain_particles.emitting = false
    rain_particles.position = Vector3(0,8,0)
    add_child(rain_particles)

func _process(delta: float) -> void:
    delta = minf(delta,0.05)
    elapsed += delta
    day_time = fposmod(day_time + delta/340.0,1.0)
    var sunlight_factor: float = 0.52+0.48*maxf(0.0,sin(day_time*TAU-PI*0.5))
    sunlight.light_energy = 0.45 + sunlight_factor*1.6
    environment.ambient_light_energy = 0.76 + sunlight_factor*0.60
    var move := Vector3.ZERO
    if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move.z -= 1
    if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move.z += 1
    if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move.x -= 1
    if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move.x += 1
    if move.length_squared()>0.0:
        move = move.normalized()
        hero_facing = move
        hero_position += move * (6.0 if Input.is_key_pressed(KEY_SHIFT) else 3.8)*delta
        hero_position.x = clampf(hero_position.x,-52,52)
        hero_position.z = clampf(hero_position.z,-44,32)
        actor.rotation.y = atan2(-move.x,-move.z)
        walk_phase += delta * 10.0
    actor.position = hero_position
    left_foot.position.z = 0.15*sin(walk_phase)
    right_foot.position.z = -0.15*sin(walk_phase)
    _sync_camera(delta)
    rain_particles.position = hero_position + Vector3(0,9,0)

    attack_remaining = maxf(0.0,attack_remaining-delta)
    spell_remaining = maxf(0.0,spell_remaining-delta)
    sword.rotation.z = -1.0 + 1.8 * (attack_remaining/0.38) if attack_remaining>0.0 else -0.25
    mp = minf(100,mp+delta*4.0)
    for enemy in enemies:
        var root: Node3D = enemy["node"]
        var offset: Vector3 = hero_position-root.position
        if offset.length()>2.8 and offset.length()<17.0:
            root.position+=offset.normalized()*1.3*delta
        root.position.y = 0.05*sin(elapsed*2.3+root.position.x)

func action(key: int) -> void:
    match key:
        KEY_1, KEY_2, KEY_3:
            weapon = key - KEY_1
            status = "EQUIPPED " + weapon_names[weapon]
        KEY_SPACE:
            attack_remaining = 0.38
            _attack()
        KEY_Q:
            if mp < 20: return
            mp-=20
            spell_remaining=0.6
            _attack(true)
            status="ASPECT OF THE ASHEN FLAME"
        KEY_E:
            _chop()
        KEY_R:
            rain=not rain
            rain_particles.emitting=rain
            status="THE RAIN RETURNS" if rain else "THE STORM HAS PASSED"
        KEY_T:
            day_time=fposmod(day_time+0.15,1.0)
            status="THE BELLS MARK ANOTHER HOUR"

func _attack(magic: bool=false) -> void:
    var reach: float = 8.0 if magic else (3.8 if weapon==2 else 2.4)
    for i in range(enemies.size()-1,-1,-1):
        var root: Node3D = enemies[i]["node"]
        var direction: Vector3 = root.position-hero_position
        if direction.length() < reach and (magic or direction.normalized().dot(hero_facing)>0.0):
            enemies[i]["hp"] = int(enemies[i]["hp"]) - (4 if magic else 2)
            if int(enemies[i]["hp"])<=0:
                root.queue_free()
                enemies.remove_at(i)
                kills+=1
                status="THE OATHBREAKER FALLS"

func _chop() -> void:
    for i in range(trees.size()):
        var t: Dictionary=trees[i]
        if (t["origin"] as Vector3).distance_to(hero_position)<4.2 and int(t["hp"])>0:
            t["hp"]=int(t["hp"])-1
            if int(t["hp"])<=0:
                wood+=2
                var idx: int=int(t["index"])
                trunk_instances.set_instance_transform(idx,Transform3D(Basis(),Vector3(2000,2000,2000)))
                for j in range(5):
                    crown_instances.set_instance_transform(idx*5+j,Transform3D(Basis(),Vector3(2000,2000,2000)))
                status="AN OLD TREE FALLS. +2 WOOD"
            else:
                status="THE TRUNK CRACKS"
            trees[i]=t
            return
    status="NO TREE WITHIN REACH"
