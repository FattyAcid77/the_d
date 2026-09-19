# =============================================================================
# DEBUG ONLY - pretends the disk is slow so the loading screen can be tested
# on an SSD. Does nothing in a release build.
#
# While the game is running:
#   F9  off        F10  400ms (just over the grace)    F11  2000ms (slow HDD)
#   F12 reload the current scene using the current setting
#
# TO DELETE: remove this file, then remove the blocks marked
# "DEBUG SLOW LOAD" in SceneManager.gd. Nothing else references it.
# =============================================================================
class_name DebugSlowLoad
extends RefCounted

# ms to stall every scene load at startup. 0 = off.
# also settable at runtime with the keys above, or --slow-load-ms=2000
const DEFAULT_HOLD_MS := 0

static var _hold_ms := -1
static var _started_at := 0


static func begin() -> void:
	_started_at = Time.get_ticks_msec()


static func is_holding() -> bool:
	if not OS.is_debug_build() or _started_at == 0:
		return false
	return Time.get_ticks_msec() - _started_at < _resolve_hold_ms()


# climbs 0 -> 0.9 across the stall so the bar moves like a real slow load
static func fake_progress() -> float:
	var hold := _resolve_hold_ms()
	if hold <= 0:
		return 0.0
	var elapsed := float(Time.get_ticks_msec() - _started_at)
	return clampf(elapsed / float(hold), 0.0, 1.0) * 0.9


static func set_hold_ms(ms: int) -> void:
	_hold_ms = maxi(ms, 0)
	print("[slow load] fake disk delay = %d ms" % _hold_ms)


static func _resolve_hold_ms() -> int:
	if _hold_ms < 0:
		_hold_ms = DEFAULT_HOLD_MS
		var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
		for arg in args:
			if arg.begins_with("--slow-load-ms="):
				_hold_ms = int(arg.get_slice("=", 1))
	return _hold_ms
