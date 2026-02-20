extends CharacterBody3D
class_name Player

@onready var pitchNode: Node3D = $gravityControl/yawAxis/pitchAxis
@onready var yawNode: Node3D   = $gravityControl/yawAxis
@onready var rigRoot: Node3D   = $gravityControl
@onready var cam: Camera3D     = $gravityControl/yawAxis/pitchAxis/Camera3D
@onready var downProbe: ShapeCast3D = $ShapeCast3D

@onready var hud := $hud
@onready var wallIndicator := $hud/wallIndicator
@onready var trueGroundIndicator := $hud/trueGroundIndicator

@onready var gravityController: GravityController = $controllers/gravityController
@onready var movementController: MovementController = $controllers/movementController

@export var arrowTexturePointsUp := true

# shared tuning (controllers will read these off the player)
@export var rigReorientRate := 20.0
@export var speed := 15.0
@export var gravityStrength := 90.0
@export var stickStrength := 90.0
@export var maxStickSpeed := 500.0
@export var jumpSpeed := 30.0
@export var mouseSens := 0.001
@export var attachRange := 2.5
@export var pitchLimit := deg_to_rad(85.0)
@export var autoAttach := true
@export var attachWallDot := 0.5
@export var faceDot := 0.8 # this big value means (closer to 1 = floor becomes wall) at 0.8 a 20 deg slope becomes a wall
@export var detachGrace := 0.10
@export var supportNormalSmoothStep := 25.0     # bigger = snaps faster, smaller = smoother
@export var supportNormalDeadzoneDeg := 0.35    # ignore tiny normal changes (degrees)
@export var continuityWeight := 0.35            # 0..1, biases toward last normal

var filteredSupportUp := Vector3.UP            # our de-noised normal
# shared runtime state
var pitch := 0.0
var yaw := 0.0
var currentUp := Vector3.UP
var supposedUp := Vector3.UP
var attached := false
var detachTimer := 0.0



func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	gravityController.setup(self, movementController)
	movementController.setup(self, gravityController)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw   -= event.relative.x * mouseSens
		pitch -= event.relative.y * mouseSens
		pitch = clamp(pitch, -pitchLimit, pitchLimit)



func _physics_process(delta: float) -> void:
	gravityController.handleInteract()
	gravityController.updateUpAxis(delta)
	_updateCameraRig()
	movementController.updatePlanarAndJump(delta)
	gravityController.applyVerticalAccel(delta)
	move_and_slide()
	gravityController.updateAttachmentAfterMove(delta)
	gravityController.clampIntoFloor()
	if Input.is_action_just_pressed("esc"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	_updateHudArrows()



func _updateCameraRig() -> void:
	var up := currentUp.normalized()

	var refForward := (-rigRoot.global_transform.basis.z).normalized()
	refForward = refForward - up * refForward.dot(up)

	if refForward.length() < 0.001:
		var tmp := Vector3.FORWARD if abs(up.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
		refForward = tmp - up * tmp.dot(up)

	var fwd := refForward.normalized()
	var right := fwd.cross(currentUp).normalized()
	var targetBasis := Basis(right, up, -fwd).orthonormalized()

	rigRoot.global_transform.basis = targetBasis
	yawNode.rotation = Vector3(0.0, yaw, 0.0)
	pitchNode.rotation = Vector3(pitch, 0.0, 0.0)

func _updateHudArrows() -> void:
	var offset := -PI / 2 if arrowTexturePointsUp else 0.0
	var aGround := _screenArrowAngle(cam, Vector3.DOWN)
	if aGround > 100000.0:
		trueGroundIndicator.visible = false
	else:
		trueGroundIndicator.visible = true
		trueGroundIndicator.rotation = aGround + offset
	var aStick := _screenArrowAngle(cam, -currentUp)
	if attached and aStick <= 100000.0: # this can literally just be attached
#		i think an indicator of "am i even looking at the ground rn? would help"
		wallIndicator.visible = true
		wallIndicator.rotation = aStick + offset
	else:
		wallIndicator.visible = false

func _screenArrowAngle(camRef: Camera3D, worldDir: Vector3) -> float:
	var d := worldDir.normalized()
	var right := camRef.global_transform.basis.x
	var up := camRef.global_transform.basis.y
	var fwd := -camRef.global_transform.basis.z
	var dProj := d - fwd * d.dot(fwd)
	if dProj.length() < 0.001:
		return INF
	var x := dProj.dot(right)
	var y := dProj.dot(up)
	return Vector2(x, -y).angle()
