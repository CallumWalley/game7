extends Node

@warning_ignore_start("unused_signal")
signal memory_discovered(memory_id: String)
signal body_node_unlocked(node_id: String)
signal environment_observed(observation_id: String)
signal fragment_node_contested(node_id: String)
signal fragment_node_stabilized(node_id: String)
signal component_memory_state_changed(component_type_id: String, new_state: int)
@warning_ignore_restore("unused_signal")
