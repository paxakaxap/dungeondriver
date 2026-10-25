extends Camera3D

@export var target_path: NodePath
@export var follow_speed: float = 5.0
@export var offset: Vector3 = Vector3(0, 2, 5) # Adjust height and distance

var target: Node3D

func _ready() -> void:
	if target_path:
		target = get_node(target_path)

func _physics_process(delta: float) -> void:
	if not target:
		return
		
	# Calculate target global position based on car's position + offset
	var target_position = target.global_position + target.global_basis * offset
	
	# Smoothly interpolate current position to target position
	global_position = global_position.lerp(target_position, follow_speed * delta)
	
	# Optional: Look at the car
	look_at(target.global_position, Vector3.UP)
