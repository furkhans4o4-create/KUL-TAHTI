extends Node2D

# This is a real 2D procedural Godot environment. The final visible frame is
# converted to ASCII glyphs by the compositing shader on the parent Control.
const EXTENT := Vector2(3200.0,2500.0)
const TAU_F := PI * 2.0
const EARTH := Color("080f10")
const MOSS := Color("243b2b")
const BARK := Color("5a5749")
const PINE := Color("4b8060")
const SILVER := Color("9cb8ac")
const GOLD := Color("d8aa68")

var hero := Vector2(1540.0,800.0)
var facing := Vector2(0,1)
var walk_phase := 0.0
var timer := 0.0
var day_time := 0.32
var light := 0.75
var wind := 0.0
var rain := false
var hp := 100.0
var mp := 100.0
var wood := 0
var kills := 0
var weapon := 0
var weapon_names := ["LONGSWORD","AXE","SPEAR"]
var status := "THE OLD KING IS DEAD. THE ROOTS REMEMBER."
var attack_time := 0.0
var spell_time := 0.0
var blast_at := Vector2.ZERO
var trees: Array[Dictionary] = []
var grass: Array[Dictionary] = []
var rocks: Array[Vector2] = []
var enemies: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var ruin_health := 4

func _ready() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 711390
    for i in range(260):
        var p := Vector2(rng.randf_range(70,EXTENT.x-70),rng.randf_range(50,EXTENT.y-50))
        if p.y > _bank(p.x)-35 or p.distance_to(hero)<130:
            continue
        var radius := rng.randf_range(42,85)
        trees.append({"p":p,"r":radius,"phase":rng.randf()*TAU_F,"hp":3,"type":i%3})
    trees.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return a["p"].y < b["p"].y)
    for i in range(4400):
        var p := Vector2(rng.randf_range(0,EXTENT.x),rng.randf_range(0,EXTENT.y))
        if p.y > _bank(p.x)-20 or absf(p.y - (760.0 + 17.0*sin(p.x*0.013))) < 58.0 or p.distance_to(hero) < 90.0: continue
        grass.append({"p":p,"height":rng.randf_range(8,22),"phase":rng.randf()*TAU_F,"kind":i%13})
    for i in range(350):
        var p := Vector2(rng.randf_range(0,EXTENT.x),rng.randf_range(0,EXTENT.y))
        if p.y < _bank(p.x)-10:
            rocks.append(p)
    enemies = [
        {"p":Vector2(1370,725),"health":4,"phase":1.0},
        {"p":Vector2(1660,660),"health":4,"phase":2.0},
        {"p":Vector2(1500,520),"health":4,"phase":3.0},
        {"p":Vector2(1810,910),"health":4,"phase":4.0}
    ]
    set_process(true)

func _bank(x: float) -> float:
    return 1060.0 + 43.0*sin(x*0.004) + 17.0*sin(x*0.017)

func _process(dt: float) -> void:
    dt = minf(dt,0.055)
    timer += dt
    day_time = fposmod(day_time + dt/330.0,1.0)
    light = 0.42 + 0.58*(0.5+0.5*sin(day_time*TAU_F-PI*0.5))
    wind = 6.0*sin(timer*0.71)+3.0*sin(timer*1.63)
    mp = minf(100.0,mp+dt*5.0)
    attack_time = maxf(0.0,attack_time-dt)
    spell_time = maxf(0.0,spell_time-dt)
    var move := Vector2.ZERO
    if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move.y -= 1
    if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move.y += 1
    if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move.x -= 1
    if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move.x += 1
    if move.length_squared()>0:
        move = move.normalized()
        facing = move
        var speed := 175.0 if Input.is_key_pressed(KEY_SHIFT) else 105.0
        hero = (hero+move*speed*dt).clamp(Vector2(45,45),EXTENT-Vector2(45,45))
        walk_phase += dt*(16.0 if speed>140 else 10.0)
    for j in range(enemies.size()):
        var e: Dictionary = enemies[j]
        var ep: Vector2 = e["p"]
        var d: float = ep.distance_to(hero)
        if d < 215.0 and d > 46.0:
            ep += (hero-ep).normalized()*34.0*dt
        else:
            ep += Vector2(cos(timer*0.5+float(e["phase"])),sin(timer*0.4+float(e["phase"])))*3.0*dt
        e["p"]=ep
        enemies[j]=e
    for j in range(sparks.size()-1,-1,-1):
        var s: Dictionary=sparks[j]
        s["ttl"]=float(s["ttl"])-dt
        if s["ttl"]<=0.0:
            sparks.remove_at(j)
        else:
            s["p"]=s["p"]+s["v"]*dt
            sparks[j]=s
    queue_redraw()

func action(key: int) -> void:
    match key:
        KEY_1, KEY_2, KEY_3:
            weapon = key-KEY_1
            status = "EQUIPPED "+weapon_names[weapon]
        KEY_SPACE:
            attack_time = 0.33
            var reach: float = float([76.0,65.0,122.0][weapon])
            for j in range(enemies.size()-1,-1,-1):
                var e: Dictionary=enemies[j]
                var v: Vector2=e["p"]-hero
                if v.length() < reach and v.normalized().dot(facing)>0.05:
                    e["health"]=int(e["health"])-(2 if weapon==1 else 1)
                    _emit(e["p"],Color("dc6f64"),24)
                    if int(e["health"])<=0:
                        enemies.remove_at(j)
                        kills+=1
                        status="THE OATHBREAKER FALLS."
                    else:
                        enemies[j]=e
            if weapon==1: _chop()
        KEY_Q:
            if mp<20: return
            mp-=20
            spell_time=0.65
            blast_at=hero+facing*130.0
            _emit(blast_at,Color("f1bf64"),70)
            status="ASHEN FLAME."
            for j in range(enemies.size()-1,-1,-1):
                if (enemies[j]["p"] as Vector2).distance_to(blast_at)<110:
                    enemies.remove_at(j)
                    kills+=1
        KEY_E:
            _chop()
        KEY_R:
            rain=not rain
            status="THE RAIN RETURNS." if rain else "THE STORM HAS PASSED."
        KEY_T:
            day_time=fposmod(day_time+0.19,1.0)
            status="THE BELLS MARK ANOTHER HOUR."

func _chop() -> void:
    for j in range(trees.size()-1,-1,-1):
        var tree: Dictionary=trees[j]
        if (tree["p"] as Vector2).distance_to(hero)<100:
            tree["hp"]=int(tree["hp"])-1
            _emit(tree["p"]-Vector2(0,48),Color("81bb74"),34)
            if int(tree["hp"])<=0:
                trees.remove_at(j)
                wood+=2
                status="AN OLD TREE FALLS. +2 WOOD."
            else:
                trees[j]=tree
                status="THE TRUNK CRACKS."
            return
    if hero.distance_to(Vector2(1710,540))<130 and ruin_health>0:
        ruin_health-=1
        _emit(Vector2(1710,530),Color("979181"),35)
        status="THE RUIN CRUMBLES."
        if ruin_health==0: status="THE WATCHTOWER COLLAPSES."

func _emit(at: Vector2, hue: Color, count: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed=int(timer*100000.0)+count
    for i in range(count):
        sparks.append({"p":at,"v":Vector2.from_angle(rng.randf()*TAU_F)*rng.randf_range(35,165),"ttl":rng.randf_range(0.3,0.95),"hue":hue})

func _col(c: Color, factor: float=1.0) -> Color:
    return Color(c.r*light*factor,c.g*light*factor,c.b*(0.5+0.5*light)*factor,c.a)

func _screen(p: Vector2,center: Vector2)->Vector2:
    return p-hero+center

func _in(p: Vector2,size: Vector2,pad: float=140.0)->bool:
    return p.x>-pad and p.x<size.x+pad and p.y>-pad and p.y<size.y+pad

func _draw() -> void:
    var size := get_viewport_rect().size
    var center := size*0.5
    _ground(size,center)
    _river(size,center)
    _foliage(size,center)
    for p in rocks:
        var sp := _screen(p,center)
        if _in(sp,size,25):
            draw_circle(sp+Vector2(0,2),6,_col(Color("243a35")))
            draw_circle(sp,3,_col(Color("607168")))
    for t in trees:
        if (t["p"] as Vector2).y <= hero.y and _in(_screen(t["p"],center),size,210):
            _tree(t,center)
    _ruin(center)
    for e in enemies:
        if (e["p"] as Vector2).y<=hero.y: _enemy(e,center)
    _hero(center)
    for e in enemies:
        if (e["p"] as Vector2).y>hero.y: _enemy(e,center)
    for t in trees:
        if (t["p"] as Vector2).y>hero.y and _in(_screen(t["p"],center),size,210):
            _tree(t,center)
    _effects(size,center)
    if rain: _rain(size)
    _ambient(size,center)

func _ground(size: Vector2,center: Vector2)->void:
    draw_rect(Rect2(Vector2.ZERO,size),_col(EARTH,0.8),true)
    var offset := hero-center
    var start_x := int(floor(offset.x/34.0))-2
    var start_y := int(floor(offset.y/34.0))-2
    for gy in range(start_y,start_y+int(size.y/34.0)+5):
        for gx in range(start_x,start_x+int(size.x/34.0)+5):
            var world := Vector2(float(gx)*34.0,float(gy)*34.0)
            if world.y>_bank(world.x): continue
            var hash := fposmod(sin(float(gx)*77.21+float(gy)*13.61)*43758.55,1.0)
            var screen_pos:=_screen(world,center)
            if hash>.91:
                draw_circle(screen_pos+Vector2(15,16),12,_col(Color("20382d"),0.34))
            if hash>.92:
                draw_circle(screen_pos,8,_col(Color("33523a"),0.27))
    var path_sp:=_screen(Vector2(1590,760),center)
    for i in range(150):
        var q := Vector2(path_sp.x + (float(i)-75)*9, path_sp.y + 17*sin(float(i)*0.13))
        if _in(q,size,70):
            draw_circle(q,23,_col(Color("514936"),0.12))

func _river(size: Vector2,center: Vector2)->void:
    var offset := hero-center
    var poly := PackedVector2Array()
    poly.append(Vector2(0,size.y+10))
    poly.append(Vector2(size.x,size.y+10))
    for i in range(65,-1,-1):
        var x := float(i)*size.x/65.0
        poly.append(Vector2(x,_bank(x+offset.x)-offset.y))
    draw_colored_polygon(poly,_col(Color("071827"),0.90))
    for i in range(450):
        var wx: float = floor(offset.x/15.0)*15.0+float(i%110)*15.0
        var wy: float = floor(offset.y/16.0)*16.0+float(i/110)*16.0
        var sy: float=wy-offset.y
        var sx: float=wx-offset.x
        if wy<_bank(wx)+5: continue
        if sy<-30 or sy>size.y+20 or sx<-30 or sx>size.x+30: continue
        var wav := 4.0*sin(wx*0.025+timer*1.8+wy*0.012)
        draw_line(Vector2(sx+wav,sy),Vector2(sx+wav+10.0+4*sin(timer+wx*.2),sy),_col(Color("79b0bb"),0.9),1.8)
    # Reflections are mirrored and displaced silhouettes of nearby trees.
    for t in trees:
        var p: Vector2=t["p"]
        var shore:=_bank(p.x)
        if shore-p.y>190 or shore-p.y<0: continue
        var q:=_screen(Vector2(p.x,shore+(shore-p.y)*0.62+45),center)
        if not _in(q,size,135): continue
        var r: float=t["r"]
        for j in range(7):
            var ry:=float(j)*9.0
            var sway:=sin(timer*1.9+ry*0.25+p.x)*5.0
            draw_line(q+Vector2(-r*0.4+sway,ry),q+Vector2(r*0.4+sway,ry),_col(PINE,0.67),3.2)
    for i in range(95):
        var wx:=float(i)*34.0
        var b :=_bank(wx)+2.0
        var q:=_screen(Vector2(wx,b),center)
        if _in(q,size,60):
            draw_circle(q,6,_col(Color("739a8b"),0.24))

func _foliage(size: Vector2,center: Vector2)->void:
    for grass_blade in grass:
        var p: Vector2=grass_blade["p"]
        var sp:=_screen(p,center)
        if not _in(sp,size,36): continue
        var h: float=grass_blade["height"]
        var sway:=sin(timer*1.75+float(grass_blade["phase"]))*h*.32+wind*.42
        var c := _col(Color("7bb68a") if int(grass_blade["kind"])%4==0 else Color("4a8560"),0.86+0.20*sin(float(grass_blade["phase"])))
        draw_line(sp,sp+Vector2(sway,-h),c,2.2)
        if int(grass_blade["kind"])==0:
            draw_line(sp+Vector2(2,0),sp+Vector2(sway*0.7+5,-h*0.7),_col(Color("a0be79"),0.9),2.0)
    for i in range(150):
        var p:=Vector2(float((i*733)%3100)+20,float((i*311)%2250)+20)
        var s:=_screen(p,center)
        if _in(s,size,10) and p.y<_bank(p.x):
            var glow:=0.5+0.5*sin(timer*2.8+float(i)*1.23)
            draw_circle(s+Vector2(2*sin(timer+float(i)),2*cos(timer*0.4+float(i))),1.7,_col(Color("efcf83"),0.3+glow*1.5))

func _tree(t: Dictionary,center: Vector2)->void:
    var p: Vector2=_screen(t["p"],center)
    var radius: float=t["r"]
    var sway:=wind*0.7+5.0*sin(timer*0.8+float(t["phase"]))
    draw_circle(p+Vector2(3,8),radius*0.65,_col(Color("0d201e"),0.65))
    draw_line(p,p+Vector2(sway*.4,-radius*1.20),_col(BARK,0.78),7.0)
    draw_line(p-Vector2(3,17),p+Vector2(12,3),_col(BARK,0.55),4.0)
    var crow:=p+Vector2(sway,-radius*1.25)
    for j in range(8):
        var angle:=float(j)*TAU_F/8.0+float(t["phase"])
        var o:=Vector2(cos(angle),sin(angle))*radius*.39
        draw_circle(crow+o,radius*.54,_col(Color("27533d"),0.9))
    draw_circle(crow,radius*.68,_col(Color("356e4e"),0.92))
    for j in range(30):
        var a:=float(j)*2.399963+float(t["phase"])
        var rr:=sqrt(float(j)/30.0)*radius*.86
        var leaf:=crow+Vector2(cos(a),sin(a))*rr
        var colr:=Color("a1cc90") if j%5==0 else Color("579b70")
        draw_circle(leaf,5.5 if j%5==0 else 3.0,_col(colr,0.60+(float(j%4)*.14)))

func _body(pos: Vector2, cloaked: bool, swing: float)->void:
    draw_ellipse_shadow(pos)
    var torso:=pos+Vector2(0,-21)
    var wool:=_col(Color("895368") if cloaked else Color("aebdb6"),1.45)
    draw_line(torso+Vector2(-5,16),pos+Vector2(-6+sin(swing)*4,0),_col(Color("5c666b")),5)
    draw_line(torso+Vector2(5,16),pos+Vector2(6-sin(swing)*4,0),_col(Color("596465")),5)
    var cloak:=PackedVector2Array([torso+Vector2(-11,-7),torso+Vector2(11,-7),pos+Vector2(10,7),pos+Vector2(-12,7)])
    draw_colored_polygon(cloak,wool)
    draw_circle(torso+Vector2(0,-12),9,_col(Color("d0b39a"),1.45))
    draw_line(torso+Vector2(-8,-6),torso+Vector2(-11,9+sin(swing)*2),wool,5)
    draw_line(torso+Vector2(8,-6),torso+Vector2(11,10-sin(swing)*2),wool,5)
    draw_circle(torso+Vector2(0,-16),3,_col(Color("d9c7af"),1.00))

func draw_ellipse_shadow(p: Vector2)->void:
    draw_circle(p+Vector2(0,5),16,_col(Color("0a1518"),0.5))

func _hero(center: Vector2)->void:
    _body(center,false,walk_phase)
    var p:=center+Vector2(10,-19)
    var blade:=facing
    if attack_time>0.0:
        var k:=1.0-attack_time/.33
        blade=Vector2.from_angle(-2.2+k*3.7)
        draw_arc(center,49,blade.angle()-.35,blade.angle()+.4,14,_col(Color("d6e4cc"),1.3),4,true)
    var length:=65.0 if weapon==2 else (43.0 if weapon==0 else 35.0)
    var edge:=p+blade*length
    draw_line(p,edge,_col(Color("d7ded1") if weapon!=1 else Color("c6ab75"),1.2),3.0)
    draw_circle(p,_col(GOLD).r*3+2,_col(GOLD,1.3))

func _enemy(e: Dictionary,center: Vector2)->void:
    var p:=_screen(e["p"],center)
    if not _in(p,get_viewport_rect().size,30): return
    _body(p,true, timer*2.0)
    draw_circle(p+Vector2(-4,-35),2,_col(Color("f38b7e"),1.3))
    draw_circle(p+Vector2(4,-35),2,_col(Color("f38b7e"),1.3))

func _ruin(center: Vector2)->void:
    if ruin_health<=0: return
    var p:=_screen(Vector2(1710,540),center)
    if not _in(p,get_viewport_rect().size,90): return
    draw_rect(Rect2(p+Vector2(-39,-56),Vector2(78,55)),_col(Color("393e3a"),0.87),true)
    draw_rect(Rect2(p+Vector2(-31,-48),Vector2(62,42)),_col(Color("6a685c"),0.7),true)
    draw_rect(Rect2(p+Vector2(-14,-35),Vector2(28,26)),_col(Color("131b19"),0.75),true)
    for i in range(5):
        draw_line(p+Vector2(-40+i*20,-54),p+Vector2(-40+i*20,-68),_col(Color("8b8270")),7.0)

func _effects(size: Vector2,center: Vector2)->void:
    if spell_time>0.0:
        var p:=_screen(blast_at,center)
        var radius:=110.0*(1.0-spell_time/0.65)+7.0
        draw_arc(p,radius,0,TAU_F,45,_col(Color("f0b654"),spell_time*1.6),4.0,true)
        draw_circle(p,18*spell_time,_col(Color("ffcf74"),1.9))
    for s in sparks:
        var p:=_screen(s["p"],center)
        draw_line(p,p-((s["v"] as Vector2).normalized()*6.0),_col(s["hue"],maxf(0.1,float(s["ttl"])*1.7)),2.0)

func _rain(size: Vector2)->void:
    for i in range(280):
        var x:=fposmod(float((i*791)%3401)+timer*110.0,size.x)
        var y:=fposmod(float((i*1093)%2801)+timer*300.0,size.y)
        draw_line(Vector2(x,y),Vector2(x-6,y+18),_col(Color("6c95ab"),0.65),1.4)

func _ambient(size: Vector2,center: Vector2)->void:
    # Warm torch glow and dusk fireflies are painted into the source frame,
    # so the GPU renderer represents them using the same ASCII letters.
    var torch:=_screen(Vector2(1710,555),center)
    if _in(torch,size,90):
        var glow:=0.76+0.24*sin(timer*9.0)
        draw_circle(torch,17,_col(Color("ef9a47"),0.3*glow))
        draw_circle(torch,7,_col(Color("f9c875"),1.5*glow))
