extends Node
class_name MovementController

var player: Player
var gravityController: GravityController

func setup(p: Player, g: GravityController) -> void:
	player = p
	gravityController = g


func updatePlanarAndJump(delta: float) -> void:
	# --- input -> wish direction in the plane ⟂ currentUp ---
	var v2 := Input.get_vector("ui_right", "ui_left", "ui_up", "ui_down")
	var strafe := v2.x
	var forward := -v2.y

	var camForward := (-player.pitchNode.global_transform.basis.z).normalized()
	var fwd := camForward - player.currentUp * camForward.dot(player.currentUp)

	if fwd.length() < 0.001:
		var rigFwd := (-player.rigRoot.global_transform.basis.z).normalized()
		fwd = rigFwd - player.currentUp * rigFwd.dot(player.currentUp)

	fwd = fwd.normalized()
	var right := player.currentUp.cross(fwd).normalized()

	var wishDir := (right * strafe + fwd * forward)
	if wishDir.length() > 1.0:
		wishDir = wishDir.normalized()

	# --- keep current vertical component, replace planar component ---
	var vUp := player.velocity.dot(player.currentUp)
	var planar := wishDir * player.speed
	player.velocity = planar + player.currentUp * vUp

	# --- jump (impulse along +currentUp) ---
	if Input.is_action_just_pressed("ui_accept") and player.is_on_floor():
		vUp = player.jumpSpeed
		player.velocity = planar + player.currentUp * vUp

		# jumping from wall breaks attachment (your current behavior)
		if player.attached:
			gravityController.forceDetach()
