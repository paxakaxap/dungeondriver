extends Camera3D

@export var target_path: NodePath
@export var follow_speed: float = 5.0
@export var offset: Vector3 = Vector3(0, 2, 5) # Adjust height and distance

var target: Node3D

func _ready() -> void:
	# Try to find the target if not set via NodePath or if it failed
	if not target and target_path:
		target = get_node_or_null(target_path)
	
	# If still no target, try to find the car after it has been spawned
	if not target:
		await get_tree().process_frame
		var scene = get_tree().current_scene
		for node in scene.get_children():
			if node.name.begins_with("car_base_a"):
				target = node
				break
func _physics_process(delta: float) -> void:
	if not target:
		return
		
	# Calculate target global position based on car's position + offset
	var target_position = target.global_position + target.global_basis * offset
	
	# Smoothly interpolate current position to target position
	global_position = global_position.lerp(target_position, follow_speed * delta)
	
	# Optional: Look at the car
	look_at(target.global_position, Vector3.UP)
