extends Node2D
class_name BeamEmitter

@export_group("Beam")
@export var beam_color: Color = Color(1.0, 0.85, 0.0, 1.0)
@export var beam_width: float = 4.0
@export var max_length: float = 2000.0
@export var max_bounces: int = 6
## Layer 1 = walls/mirrors (value 1), Layer 2 = portals/receivers (value 2). Default 3 = both.
@export_flags_2d_physics var collision_mask: int = 3

@export_group("Portal Entry (leave blank for a normal emitter)")
## Match this to the portal_id on the BeamPortal in the OTHER world.
@export var source_portal_id: String = ""
## Rotation offset (radians) applied when the beam enters from the portal.
@export var angle_offset: float = 0.0

var _points: PackedVector2Array = []
var _active: bool = true
var _prev_portal: String = ""

func _ready() -> void:
	z_index = 10
	z_as_relative = false  # Absolute z — never overridden by a parent node
	if source_portal_id != "":
		_sync_portal()
		queue_redraw()

func _physics_process(_delta: float) -> void:
	if source_portal_id != "":
		_sync_portal()
	if not _active:
		if _points.size() > 0:
			_points.clear()
			queue_redraw()
		return
	_cast()
	queue_redraw()

func _sync_portal() -> void:
	var state: Dictionary = GameState.get_beam_portal(source_portal_id)
	var was_active := _active
	_active = state.get("active", false)
	if _active:
		rotation = state.get("angle", rotation) + angle_offset
	elif was_active:
		_points.clear()

func _cast() -> void:
	_points.clear()
	var origin: Vector2 = global_position
	var dir: Vector2 = Vector2.RIGHT.rotated(global_rotation)
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	_points.append(to_local(origin))
	var new_portal: String = ""
	var exclude: Array[RID] = []
	var mirrors_hit: Dictionary = {}   # unique mirror RIDs the beam touched this cast
	var bounces := 0
	var iters := 0

	# While loop so character pass-throughs don't consume bounce budget
	while bounces <= max_bounces and iters < max_bounces + 20:
		iters += 1
		# Pass exclude as the 4th arg to create() — most reliable path in Godot 4.6
		var query := PhysicsRayQueryParameters2D.create(
			origin, origin + dir * max_length, collision_mask, exclude
		)
		query.collide_with_areas = true
		var hit: Dictionary = space.intersect_ray(query)

		if hit.is_empty():
			_points.append(to_local(origin + dir * max_length))
			break

		var body: Object = hit.collider

		# Beam groups get special handling first
		if body.is_in_group("beam_portal"):
			_points.append(to_local(hit.position))
			new_portal = body.portal_id
			GameState.set_beam_portal(body.portal_id, true, dir.angle())
			break
		elif body.is_in_group("beam_mirror"):
			_points.append(to_local(hit.position))
			mirrors_hit[body.get_rid()] = true
			dir = dir.bounce(hit.normal)
			origin = hit.position + dir * 2.0
			bounces += 1
		elif body.is_in_group("beam_receiver"):
			_points.append(to_local(hit.position))
			body.on_beam_hit(mirrors_hit.size())
			break
		elif body is CharacterBody2D or body is Area2D:
			# Player, NPCs, and any non-beam Area2D (e.g. push-pull zones) — pass through.
			# Add to exclude so the same body isn't re-hit, nudge origin past the surface.
			exclude.append(body.get_rid())
			origin = hit.position + dir * 1.0
		else:
			# StaticBody2D, TileMap walls, or any other solid geometry — beam stops.
			_points.append(to_local(hit.position))
			break

	# If beam stopped hitting a portal it was hitting before, deactivate the portal
	if _prev_portal != "" and _prev_portal != new_portal:
		GameState.set_beam_portal(_prev_portal, false, 0.0)
	_prev_portal = new_portal

func _draw() -> void:
	if _points.size() < 2:
		return
	# Glow pass (wide + transparent)
	var glow := Color(beam_color.r, beam_color.g, beam_color.b, beam_color.a * 0.35)
	for i in range(_points.size() - 1):
		draw_line(_points[i], _points[i + 1], glow, beam_width * 4.0)
	# Core beam pass
	for i in range(_points.size() - 1):
		draw_line(_points[i], _points[i + 1], beam_color, beam_width)
	# Source dot
	draw_circle(Vector2.ZERO, beam_width * 1.5, beam_color)
