extends OnlineInput
## Player input - define your input properties here and sync them via MultiplayerSynchronizer.
##
## Example for a top-down game:
##   var direction: Vector2 = Vector2.ZERO
##
##   func _process(delta):
##       if not is_multiplayer_authority():
##           return
##       direction = Vector2(
##           Input.get_axis("move_left", "move_right"),
##           Input.get_axis("move_up", "move_down"),
##       )
