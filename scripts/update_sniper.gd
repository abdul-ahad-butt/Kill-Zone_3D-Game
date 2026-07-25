extends SceneTree

func _init():
    var sniper = load("res://resources/weapon_data/Sniper.tres")
    sniper.can_ads = true
    sniper.ads_fov = 20.0
    ResourceSaver.save(sniper, "res://resources/weapon_data/Sniper.tres")
    print("Sniper updated with ADS capabilities.")
    quit()