extends Equipment
class_name PushbackGun

@export var range := 40.0
@export var recoilImpulse := -30.0
@export var cooldown := 0.12
@export var recoilPlanarRelativeToUp := false   # <- key switch

var fireQueued := false
var cd := 0.0

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		fireQueued = true

func tick(delta: float) -> void:
	cd = max(cd - delta, 0.0)
	if fireQueued and cd <= 0.0:
		fireQueued = false
		cd = cooldown
		_fire()

func _fire() -> void:
	var up := player.currentUp.normalized()
	var camFwd := (-player.cam.global_transform.basis.z).normalized()

	var shotDir := camFwd
	if recoilPlanarRelativeToUp:
		var planar := camFwd - up * camFwd.dot(up)
		if planar.length() > 0.001:
			shotDir = planar.normalized()

	if player.attached:
		player.noStickTimer = 0.08
		player.gravityController.forceDetach()

	# UNSAFE: injected after movement+gravity, right before move_and_slide
	player.addImpulseWorldUnsafe(-shotDir * recoilImpulse)

	var pushbackexplisionparts := preload("res://src/equipment/pushbackGun/push_back_explosion.tscn").instantiate()
	get_tree().root.add_child(pushbackexplisionparts)
	pushbackexplisionparts.global_position = $MeshInstance3D/gunPartSpot.global_position
