extends PanelContainer
class_name LobbyPanel

@onready var host: Button = %Host
@onready var code_input: TextEdit = %CodeInput
@onready var join: Button = %Join

var code: String = ""

signal on_host_click
signal on_join_click(code: String)

func _ready():
	host.pressed.connect(_on_host_pressed)
	code_input.text_changed.connect(_on_code_changed)
	join.pressed.connect(_on_join_pressed)

func _on_host_pressed():
	on_host_click.emit()

func _on_join_pressed():
	on_join_click.emit(code)

func _on_code_changed():
	code = code_input.text
