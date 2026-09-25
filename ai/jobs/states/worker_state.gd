class_name WorkerState
extends State
## Base for settler work states; `worker` is the WorkerController.

var worker: WorkerController:
	get: return machine.context as WorkerController
