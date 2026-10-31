extends Area3D
class_name FinishLine
## Sprint finish gate. Crossing it with every checkpoint already passed ends the
## race; in a lap race it does nothing and must not be present.
##
## Holds no state and knows nothing about RaceManager: the manager finds it by type
## and wires body_entered, exactly like Checkpoint and StartFinishLine.
