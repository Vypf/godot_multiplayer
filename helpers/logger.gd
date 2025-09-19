class_name CustomLogger
extends RefCounted

# 1. Niveaux de Log
enum Level { DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3 }

# 2. Contrôle Manuel du Niveau Global
# Par défaut, on affiche tout (DEBUG et plus).
# Modifiez-le au démarrage de votre jeu si nécessaire.
static var _global_level: Level = Level.DEBUG

var _prefix: String = ""


# Le constructeur prend un préfixe pour identifier la source des logs.
func _init(prefix: String = ""):
	_prefix = prefix


# --- API Publique ---


func info(message: String, context: String = "") -> void:
	_print_message(Level.INFO, message, context)


func debug(message: String, context: String = "") -> void:
	_print_message(Level.DEBUG, message, context)


func warn(message: String, context: String = "") -> void:
	_print_message(Level.WARN, message, context)
	if Level.WARN >= _global_level:
		push_warning(_build_full_message(Level.WARN, message, context))


func error(message: String, context: String = "") -> void:
	_print_message(Level.ERROR, message, context)
	if Level.ERROR >= _global_level:
		var error_message = _build_full_message(Level.ERROR, message, context)
		# On garde la stack trace, c'est trop utile !
		var error_with_location = _add_stack_trace_info(error_message)
		push_error(error_with_location)


# Permet de changer le niveau de log global depuis l'extérieur.
static func set_global_level(level: Level) -> void:
	_global_level = level


# --- Méthodes Internes ---


func _print_message(level: Level, message: String, context: String) -> void:
	# Si le niveau du message est inférieur au niveau global, on ne l'affiche pas.
	if level < _global_level:
		return

	print(_build_full_message(level, message, context))


func _build_full_message(level: Level, message: String, context: String) -> String:
	var parts = []

	# Ajoute un timestamp pour savoir quand le log a eu lieu.
	var time = Time.get_time_string_from_system()
	parts.append("[%s]" % time)

	# Préfixe de la classe (ex: [Player])
	if not _prefix.is_empty():
		parts.append("[%s]" % _prefix)

		# Contexte de la fonction (ex: [take_damage])
	if not context.is_empty():
		parts.append("[%s]" % context)

		# Niveau avec icône
	match level:
		Level.DEBUG:
			parts.append("🔍 DEBUG:")
		Level.INFO:
			parts.append("ℹ️  INFO:")
		Level.WARN:
			parts.append("⚠️  WARN:")
		Level.ERROR:
			parts.append("🚨 ERROR:")

	parts.append(message)
	return " ".join(parts)


func _add_stack_trace_info(message: String) -> String:
	var stack = get_stack()
	if stack.size() < 3:
		return message + " [no stack trace available]"

	var caller_frame = stack[2]
	var filename = caller_frame.get("source", "unknown").get_file()
	var line_number = caller_frame.get("line", 0)
	var function_name = caller_frame.get("function", "unknown")

	var location_info = " [%s:%d in %s()]" % [filename, line_number, function_name]
	return message + location_info
