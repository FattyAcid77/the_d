class_name Sami_statemachine extends Node

var states : Array[ state ]
var prev_state : state
var current_state : state

func _physics_process(delta: float) -> void:
	ChangeState( current_state.Physics( delta ) )


func _unhandled_input(event):
	ChangeState( current_state.HandleInput( event ) )
	pass

func _process(delta):
	ChangeState(current_state.Process(delta))

func Initialize( _player : Player ) -> void:
	states = []

	for c in get_children():
		if c is state:
			states.append(c)

	if states.size() > 0:
		states[0].player = _player
		ChangeState( states[0] )
		process_mode = Node.PROCESS_MODE_INHERIT

# Called when the node enters the scene tree for the first time.
func _ready():
	process_mode = Node.PROCESS_MODE_DISABLED
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.


func ChangeState( new_state : state ) -> void:
	if new_state == null || new_state == current_state:
		return

	if current_state:
		current_state.Exit()

	prev_state = current_state
	current_state = new_state
	current_state.Enter()
