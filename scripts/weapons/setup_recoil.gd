extends SceneTree

func _init():
    # 1. Rifle (up, right, left)
    var rifle = load("res://resources/weapon_data/Rifle.tres")
    var rifle_pattern: Array[Vector2] = []
    for i in range(30):
        if i < 10: rifle_pattern.append(Vector2(0.8, randf_range(-0.1, 0.1))) # Kick up
        elif i < 20: rifle_pattern.append(Vector2(0.2, 0.6)) # Drift right
        else: rifle_pattern.append(Vector2(0.1, -0.7)) # Drift left
    rifle.recoil_pattern = rifle_pattern
    ResourceSaver.save(rifle, "res://resources/weapon_data/Rifle.tres")

    # 2. SMG (less vertical, more jitter)
    var smg = load("res://resources/weapon_data/SMG.tres")
    var smg_pattern: Array[Vector2] = []
    for i in range(40):
        smg_pattern.append(Vector2(0.4, randf_range(-0.4, 0.4)))
    smg.recoil_pattern = smg_pattern
    ResourceSaver.save(smg, "res://resources/weapon_data/SMG.tres")

    # 3. Pistol (low)
    var pistol = load("res://resources/weapon_data/Pistol.tres")
    var pistol_pattern: Array[Vector2] = []
    for i in range(15):
        pistol_pattern.append(Vector2(0.3, randf_range(-0.1, 0.1)))
    pistol.recoil_pattern = pistol_pattern
    ResourceSaver.save(pistol, "res://resources/weapon_data/Pistol.tres")
    
    # 4. Sniper
    var sniper = load("res://resources/weapon_data/Sniper.tres")
    var sniper_pattern: Array[Vector2] = []
    for i in range(10):
        sniper_pattern.append(Vector2(3.0, randf_range(-1.0, 1.0)))
    sniper.recoil_pattern = sniper_pattern
    ResourceSaver.save(sniper, "res://resources/weapon_data/Sniper.tres")
    
    # 5. Shotgun
    var shotgun = load("res://resources/weapon_data/Shotgun.tres")
    var shotgun_pattern: Array[Vector2] = []
    for i in range(8):
        shotgun_pattern.append(Vector2(2.0, randf_range(-0.5, 0.5)))
    shotgun.recoil_pattern = shotgun_pattern
    ResourceSaver.save(shotgun, "res://resources/weapon_data/Shotgun.tres")
    
    print("Recoil patterns generated!")
    quit()