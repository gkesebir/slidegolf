extends Control

@onready var close_button = $Panel/CloseButton
@onready var timer_label = $Panel/TimerLabel
@onready var game_manager = get_node("/root/Main/GameManager")

var time_left = 3.0
var timer_active = false
var on_complete_callback: Callable

func _ready():
	hide()
	z_index = 2000 # Ensure it's above everything
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

func _process(delta):
	if timer_active:
		time_left -= delta
		if time_left <= 0:
			time_left = 0
			timer_active = false
			if close_button:
				close_button.disabled = false
				close_button.text = "REKLAMI GEÇ"
		
		if timer_label and timer_active:
			timer_label.text = "Reklamı geçmek için %d saniye..." % ceil(time_left)

func start_ad_timer(callback: Callable = Callable()):
	on_complete_callback = callback
	time_left = 3.0
	timer_active = true
	show()
	if close_button:
		close_button.disabled = true
		close_button.text = "Lütfen Bekleyin"
	if timer_label:
		timer_label.text = "Reklamı geçmek için 3 saniye..."

func _on_close_pressed():
	hide()
	if on_complete_callback.is_valid():
		on_complete_callback.call()
	elif game_manager and game_manager.has_method("show_victory_screen"):
		# Fallback to old behavior if no callback is passed
		game_manager.show_victory_screen()
