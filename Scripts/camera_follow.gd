extends Camera3D

@export var target_path: NodePath
@export var follow_speed: float = 5.0
@export var offset: Vector3 = Vector3(0, 2, 5) # Adjust height and distance

var target: Node3D

func _ready() -> void:
	# 1. Try exported target_path first
	if not target and not target_path.is_empty():
		target = get_node_or_null(target_path)
	
	# 2. Try finding the car in the "player_car" group
	if not target:
		var player_cars = get_tree().get_nodes_in_group("player_car")
		if player_cars.size() > 0:
			target = player_cars[0] as Node3D
			
	# 3. If still not found (e.g. race_template spawning asynchronously), wait a couple frames and search group or scene
	if not target:
		for i in range(5):
			await get_tree().process_frame
			var player_cars = get_tree().get_nodes_in_group("player_car")
			if player_cars.size() > 0:
				target = player_cars[0] as Node3D
				break
			# Fallback: check by scene node name
			var scene = get_tree().current_scene
			if scene:
				for node in scene.get_children():
					if node.name.begins_with("car_base_a"):
						target = node as Node3D
						break
			if target:
				break
	
	# Automatically set the target_path NodePath so it points to the found car
	if target:
		target_path = get_path_to(target)
		print("Camera successfully attached to target: ", target.name)
	else:
		print("CameraWarning: Could not find target car to follow!")
func _physics_process(delta: float) -> void:
	if not target:
		return
		
	# Calculate target global position based on car's position + offset
	var target_position = target.global_position + target.global_basis * offset
	
	# Smoothly interpolate current position to target position
	global_position = global_position.lerp(target_position, follow_speed * delta)
	
	# Optional: Look at the car
	look_at(target.global_position, Vector3.UP)
