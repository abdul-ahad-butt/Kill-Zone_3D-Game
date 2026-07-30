import os

tscn = """[gd_scene load_steps=18 format=3 uid="uid://world_uid"]

[ext_resource type="Script" path="res://scripts/match/world.gd" id="1_world"]
[ext_resource type="PackedScene" path="res://scenes/ui/main_menu.tscn" id="2_menu"]
[ext_resource type="Script" path="res://scripts/environment/map_decorator.gd" id="5_decorator"]
[ext_resource type="Script" path="res://scripts/environment/weather_manager.gd" id="6_weather"]
[ext_resource type="PackedScene" path="res://scenes/environment/rain_particles.tscn" id="7_rain"]
[ext_resource type="Material" path="res://resources/materials/concrete.tres" id="8_concrete"]
[ext_resource type="Material" path="res://resources/materials/dirt.tres" id="9_dirt"]
[ext_resource type="Material" path="res://resources/materials/asphalt.tres" id="10_asphalt"]

[ext_resource type="PackedScene" uid="uid://policestation_uid" path="res://scenes/buildings/policestation.tscn" id="11_police"]
[ext_resource type="PackedScene" uid="uid://apartment_uid" path="res://scenes/buildings/apartment.tscn" id="12_apartment"]
[ext_resource type="PackedScene" uid="uid://warehouse_uid" path="res://scenes/buildings/warehouse.tscn" id="13_warehouse"]
[ext_resource type="PackedScene" uid="uid://market_uid" path="res://scenes/buildings/market.tscn" id="14_market"]
[ext_resource type="PackedScene" uid="uid://construction_uid" path="res://scenes/buildings/construction.tscn" id="15_construction"]
[ext_resource type="PackedScene" uid="uid://dumpster_uid" path="res://scenes/props/dumpster.tscn" id="16_dumpster"]
[ext_resource type="PackedScene" uid="uid://vehicle_uid" path="res://scenes/props/vehicle.tscn" id="17_vehicle"]

[sub_resource type="NavigationMesh" id="NavigationMesh_nav1"]

[sub_resource type="ProceduralSkyMaterial" id="ProceduralSkyMaterial_7r4gi"]
sky_top_color = Color(0.3, 0.45, 0.6, 1)
sky_horizon_color = Color(0.6, 0.7, 0.8, 1)
ground_bottom_color = Color(0.15, 0.15, 0.15, 1)
ground_horizon_color = Color(0.6, 0.7, 0.8, 1)

[sub_resource type="Sky" id="Sky_w7kh3"]
sky_material = SubResource("ProceduralSkyMaterial_7r4gi")

[sub_resource type="Environment" id="Environment_e3hyu"]
background_mode = 2
sky = SubResource("Sky_w7kh3")
ambient_light_source = 3
tonemap_mode = 3
ssao_enabled = true
sdfgi_enabled = true
sdfgi_use_occlusion = true
fog_enabled = true
fog_light_color = Color(0.6, 0.7, 0.8, 1)
fog_density = 0.003
fog_sky_affect = 0.5
volumetric_fog_enabled = true
volumetric_fog_density = 0.0
volumetric_fog_albedo = Color(0.65, 0.75, 0.85, 1)

[node name="World" type="Node3D" unique_id=65326711]
script = ExtResource("1_world")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="." unique_id=1437765875]
transform = Transform3D(0.707107, -0.5, 0.5, 0, 0.707107, 0.707107, -0.707107, -0.5, 0.5, 0, 20, 0)
shadow_enabled = true
shadow_blur = 1.5
directional_shadow_mode = 2
directional_shadow_fade_start = 1.0
directional_shadow_max_distance = 200.0

[node name="NavigationRegion3D" type="NavigationRegion3D" parent="." unique_id=778866495]
navigation_mesh = SubResource("NavigationMesh_nav1")

[node name="MapGeometry" type="Node3D" parent="NavigationRegion3D" unique_id=1309501952]

[node name="Ground" type="CSGBox3D" parent="NavigationRegion3D/MapGeometry" unique_id=319492723]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)
size = Vector3(120, 1, 200)
material = ExtResource("9_dirt")
use_collision = true

[node name="Street" type="CSGBox3D" parent="NavigationRegion3D/MapGeometry" unique_id=987654321]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.05, 0)
size = Vector3(20, 0.1, 180)
material = ExtResource("10_asphalt")
use_collision = true

[node name="PoliceStation" parent="NavigationRegion3D/MapGeometry" instance=ExtResource("11_police")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -25, 0, 80)

[node name="Apartment" parent="NavigationRegion3D/MapGeometry" instance=ExtResource("12_apartment")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -20, 0, 40)

[node name="Warehouse" parent="NavigationRegion3D/MapGeometry" instance=ExtResource("13_warehouse")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -25, 0, -20)

[node name="Market" parent="NavigationRegion3D/MapGeometry" instance=ExtResource("14_market")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 25, 0, -20)

[node name="Construction" parent="NavigationRegion3D/MapGeometry" instance=ExtResource("15_construction")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -60)

[node name="Dumpster1" parent="NavigationRegion3D/MapGeometry" instance=ExtResource("16_dumpster")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 0, 60)

[node name="Dumpster2" parent="NavigationRegion3D/MapGeometry" instance=ExtResource("16_dumpster")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 0, -10)

[node name="Vehicle1" parent="NavigationRegion3D/MapGeometry" instance=ExtResource("17_vehicle")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -5, 0, 50)

[node name="Vehicle2" parent="NavigationRegion3D/MapGeometry" instance=ExtResource("17_vehicle")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 0, -30)

[node name="SiteA" type="CSGBox3D" parent="NavigationRegion3D/MapGeometry" unique_id=532743647]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -30, 4, 10)
size = Vector3(16, 8, 16)
material = ExtResource("8_concrete")
use_collision = true

[node name="InteriorA" type="CSGBox3D" parent="NavigationRegion3D/MapGeometry/SiteA" unique_id=286601313]
operation = 2
size = Vector3(15, 7, 15)

[node name="DoorA" type="CSGBox3D" parent="NavigationRegion3D/MapGeometry/SiteA" unique_id=648600101]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 8, -2.5, 0)
operation = 2
size = Vector3(2, 3, 4)

[node name="SiteB" type="CSGBox3D" parent="NavigationRegion3D/MapGeometry" unique_id=255748011]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 30, 4, 10)
size = Vector3(16, 8, 16)
material = ExtResource("8_concrete")
use_collision = true

[node name="InteriorB" type="CSGBox3D" parent="NavigationRegion3D/MapGeometry/SiteB" unique_id=1418701831]
operation = 2
size = Vector3(15, 7, 15)

[node name="DoorB" type="CSGBox3D" parent="NavigationRegion3D/MapGeometry/SiteB" unique_id=1018596001]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -8, -2.5, 0)
operation = 2
size = Vector3(2, 3, 4)

[node name="WorldEnvironment" type="WorldEnvironment" parent="." unique_id=1949168902]
environment = SubResource("Environment_e3hyu")

[node name="WeatherManager" type="Node3D" parent="." unique_id=1073846669]
script = ExtResource("6_weather")

[node name="RainParticles" parent="WeatherManager" unique_id=1481541002 instance=ExtResource("7_rain")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 20, 0)
emitting = false

[node name="MapDecorator" type="Node3D" parent="." unique_id=648010411]
script = ExtResource("5_decorator")

[node name="Spawns" type="Node3D" parent="."]

[node name="Police" type="Node3D" parent="Spawns"]

[node name="Spawn1" type="Marker3D" parent="Spawns/Police"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2, 0, 90)
[node name="Spawn2" type="Marker3D" parent="Spawns/Police"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2, 0, 90)
[node name="Spawn3" type="Marker3D" parent="Spawns/Police"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2, 0, 85)
[node name="Spawn4" type="Marker3D" parent="Spawns/Police"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2, 0, 85)
[node name="Spawn5" type="Marker3D" parent="Spawns/Police"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 88)

[node name="Terrorist" type="Node3D" parent="Spawns"]

[node name="Spawn1" type="Marker3D" parent="Spawns/Terrorist"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2, 0, -80)
[node name="Spawn2" type="Marker3D" parent="Spawns/Terrorist"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2, 0, -80)
[node name="Spawn3" type="Marker3D" parent="Spawns/Terrorist"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2, 0, -85)
[node name="Spawn4" type="Marker3D" parent="Spawns/Terrorist"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2, 0, -85)
[node name="Spawn5" type="Marker3D" parent="Spawns/Terrorist"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -82)

[node name="MainMenu" parent="." instance=ExtResource("2_menu")]
"""

with open("scenes/world.tscn", "w") as f:
    f.write(tscn)
