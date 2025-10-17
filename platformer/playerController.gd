extends CharacterBody2D

# --- MOVEMENT ---
@export var walk_speed := 150.0
@export var run_speed := 250.0
@export_range(0, 1) var acceleration := 0.1
@export_range(0, 1) var deceleration := 0.1

# --- JUMP ---
@export_range(0, 1) var decelerate_on_jump_release := 0.5
@export var jump_force := -400.0

# --- DASH ---
@export var dash_speed := 1000.0
@export var dash_max_distance := 100.0
@export var dash_cooldown := 0.5
@export var dash_curve : Curve

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $Jump
@onready var dash_sound: AudioStreamPlayer2D = $Dash

var is_dashing := false
var can_dash := true
var dash_start_position := 0.0
var dash_direction := 0.0


func _physics_process(delta: float) -> void:
	# --- GRAVITY ---
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta

	# --- DASH → JUMP COMBO ---
	if Input.is_action_just_pressed("Jump"):
		if is_dashing:
			stop_dash()
			velocity.y = jump_force
			animated_sprite.play("Jump")
			jump_sound.play()
		elif is_on_floor() or is_on_wall():
			velocity.y = jump_force
			animated_sprite.play("Jump")
			jump_sound.play()

	# Shorter jump when releasing early
	if Input.is_action_just_released("Jump") and velocity.y < 0:
		velocity.y *= decelerate_on_jump_release

	# --- RUN/WALK SPEED ---
	var is_running := Input.is_action_pressed("Run")
	var target_speed := (run_speed if is_running else walk_speed)

	# --- HORIZONTAL MOVEMENT ---
	var direction := Input.get_axis("Left", "Right")

	if not is_dashing:
		if direction != 0:
			velocity.x = move_toward(velocity.x, direction * target_speed, target_speed * acceleration)
			animated_sprite.flip_h = direction < 0
			if is_on_floor():
				animated_sprite.play("Run" if is_running else "Walk")
		else:
			velocity.x = move_toward(velocity.x, 0, walk_speed * deceleration)
			if is_on_floor():
				animated_sprite.play("Idle")

	# --- DASH ---
	if Input.is_action_just_pressed("Dash") and direction != 0 and can_dash and not is_dashing:
		start_dash(direction)

	if is_dashing:
		var current_distance := absf(position.x - dash_start_position)
		if current_distance >= dash_max_distance or is_on_wall():
			stop_dash()
		else:
			var t = clamp(current_distance / dash_max_distance, 0.0, 1.0)
			var dash_factor := dash_curve.sample(t) if dash_curve else 1.0
			velocity.x = dash_direction * dash_speed * dash_factor
			velocity.y = 0

	# --- FALLING ANIMATION ---
	if not is_on_floor() and velocity.y > 0 and not is_dashing:
		animated_sprite.play("Fall")

	move_and_slide()


func start_dash(direction: float) -> void:
	is_dashing = true
	can_dash = false
	dash_start_position = position.x
	dash_direction = direction
	animated_sprite.play("Dashing")
	dash_sound.play()
	get_tree().create_timer(dash_cooldown).timeout.connect(_on_dash_cooldown_finished)


func stop_dash() -> void:
	is_dashing = false


func _on_dash_cooldown_finished() -> void:
	can_dash = true
