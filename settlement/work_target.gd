class_name WorkTarget
## Contract for anything a worker can walk up to and work on (resource
## nodes, construction sites, later workstations). GDScript has no
## interfaces, so members of GROUP implement these methods (duck typing):
##
##   has_work_for(job: JobDefinition) -> bool
##   can_claim(by: Object) -> bool / claim(by) -> bool / release(by)
##   work_position(from: Vector3) -> Vector3      where to stand
##   apply_work(amount: float, worker: Node3D, tags: PackedStringArray) -> Dictionary
##       returns {"produced_at": Vector3} when the work yielded items
##       that should now be collected, otherwise {}.

const GROUP := &"work_targets"
