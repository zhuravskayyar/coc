class_name ArrowProjectile
extends Area2D

const METADATA: JSON = preload("res://assets/sprites/units/archer_animations.json")

@export var speed := 320.0
@export var lifetime := 3.0
var direction := Vector2.RIGHT
var _age := 0.0

@onready var sprite: Sprite2D = $Sprite


func launch(flight_direction: Vector2, facing: int, flight_speed: float, flight_lifetime: float, visual_scale: float) -> void:
	direction = flight_direction.normalized()
	speed = maxf(flight_speed, 0.0)
	lifetime = maxf(flight_lifetime, 0.0)
	_age = 0.0
	var info: Dictionary = METADATA.data["projectile"]
	var pivot: Array = info["pivots"][facing]
	sprite.frame = facing
	sprite.offset = -Vector2(float(pivot[0]), float(pivot[1]))
	sprite.scale = Vector2.ONE * visual_scale
	sprite.rotation = direction.angle() - float(info["angles"][facing])
	$CollisionShape2D.rotation = direction.angle()


func _physics_process(delta: float) -> void:
	advance_flight(delta)


func advance_flight(delta: float) -> void:
	if delta <= 0.0 or is_queued_for_deletion():
		return
	var remaining := maxf(lifetime - _age, 0.0)
	global_position += direction * speed * minf(delta, remaining)
	_age += delta
	if _age >= lifetime:
		queue_free()
