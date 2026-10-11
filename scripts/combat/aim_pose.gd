class_name AimPose
extends SkeletonModifier3D
## Tilts the arms (and a little of the head) up/down by the aim pitch after the animation is applied,
## so third-person characters point their weapon where they aim.

var pitch := 0.0          ## radians, + = up
var arm_bones := PackedInt32Array()
var head_bone := -1


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or absf(pitch) < 0.001:
		return
	var q := Quaternion(Vector3.RIGHT, -pitch)
	for b in arm_bones:
		sk.set_bone_pose_rotation(b, q * sk.get_bone_pose_rotation(b))
	if head_bone >= 0:
		sk.set_bone_pose_rotation(head_bone, Quaternion(Vector3.RIGHT, -pitch * 0.5) * sk.get_bone_pose_rotation(head_bone))
