extends Node3D
class_name Equipment

var player: Player

func on_equip(p: Player) -> void:
	player = p

func on_unequip() -> void:
	pass

func handle_input(event: InputEvent) -> void:
	pass

func tick(delta: float) -> void:
	pass
