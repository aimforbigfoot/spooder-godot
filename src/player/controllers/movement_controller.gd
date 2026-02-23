extends Node
class_name MovementController

@export var externalVelDecay := 18.0        # how fast pushback fades (units: speed per second)
@export var planarAccel := 220.0
@export var planarBrake := 420.0

var externalVel := Vector3.ZERO            # full 3D pushback accumulator
var unsafeImpulse := Vector3.ZERO
var player: Player
var gravityController: GravityController

func setup(p: Player, g: GravityController) -> void:
	player = p
	gravityController = g

func updatePlanarAndJump(delta: float) -> void:
	externalVel = externalVel.move_toward(Vector3.ZERO, externalVelDecay * delta)
	var up := player.currentUp.normalized()
	var baseVel := player.velocity - externalVel
	var v2 := Input.get_vector("ui_right", "ui_left", "ui_up", "ui_down")

	var strafe := v2.x
	var forward := -v2.y

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

	var vUp := baseVel.dot(up)
	var curPlanar := baseVel - up * vUp
	var targetPlanar := wishDir * player.speed

	var rate := planarAccel
	if wishDir.length() < 0.05:
		rate = planarBrake

	curPlanar = curPlanar.move_toward(targetPlanar, rate * delta)

	player.velocity = curPlanar + up * vUp + externalVel

	if Input.is_action_just_pressed("ui_accept") and player.is_on_floor():
		vUp = player.jumpSpeed
		player.velocity = curPlanar + up * vUp + externalVel
		if player.attached:
			gravityController.forceDetach()

func addExternalKickWorld(kick: Vector3) -> void:
	externalVel += kick

func clearExternalKick() -> void:
	externalVel = Vector3.ZERO



func addUnsafeImpulseWorld(imp: Vector3) -> void:
	unsafeImpulse += imp

func consumeUnsafeImpulse() -> Vector3:
	var out := unsafeImpulse
	unsafeImpulse = Vector3.ZERO
	return out
