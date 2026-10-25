extends Area3D
class_name StartFinishLine

@export var spawn_markers: Array[Marker3D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("on_start_finish_entered"):
		body.on_start_finish_entered(self)
