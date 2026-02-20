# ================= GravityController.gd (Node) =================
extends Node
class_name GravityController

var player: Player
var movementController: MovementController

func setup(p: Player, m:MovementController) -> void:
	player = p
	movementController = m


func handleInteract() -> void:
	if not Input.is_action_just_pressed("interact"):
		return

	if player.attached:
		forceDetach()
	else:
		tryAttachFromCamera()

func forceDetach() -> void:
	player.attached = false
	player.supposedUp = Vector3.UP
	player.detachTimer = 0.0

func tryAttachFromCamera() -> void:
	var origin := player.pitchNode.global_position
	var dir := (-player.pitchNode.global_transform.basis.z).normalized()
	var to := origin + dir * player.attachRange

	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, to)
	q.exclude = [player]
	var hit := space.intersect_ray(q)

	if hit.is_empty():
		return

	player.attached = true
	player.supposedUp = (hit["normal"] as Vector3).normalized()
	player.detachTimer = 0.0

func updateUpAxis(delta: float) -> void:
	var t := 1.0 - exp(-player.rigReorientRate * delta)
	player.currentUp = (player.currentUp * (1.0 - t) + player.supposedUp.normalized() * t).normalized()

	player.up_direction = player.currentUp
	player.floor_max_angle = deg_to_rad(179.0 if player.attached else 45.0)

func applyVerticalAccel(delta: float) -> void:
	var vUp := player.velocity.dot(player.currentUp)

	if player.attached:
		vUp -= player.stickStrength * delta
		vUp = max(vUp, -player.maxStickSpeed)
	else:
		if not player.is_on_floor():
			vUp -= player.gravityStrength * delta

	# recompose: keep planar from movement controller, replace vertical component
	var planar := player.velocity - player.currentUp * player.velocity.dot(player.currentUp)
	player.velocity = planar + player.currentUp * vUp

func updateAttachmentAfterMove(delta: float) -> void:
	var supportN := Vector3.ZERO
	if player.is_on_floor():
		supportN = player.get_floor_normal().normalized()
	else:
		supportN = sampleSupportNormal()

	if player.attached:
		if supportN != Vector3.ZERO:
			player.supposedUp = supportN
			player.detachTimer = 0.0
		else:
			player.detachTimer += delta
			if player.detachTimer > player.detachGrace:
				forceDetach()
	else:
		player.supposedUp = Vector3.UP
		player.detachTimer = 0.0

		if player.autoAttach and supportN != Vector3.ZERO:
			var wallLike := supportN.dot(Vector3.UP) < player.attachWallDot

			var camFwd := (-player.pitchNode.global_transform.basis.z).normalized()
			var facing := camFwd.dot(-supportN) > player.faceDot

			if wallLike and facing:
				player.attached = true
				player.supposedUp = supportN
				player.detachTimer = 0.0

func clampIntoFloor() -> void:
	# only when free + on floor: remove negative "into floor" component
	if player.attached:
		return
	if not player.is_on_floor():
		return

	var vUp := player.velocity.dot(player.currentUp)
	if vUp < 0.0:
		player.velocity -= player.currentUp * vUp

func sampleSupportNormal() -> Vector3:
	player.downProbe.force_shapecast_update()

	var bestN := Vector3.ZERO
	var bestScore := -INF

	for i in range(player.downProbe.get_collision_count()):
		var n: Vector3 = player.downProbe.get_collision_normal(i).normalized()
		var score := n.dot(player.currentUp)
		if score > bestScore:
			bestScore = score
			bestN = n

	return bestN
