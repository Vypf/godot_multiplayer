extends Node
class_name OnlineInput
## Base class for player input in multiplayer games.
##
## This node should be a child of the Player node and will have its authority
## set to the owning player (peer_id = player node name).
##
## Extend this class to define your own input properties and synchronize them
## using a MultiplayerSynchronizer as a child of this node.
##
## Example:
## [codeblock]
## extends OnlineInput
##
## var direction: Vector2 = Vector2.ZERO
##
## func _process(delta):
##     if not is_multiplayer_authority():
##         return
##     direction = Vector2(
##         Input.get_axis("move_left", "move_right"),
##         Input.get_axis("move_up", "move_down"),
##     )
## [/codeblock]
