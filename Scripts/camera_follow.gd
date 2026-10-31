extends Camera3D
## Chase camera. Follows whichever racer it is told to follow.
##
## The race scene (RaceSession) calls follow() once the grid has spawned, so this
## node never searches the tree for its target.

@export var follow_speed: float = 5.0
@export var offset: Vector3 = Vector3(0, 2, 5) # Adjust height and distance
## Optional editor-time target; only used when nothing calls follow().
@export var target_path: NodePath

var target: Node3D = null


func _ready() -> void:
	if not target_path.is_empty():
		follow(get_node_or_null(target_path) as Node3D)


## Points the camera at `node`. Passing null stops the chase.
func follow(node: Node3D) -> void:
	target = node
	if target:
		print("Camera: following %s" % target.name)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	# Chase in the car's own frame, so the camera follows its heading.
	var target_position: Vector3 = target.global_position + target.global_basis * offset
	global_position = global_position.lerp(target_position, follow_speed * delta)
	look_at(target.global_position, Vector3.UP)
