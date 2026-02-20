extends Node3D

@onready var animatedBody: AnimatableBody3D = $AnimatableBody3D

@export var pointA: Vector3
@export var pointB: Vector3
@export var moveSpeed := 5.0

@export var canSpin := false
@export var spinCw := true
@export var spinSpeedDeg := 90.0   # degrees / second
@export var spinAxisLocal := Vector3.UP  # local axis to spin around

var startPos: Vector3
var startBasis: Basis

var t := 0.0
var dir := 1.0
var spinAngleRad := 0.0

func _ready() -> void:
	startPos = global_position
	startBasis = global_basis

func _physics_process(delta: float) -> void:
	# --- translation ping-pong ---
	var dist: float = max(pointA.distance_to(pointB), 0.001)
	t += dir * (moveSpeed / dist) * delta

	if t >= 1.0:
		t = 1.0
		dir = -1.0
	elif t <= 0.0:
		t = 0.0
		dir = 1.0

	global_position = startPos + pointA.lerp(pointB, t)

	# --- optional spin ---
	if canSpin:
		var sgn := -1.0 if spinCw else 1.0
		spinAngleRad += deg_to_rad(spinSpeedDeg) * sgn * delta

		# spinAxisLocal is in THIS Node3D's local space; keep it normalized
		var axis := spinAxisLocal.normalized()
		global_basis = startBasis * Basis(axis, spinAngleRad)
	else:
		# if you turn spinning off at runtime, snap back to the original orientation
		global_basis = startBasis
