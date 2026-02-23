extends Node
class_name GravityController

var player: Player
var movementController: MovementController

var extraGravityStrength := 0.0
var extraGravityTimer := 0.0

func setup(p: Player, m:MovementController) -> void:
	player = p
	movementController = m

func handleInteract() -> void:
	if not Input.is_action_just_pressed("interact"): return
	if player.attached: forceDetach()
	else: tryAttachFromCamera()

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
	q.exclude = [player.get_rid()] # Use RID for better reliability
	var hit := space.intersect_ray(q)

	if not hit.is_empty():
		player.attached = true
		player.supposedUp = (hit["normal"] as Vector3).normalized()
		player.detachTimer = 0.0

func updateUpAxis(delta: float) -> void:
	var t := 1.0 - exp(-player.rigReorientRate * delta)
	# Smoothly interpolate the "current" up to the "supposed" up
	player.currentUp = player.currentUp.lerp(player.supposedUp, t).normalized()

	player.up_direction = player.currentUp
	# Allow walking on any angle when attached
	player.floor_max_angle = deg_to_rad(179.0 if player.attached else 45.0)


func applyVerticalAccel(delta: float) -> void:
	var up := player.currentUp.normalized()
	# exclude pushback from gravity/stick
	var ext := movementController.externalVel
	var baseVel := player.velocity - ext

	var vUp := baseVel.dot(up)

	if player.attached:
		vUp -= player.stickStrength * delta
		vUp = max(vUp, -player.maxStickSpeed)
	elif not player.is_on_floor():
		vUp -= player.gravityStrength * delta

	if extraGravityTimer > 0.0:
		vUp -= extraGravityStrength * delta
		extraGravityTimer -= delta
		if extraGravityTimer <= 0.0:
			extraGravityStrength = 0.0
			extraGravityTimer = 0.0

	var planar := baseVel - up * baseVel.dot(up)
	player.velocity = planar + up * vUp + ext



func updateAttachmentAfterMove(delta: float) -> void:
	if player.justForceAttached:
		player.justForceAttached = false
		return
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
		if player.autoAttach:
			var vUp_pre := player.preMoveVel.dot(player.currentUp)
			var falling := (not player.is_on_floor()) and (vUp_pre < -0.1)
			if falling:
				var wallN := _bestWallFromSlideCollisions(player.preMoveVel)
				if wallN != Vector3.ZERO:
					player.attached = true
					player.supposedUp = wallN
					return
			# Is the surface wall-like? (Normal horizontal-ish)

			if supportN != Vector3.ZERO:
				var wallLike := supportN.dot(Vector3.UP) < player.attachWallDot
				var camFwd := (-player.pitchNode.global_transform.basis.z).normalized()
				# Are we looking at it?
				var facing := camFwd.dot(-supportN) > player.faceDot

				if wallLike and facing:
					player.attached = true
					player.supposedUp = supportN

func clampIntoFloor() -> void:
	if player.attached or not player.is_on_floor(): return
	if player.gravityController.extraGravityTimer > 0.0: return
	var up := player.currentUp.normalized()
	var ext := movementController.externalVel
	var baseVel := player.velocity - ext

	var vUp := baseVel.dot(up)
	if vUp < 0.0:
		baseVel -= up * vUp

	player.velocity = baseVel + ext

func sampleSupportNormal() -> Vector3:
	# Crucial: Cast the shape slightly "down" relative to player feet
	player.downProbe.target_position = player.to_local(player.global_position - player.currentUp * 0.5)
	player.downProbe.force_shapecast_update()

	var bestN := Vector3.ZERO
	var bestScore := -INF

	for i in range(player.downProbe.get_collision_count()):
		var n: Vector3 = player.downProbe.get_collision_normal(i).normalized()
		# We want the surface most aligned with our feet
		var score := n.dot(player.currentUp)
		if score > bestScore:
			bestScore = score
			bestN = n
	return bestN



func _bestWallFromSlideCollisions(preVel: Vector3) -> Vector3:
	var bestN := Vector3.ZERO
	var bestScore := -INF

	for i in range(player.get_slide_collision_count()):
		var col := player.get_slide_collision(i)
		var n := (col.get_normal() as Vector3).normalized()

		# wall-like: normal is not "up-ish"
		if n.dot(Vector3.UP) >= player.attachWallDot:
			continue

		# require we were moving into the surface (pre-move), not merely grazing
		var approach := preVel.dot(-n)   # >0 means moving toward the wall
		if approach < 0.25:
			continue

		if approach > bestScore:
			bestScore = approach
			bestN = n

	return bestN


func forceAttachToNormal(n: Vector3) -> void:
	player.attached = true
	player.supposedUp = n.normalized()
	player.detachTimer = 0.0
