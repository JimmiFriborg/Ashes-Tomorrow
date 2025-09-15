extends RefCounted

## Enumerated states used by technology nodes.
enum NodeState {
    OPERABLE,
    FADING,
    DORMANT,
    FORGOTTEN,
}

const STATE_NAMES := {
    NodeState.OPERABLE: "Operable",
    NodeState.FADING: "Fading",
    NodeState.DORMANT: "Dormant",
    NodeState.FORGOTTEN: "Forgotten",
}

const STATE_LOOKUP := {
    "OPERABLE": NodeState.OPERABLE,
    "Operable": NodeState.OPERABLE,
    "operable": NodeState.OPERABLE,
    "FADING": NodeState.FADING,
    "Fading": NodeState.FADING,
    "fading": NodeState.FADING,
    "DORMANT": NodeState.DORMANT,
    "Dormant": NodeState.DORMANT,
    "dormant": NodeState.DORMANT,
    "FORGOTTEN": NodeState.FORGOTTEN,
    "Forgotten": NodeState.FORGOTTEN,
    "forgotten": NodeState.FORGOTTEN,
}


class ResilienceScore:
    extends RefCounted

    var _resistance_by_state := {
        "Operable": 3,
        "Fading": 2,
        "Dormant": 1,
    }

    func _init(operable_resistance: int = 3, fading_resistance: int = 2, dormant_resistance: int = 1) -> void:
        set_resistance("Operable", operable_resistance)
        set_resistance("Fading", fading_resistance)
        set_resistance("Dormant", dormant_resistance)

    func duplicate() -> ResilienceScore:
        return ResilienceScore.new(
            _resistance_by_state.get("Operable", 3),
            _resistance_by_state.get("Fading", 2),
            _resistance_by_state.get("Dormant", 1),
        )

    func set_resistance(state_name: String, value: int) -> void:
        _resistance_by_state[state_name] = max(1, int(value))

    func get_resistance(state: int) -> int:
        var state_name := STATE_NAMES.get(state, "Operable")
        return _resistance_by_state.get(state_name, 1)

    func serialize() -> Dictionary:
        return {
            "operable_resistance": _resistance_by_state.get("Operable", 3),
            "fading_resistance": _resistance_by_state.get("Fading", 2),
            "dormant_resistance": _resistance_by_state.get("Dormant", 1),
        }

    static func deserialize(data: Dictionary) -> ResilienceScore:
        if data == null:
            return ResilienceScore.new()
        return ResilienceScore.new(
            int(data.get("operable_resistance", 3)),
            int(data.get("fading_resistance", 2)),
            int(data.get("dormant_resistance", 1)),
        )


class TechLink:
    extends RefCounted

    var node_a := null
    var node_b := null
    var metadata: Dictionary = {}

    func _init(a = null, b = null, link_metadata: Dictionary = {}) -> void:
        node_a = a
        node_b = b
        metadata = link_metadata.duplicate(true)

    func connects(node) -> bool:
        return node == node_a or node == node_b

    func get_other_node(node):
        if node == node_a:
            return node_b
        if node == node_b:
            return node_a
        return null

    func serialize() -> Dictionary:
        return {
            "node_a": node_a.id if node_a and node_a.id != null else "",
            "node_b": node_b.id if node_b and node_b.id != null else "",
            "metadata": metadata.duplicate(true),
        }

    static func deserialize(data: Dictionary, node_lookup: Dictionary) -> TechLink:
        if data == null:
            return null
        var id_a := str(data.get("node_a", ""))
        var id_b := str(data.get("node_b", ""))
        if not node_lookup.has(id_a) or not node_lookup.has(id_b):
            return null
        var metadata := {}
        var metadata_value := data.get("metadata", {})
        if typeof(metadata_value) == TYPE_DICTIONARY:
            metadata = metadata_value.duplicate(true)
        return TechLink.create_link(node_lookup[id_a], node_lookup[id_b], metadata)

    static func create_link(node_a, node_b, metadata: Dictionary = {}) -> TechLink:
        if node_a == null or node_b == null or node_a == node_b:
            return null
        var existing := node_a.get_link_with(node_b)
        if existing:
            if metadata.size() > 0:
                existing.metadata = metadata.duplicate(true)
            return existing
        var link := TechLink.new(node_a, node_b, metadata)
        node_a._register_link(link)
        node_b._register_link(link)
        return link

    func disconnect() -> void:
        if node_a:
            node_a._unregister_link(self)
        if node_b:
            node_b._unregister_link(self)
        node_a = null
        node_b = null


class TechNode:
    extends RefCounted

    var id: String = ""
    var name: String = ""
    var state: int = NodeState.OPERABLE
    var resilience: ResilienceScore

    var _links: Array = []
    var _decay_progress := 0
    var _pending_neighbor_ids: Array = []

    func _init(node_id: String = "", display_name: String = "", initial_state: int = NodeState.OPERABLE, resilience_score: ResilienceScore = null) -> void:
        id = node_id
        name = display_name if display_name != "" else node_id
        resilience = resilience_score if resilience_score != null else ResilienceScore.new()
        set_state(initial_state)

    func set_state(value: int) -> void:
        if not STATE_NAMES.has(value):
            state = NodeState.OPERABLE
        else:
            state = value
        if state == NodeState.FORGOTTEN:
            _decay_progress = 0

    func set_state_by_name(state_name: String) -> void:
        var normalized := STATE_LOOKUP.get(state_name, NodeState.OPERABLE)
        set_state(normalized)

    func get_state_name() -> String:
        return STATE_NAMES.get(state, "Operable")

    func get_links() -> Array:
        return _links.duplicate()

    func get_neighbors() -> Array:
        var results: Array = []
        for link in _links:
            var neighbor := link.get_other_node(self)
            if neighbor and not results.has(neighbor):
                results.append(neighbor)
        return results

    func has_neighbor(node) -> bool:
        return get_link_with(node) != null

    func get_link_with(node) -> TechLink:
        for link in _links:
            if link.get_other_node(self) == node:
                return link
        return null

    func apply_decay() -> int:
        if state == NodeState.FORGOTTEN:
            return state
        _decay_progress += 1
        var threshold := max(1, resilience.get_resistance(state))
        if _decay_progress >= threshold:
            _decay_progress = 0
            match state:
                NodeState.OPERABLE:
                    state = NodeState.FADING
                NodeState.FADING:
                    state = NodeState.DORMANT
                NodeState.DORMANT:
                    state = NodeState.FORGOTTEN
        return state

    func relearn(steps: int = 1) -> int:
        if steps <= 0:
            return state
        _decay_progress = 0
        while steps > 0:
            match state:
                NodeState.FORGOTTEN:
                    state = NodeState.DORMANT
                NodeState.DORMANT:
                    state = NodeState.FADING
                NodeState.FADING:
                    state = NodeState.OPERABLE
                NodeState.OPERABLE:
                    steps = 0
                    continue
            steps -= 1
        return state

    func serialize() -> Dictionary:
        return {
            "id": id,
            "name": name,
            "state": get_state_name(),
            "decay_progress": _decay_progress,
            "resilience": resilience.serialize() if resilience else ResilienceScore.new().serialize(),
            "neighbors": _serialize_neighbor_ids(),
        }

    static func deserialize(data: Dictionary) -> TechNode:
        if data == null:
            return null
        var node := TechNode.new(
            str(data.get("id", "")),
            str(data.get("name", "")),
        )
        node.set_state_by_name(data.get("state", "Operable"))
        node._decay_progress = int(data.get("decay_progress", 0))
        node.resilience = ResilienceScore.deserialize(data.get("resilience", {}))
        var neighbors := []
        if data.has("neighbors") and typeof(data["neighbors"]) == TYPE_ARRAY:
            neighbors = data["neighbors"].duplicate()
        var normalized_ids: Array = []
        for neighbor_id in neighbors:
            normalized_ids.append(str(neighbor_id))
        node._pending_neighbor_ids = normalized_ids
        return node

    func resolve_pending_links(node_lookup: Dictionary) -> void:
        if _pending_neighbor_ids.is_empty():
            return
        for neighbor_id in _pending_neighbor_ids:
            if not node_lookup.has(neighbor_id):
                continue
            var neighbor = node_lookup[neighbor_id]
            TechLink.create_link(self, neighbor)
        _pending_neighbor_ids.clear()

    func _register_link(link: TechLink) -> void:
        if link == null:
            return
        if _links.has(link):
            return
        _links.append(link)

    func _unregister_link(link: TechLink) -> void:
        if link == null:
            return
        if _links.has(link):
            _links.erase(link)

    func _serialize_neighbor_ids() -> Array:
        var ids: Array = []
        for link in _links:
            var neighbor := link.get_other_node(self)
            if neighbor and neighbor.id != null and neighbor.id != "" and not ids.has(neighbor.id):
                ids.append(neighbor.id)
        return ids
