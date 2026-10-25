extends Area3D
class_name Checkpoint

@export var checkpoint_index: int = 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("on_checkpoint_entered"):
		body.on_checkpoint_entered(self)
