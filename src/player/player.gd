extends CharacterBody3D

@onready var pitchNode: Node3D = $gravityControl/yawAxis/pitchAxis
@onready var yawNode: Node3D   = $gravityControl/yawAxis
@onready var rigRoot: Node3D   = $gravityControl
@onready var cam := $gravityControl/yawAxis/pitchAxis/Camera3D
@onready var down_probe := $ShapeCast3D
@onready var hud := $hud
@onready var wallIndicator := $hud/wallIndicator
@onready var trueGroundIndicator := $hud/trueGroundIndicator

@export var arrow_texture_points_up := true  # set true if your arrow image points "up" by default

@export var rig_reorient_rate := 10.0
@export var speed := 15.0
@export var gravity_strength := 90.0 #how strong regular game gravity is
@export var stick_strength := 90.0 # while attached, presses into surface (along -current_up) (doesnt affect much, but should be greater than 10
@export var max_stick_speed := 50.0 # (matters a lot, dictates how sticky you are to a wall )
@export var jump_speed := 30.0 # jump height defined along the current_up (so u jump from a wall upwards)
@export var mouse_sens := 0.001
@export var attach_range := 2.5
@export var pitch_limit := deg_to_rad(85.0)
@export var support_len := 1.3
@export var support_offset := 0.25
@export var auto_attach := true
@export var attach_wall_dot := 0.9        # lower = more willing; 0.6 ≈ "pretty wall-like"
@export var face_dot := 0.4              # camera must face the surface a bit
@export var detach_grace := 0.12         # seconds of allowed probe-miss
var detach_timer := 0.0


var pitch := 0.0
var yaw := 0.0

var current_up := Vector3.UP
var supposedUp := Vector3.UP
var attached := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw   -= event.relative.x * mouse_sens
		pitch -= event.relative.y * mouse_sens
		pitch = clamp(pitch, -pitch_limit, pitch_limit)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		if attached:
			attached = false
			supposedUp = Vector3.UP
		else:
			_try_attach_from_camera()

	_update_up(delta)

	_update_camera_rig(delta)
	_update_player_vel(delta)


	# 3) Move
	move_and_slide()

	var support_n := Vector3.ZERO
	if is_on_floor():
		support_n = get_floor_normal().normalized()
	else:
		support_n = _sample_support_normal()

	if attached:
		if support_n != Vector3.ZERO:
			supposedUp = support_n
			detach_timer = 0.0
		else:
			detach_timer += delta
			if detach_timer > detach_grace:
				attached = false
				supposedUp = Vector3.UP
	else:
		supposedUp = Vector3.UP
		detach_timer = 0.0
		if auto_attach and support_n != Vector3.ZERO:
			print(support_n.dot(Vector3.UP))
			var wall_like := support_n.dot(Vector3.UP) < attach_wall_dot

			var cam_fwd := (-pitchNode.global_transform.basis.z).normalized()
			var facing := cam_fwd.dot(-support_n) > face_dot

			if wall_like and facing:
				attached = true
				supposedUp = support_n


	if (not attached) and is_on_floor():
		var v_up := velocity.dot(current_up)
		if v_up < 0.0:
			velocity -= current_up * v_up

	if Input.is_action_just_pressed("esc"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_update_hud_arrows()






func _updateSupportUp() -> void:
	if is_on_floor():
		supposedUp = get_floor_normal().normalized()
		return

	down_probe.force_shapecast_update()

	#if not down_probe.is_colliding():
		#attached = false
		#supposedUp = Vector3.UP
		#return

	var best_n := Vector3.ZERO
	var best_score := -INF
	for i in range(down_probe.get_collision_count()):
		var n :Vector3= down_probe.get_collision_normal(i).normalized()
		var score := n.dot(current_up)  # higher = more “under” you
		if score > best_score:
			best_score = score
			best_n = n

	if best_score > -INF:
		supposedUp = best_n
	else:
		attached = false
		supposedUp = Vector3.UP
	prints(supposedUp, down_probe.get_collision_count())

func _try_attach_from_camera() -> void:
	var origin := pitchNode.global_position
	var dir := (-pitchNode.global_transform.basis.z).normalized()
	var to := origin + dir * attach_range

	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, to)
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	print(hit)
	if hit.is_empty():
		return
	attached = true
	supposedUp = (hit["normal"] as Vector3).normalized()
	print(supposedUp)



func _update_up(delta: float) -> void:
	var t := 1.0 - exp(-rig_reorient_rate * delta)
	current_up = (current_up * (1.0 - t) + supposedUp.normalized() * t).normalized()

	up_direction = current_up
	floor_max_angle = deg_to_rad(179.0 if attached else  45.0)



func _update_camera_rig(delta: float) -> void:
	var up := current_up.normalized()

	# Pick a reference forward (use where the rig is currently facing), then project onto tangent plane
	var ref_forward := (-rigRoot.global_transform.basis.z).normalized()
	ref_forward = ref_forward - up * ref_forward.dot(up)

	# If near-parallel, choose a safe fallback and project
	if ref_forward.length() < 0.001:
		var tmp := Vector3.FORWARD if (abs(up.dot(Vector3.FORWARD)) < 0.99) else Vector3.RIGHT
		ref_forward = tmp - up * tmp.dot(up)

	var fwd := ref_forward.normalized()
	var right := up.cross(fwd).normalized()

	var target_basis := Basis(right, up, -fwd).orthonormalized()

	rigRoot.global_transform.basis = target_basis

	# Yaw/pitch inside that rotated frame
	yawNode.rotation = Vector3(0.0, yaw, 0.0)
	pitchNode.rotation = Vector3(pitch, 0.0, 0.0)



func _update_player_vel(delta: float) -> void:
	var v2 := Input.get_vector("ui_right", "ui_left", "ui_up", "ui_down")
	var strafe := v2.x
	var forward := -v2.y

	var cam_forward := (-pitchNode.global_transform.basis.z).normalized()
	var fwd := cam_forward - current_up * cam_forward.dot(current_up)

	if fwd.length() < 0.001:
		var rig_fwd := (-rigRoot.global_transform.basis.z).normalized()
		fwd = rig_fwd - current_up * rig_fwd.dot(current_up)
	fwd = fwd.normalized()

	var right := fwd.cross(current_up).normalized()
	var wish_dir := (right * strafe + fwd * forward)
	if wish_dir.length() > 1.0:
		wish_dir = wish_dir.normalized()

	var v_up := velocity.dot(current_up)
	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor():
			v_up = jump_speed
			if attached:
				attached = false
				supposedUp = Vector3.UP
	if attached:
		v_up -= stick_strength * delta
		v_up = max(v_up, -max_stick_speed)
	else:
		if not is_on_floor():
			v_up -= gravity_strength * delta

	# Recompose full velocity: planar + up-axis
	var planar := wish_dir * speed
	velocity = planar + current_up * v_up


func _sample_support_normal() -> Vector3:
	down_probe.force_shapecast_update()

	var best_n := Vector3.ZERO
	var best_score := -INF
	for i in range(down_probe.get_collision_count()):
		var n: Vector3 = down_probe.get_collision_normal(i).normalized()
		var score := n.dot(current_up)
		if score > best_score:
			best_score = score
			best_n = n

	return best_n



func _arrow_angle_from_world_dir(cam: Camera3D, world_dir: Vector3) -> float:
	var v_cam := world_dir.normalized() * cam.global_transform.basis
	if v_cam.z > 0.0:
		v_cam = -v_cam
	var dir2 := Vector2(v_cam.x, -v_cam.y)
	if dir2.length() < 0.001:
		return 999999.0
	return dir2.normalized().angle()



func _update_hud_arrows() -> void:
	var offset := -PI/2 if arrow_texture_points_up else 0.0

	# Ground arrow
	var a_ground := _screen_arrow_angle(cam, Vector3.DOWN)
	if a_ground > 100000.0:
		trueGroundIndicator.visible = false
	else:
		trueGroundIndicator.visible = true
		trueGroundIndicator.rotation = a_ground + offset

	var a_stick := _screen_arrow_angle(cam, -current_up)
	if attached and a_stick <= 100000.0:
		wallIndicator.visible = true
		wallIndicator.rotation = a_stick + offset
	else:
		wallIndicator.visible = false



func _screen_arrow_angle(cam: Camera3D, world_dir: Vector3) -> float:
	var d := world_dir.normalized()
	var right := cam.global_transform.basis.x
	var up    := cam.global_transform.basis.y
	var fwd   := -cam.global_transform.basis.z  # camera forward

	var d_proj := d - fwd * d.dot(fwd)

	if d_proj.length() < 0.001:
		return INF
	var x := d_proj.dot(right)
	var y := d_proj.dot(up)

	return Vector2(x, -y).angle()
