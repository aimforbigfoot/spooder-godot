extends Equipment
class_name PushbackGun

@export var range := 40.0
@export var hitImpulse := 25.0         # impulse applied to rigidbodies
@export var recoilImpulse := 30.0       # impulse applied to player (opposite shot dir)
@export var cooldown := 0.12

@export var gravityKick := 80.0         # optional: extra gravity strength
@export var gravityKickTime := 0.08    # optional duration

@export var blastNormalImpulse := 18.0   # pop off surface
@export var blastOnlyWhenSupported := true

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
	var origin := player.cam.global_position
	var dir := (-player.cam.global_transform.basis.z).normalized()
	var to := origin + dir * range

	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, to)
	q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)

	var u := player.currentUp.normalized()
	var v := -dir * recoilImpulse
	var v_vert := u * v.dot(u)
	var v_plan := v - v_vert
	print("vert=", v_vert.length(), " planar=", v_plan.length(), " dot=", v.normalized().dot(u))

	if player.attached:
		player.noStickTimer = 0.08
		player.gravityController.forceDetach()
	player.addImpulseWorld(-dir * recoilImpulse)

	# optional gravity hook (this is separate from blast-off)
	#if gravityKick > 0.0 and gravityKickTime > 0.0:
		#player.gravityController.addExtraGravity(gravityKick, gravityKickTime)


	if hit.is_empty():
		return

