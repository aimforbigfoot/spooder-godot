extends Node
class_name EquipmentManager

@export var starting_equipment: PackedScene
@export var equipment_list: Array[PackedScene] = []  # optional inventory

var player: Player
var gravityController : GravityController
var movementController : MovementController
var current: Equipment
var current_index := 0

func setup(p: Player, g:GravityController, m:MovementController) -> void:
	player = p
	gravityController = g
	movementController = m
	if starting_equipment:
		equip_scene(starting_equipment)

func equip_scene(scene: PackedScene) -> void:
	if current:
		current.on_unequip()
		current.queue_free()

	var inst := scene.instantiate() as Equipment
	current = inst

	# attach to a socket that follows camera aim
	player.pitchNode.add_child(current)  # or player.get_node(".../HandSocket")
	current.on_equip(player)

func unequip() -> void:
	if not current: return
	current.on_unequip()
	current.queue_free()
	current = null

func handle_input(event: InputEvent) -> void:
	if current:
		current.handle_input(event)

func tick(delta: float) -> void:
	if current:
		current.tick(delta)

func equip_next() -> void:
	if equipment_list.is_empty(): return
	current_index = (current_index + 1) % equipment_list.size()
	equip_scene(equipment_list[current_index])
