import os

os.makedirs('scenes/buildings', exist_ok=True)

def generate_building(name, dimensions, color, has_interior=True, is_two_story=False):
    w, h, d = dimensions
    tscn = f"""[gd_scene format=3 uid="uid://{name}_uid"]

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_{name}"]
albedo_color = Color({color})

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_{name}_interior"]
albedo_color = Color(0.8, 0.8, 0.8, 1)

[node name="{name}" type="CSGCombiner3D"]
use_collision = true

[node name="Exterior" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {h/2}, 0)
size = Vector3({w}, {h}, {d})
material = SubResource("StandardMaterial3D_{name}")
"""
    if has_interior:
        tscn += f"""
[node name="Interior" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {h/2}, 0)
operation = 2
size = Vector3({w-0.5}, {h-0.5}, {d-0.5})
material = SubResource("StandardMaterial3D_{name}_interior")

[node name="Door" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.25, {d/2})
operation = 2
size = Vector3(1.5, 2.5, 1.0)
material = SubResource("StandardMaterial3D_{name}_interior")

[node name="Window1" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 3.0, 1.5, {d/2})
operation = 2
size = Vector3(2.0, 1.5, 1.0)
material = SubResource("StandardMaterial3D_{name}_interior")

[node name="Window2" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -3.0, 1.5, {d/2})
operation = 2
size = Vector3(2.0, 1.5, 1.0)
material = SubResource("StandardMaterial3D_{name}_interior")
"""
    if is_two_story:
        tscn += f"""
[node name="Staircase" type="CSGBox3D" parent="."]
transform = Transform3D(0.707107, -0.707107, 0, 0.707107, 0.707107, 0, 0, 0, 1, -{(w/2) - 2}, {h/2}, -{(d/2) - 2})
size = Vector3({h}, 0.5, 2.0)
"""
    
    with open(f"scenes/buildings/{name.lower()}.tscn", "w") as f:
        f.write(tscn)

generate_building("PoliceStation", (20, 6, 15), "0.2, 0.3, 0.8, 1", has_interior=True)
generate_building("Apartment", (15, 12, 15), "0.6, 0.4, 0.2, 1", has_interior=True, is_two_story=True)
generate_building("Warehouse", (30, 8, 25), "0.5, 0.5, 0.5, 1", has_interior=True)
generate_building("Market", (20, 4, 15), "0.8, 0.6, 0.2, 1", has_interior=True)
generate_building("Construction", (20, 15, 20), "0.7, 0.7, 0.3, 1", has_interior=False)

os.makedirs('scenes/props', exist_ok=True)

dumpster = """[gd_scene format=3 uid="uid://dumpster_uid"]
[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_dumpster"]
albedo_color = Color(0.1, 0.5, 0.2, 1)

[node name="Dumpster" type="CSGCombiner3D"]
use_collision = true

[node name="Base" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.75, 0)
size = Vector3(2.5, 1.5, 1.5)
material = SubResource("StandardMaterial3D_dumpster")

[node name="Hollow" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.85, 0)
operation = 2
size = Vector3(2.3, 1.5, 1.3)
"""
with open("scenes/props/dumpster.tscn", "w") as f: f.write(dumpster)

vehicle = """[gd_scene format=3 uid="uid://vehicle_uid"]
[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_car"]
albedo_color = Color(0.7, 0.1, 0.1, 1)
[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_tire"]
albedo_color = Color(0.1, 0.1, 0.1, 1)
[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_glass"]
albedo_color = Color(0.1, 0.1, 0.8, 1)
roughness = 0.1

[node name="Vehicle" type="CSGCombiner3D"]
use_collision = true

[node name="Body" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, 0)
size = Vector3(4.0, 0.8, 2.0)
material = SubResource("StandardMaterial3D_car")

[node name="Cabin" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.5, 1.2, 0)
size = Vector3(2.0, 0.8, 1.8)
material = SubResource("StandardMaterial3D_glass")

[node name="Tire1" type="CSGCylinder3D" parent="."]
transform = Transform3D(-4.37114e-08, 1, 0, -1, -4.37114e-08, 0, 0, 0, 1, 1.2, 0.3, 1.0)
radius = 0.3
height = 0.2
material = SubResource("StandardMaterial3D_tire")
[node name="Tire2" type="CSGCylinder3D" parent="."]
transform = Transform3D(-4.37114e-08, 1, 0, -1, -4.37114e-08, 0, 0, 0, 1, 1.2, 0.3, -1.0)
radius = 0.3
height = 0.2
material = SubResource("StandardMaterial3D_tire")
[node name="Tire3" type="CSGCylinder3D" parent="."]
transform = Transform3D(-4.37114e-08, 1, 0, -1, -4.37114e-08, 0, 0, 0, 1, -1.2, 0.3, 1.0)
radius = 0.3
height = 0.2
material = SubResource("StandardMaterial3D_tire")
[node name="Tire4" type="CSGCylinder3D" parent="."]
transform = Transform3D(-4.37114e-08, 1, 0, -1, -4.37114e-08, 0, 0, 0, 1, -1.2, 0.3, -1.0)
radius = 0.3
height = 0.2
material = SubResource("StandardMaterial3D_tire")
"""
with open("scenes/props/vehicle.tscn", "w") as f: f.write(vehicle)
