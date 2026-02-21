extends Node
class_name MovementController

@export var externalPlanarDecay := 8.0
@export var planarAccel := 220.0
@export var planarBrake := 420.0

var externalPlanar := Vector3.ZERO
var player: Player
var gravityController: GravityController

func setup(p: Player, g: GravityController) -> void:
	player = p
	gravityController = g

func updatePlanarAndJump(delta: float) -> void:
	# input -> wishDir in plane ⟂ currentUp
	var v2 := Input.get_vector("ui_right", "ui_left", "ui_up", "ui_down")
	var strafe := v2.x
	var forward := -v2.y
	var up := player.currentUp.normalized()

	var camForward := (-player.pitchNode.global_transform.basis.z).normalized()
	var fwd := camForward - up * camForward.dot(up)

	if fwd.length() < 0.001:
		var rigFwd := (-player.rigRoot.global_transform.basis.z).normalized()
		fwd = rigFwd - up * rigFwd.dot(up)

	fwd = fwd.normalized()
	var right := up.cross(fwd).normalized()

	var wishDir := (right * strafe + fwd * forward)
	if wishDir.length() > 1.0:
		wishDir = wishDir.normalized()

	# decay external kick ONCE
	externalPlanar = externalPlanar.move_toward(Vector3.ZERO, externalPlanarDecay * delta)
	# preserve vertical, steer planar toward target
	var vUp := player.velocity.dot(up)
	var curPlanar := player.velocity - up * vUp
	var targetPlanar := (wishDir * player.speed) + externalPlanar

	var rate := planarAccel
	if wishDir.length() < 0.05:
		rate = planarBrake

	curPlanar = curPlanar.move_toward(targetPlanar, rate * delta)
	player.velocity = curPlanar + up * vUp

	# jump
	if Input.is_action_just_pressed("ui_accept") and player.is_on_floor():
		vUp = player.jumpSpeed
		player.velocity = curPlanar + up * vUp
		if player.attached:
			gravityController.forceDetach()

func addExternalPlanarKickWorld(kick: Vector3) -> void:
	var up := player.currentUp.normalized()
	var planar := kick - up * kick.dot(up)
	externalPlanar += planar

func clearExternalPlanar() -> void:
	externalPlanar = Vector3.ZERO
