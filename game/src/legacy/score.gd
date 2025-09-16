extends RefCounted
class_name LegacyScore

const TECH_WEB := preload("res://src/tech/tech_web.gd")

var preserved_pillars: int = 0
var interlink_density: float = 0.0
var artifact_count: int = 0
var master_line_continuity: float = 0.0
var total_score: float = 0.0
var outcome_label: String = ""
var breakdown: Dictionary = {}
var thresholds := {
    "eternal_lineage": 120.0,
    "resilient_hearth": 80.0,
    "flickering_memory": 45.0,
    "ashbound": 0.0,
}

func _init(state: Dictionary = {}) -> void:
    if not state.is_empty():
        evaluate(state)

func evaluate(state: Dictionary) -> void:
    preserved_pillars = _compute_preserved_pillars(state)
    interlink_density = _compute_interlink_density(state)
    artifact_count = _compute_artifact_count(state)
    master_line_continuity = _compute_master_line_continuity(state)
    breakdown = {
        "preserved_pillars": preserved_pillars,
        "interlink_density": interlink_density,
        "artifact_count": artifact_count,
        "master_line_continuity": master_line_continuity,
    }
    total_score = _compute_total_score()
    outcome_label = _determine_outcome(total_score, state.get("outcome_thresholds", {}))

func to_dictionary() -> Dictionary:
    return {
        "preserved_pillars": preserved_pillars,
        "interlink_density": interlink_density,
        "artifact_count": artifact_count,
        "master_line_continuity": master_line_continuity,
        "total_score": total_score,
        "outcome": outcome_label,
        "breakdown": breakdown.duplicate(true),
        "thresholds": thresholds.duplicate(true),
    }

static func calculate(state: Dictionary) -> LegacyScore:
    var score := LegacyScore.new()
    score.evaluate(state)
    return score

func _compute_total_score() -> float:
    return preserved_pillars * 4.0 + interlink_density * 40.0 + artifact_count * 6.0 + master_line_continuity * 8.0

func _determine_outcome(score_value: float, custom_thresholds: Dictionary) -> String:
    var evaluation_thresholds := thresholds.duplicate(true)
    for key in custom_thresholds.keys():
        evaluation_thresholds[key] = float(custom_thresholds[key])
    if score_value >= evaluation_thresholds.get("eternal_lineage", thresholds["eternal_lineage"]):
        return "Eternal Lineage"
    if score_value >= evaluation_thresholds.get("resilient_hearth", thresholds["resilient_hearth"]):
        return "Resilient Hearth"
    if score_value >= evaluation_thresholds.get("flickering_memory", thresholds["flickering_memory"]):
        return "Flickering Echo"
    return "Ashbound Silence"

func _compute_preserved_pillars(state: Dictionary) -> int:
    var nodes := _collect_nodes(state)
    var preserved := 0
    for node in nodes:
        var state_index := _extract_node_state(node)
        if state_index != TECH_WEB.NodeState.FORGOTTEN:
            preserved += 1
    return preserved

func _compute_interlink_density(state: Dictionary) -> float:
    var nodes := _collect_nodes(state)
    var node_count := nodes.size()
    if node_count <= 1:
        return 0.0
    var links := _collect_links(state, nodes)
    var unique_links := _count_unique_links(links, nodes)
    var max_links := float(node_count * (node_count - 1)) / 2.0
    if max_links <= 0.0:
        return 0.0
    return clamp(unique_links / max_links, 0.0, 1.0)

func _compute_artifact_count(state: Dictionary) -> int:
    if state.has("artifacts"):
        var artifacts = state["artifacts"]
        if typeof(artifacts) == TYPE_ARRAY:
            return artifacts.size()
        if typeof(artifacts) == TYPE_DICTIONARY:
            return artifacts.size()
    if state.has("artifact_count"):
        return int(state["artifact_count"])
    if state.has("event_manager"):
        var manager = state["event_manager"]
        if typeof(manager) == TYPE_OBJECT:
            if manager.has_method("count_discovered_artifacts"):
                return int(manager.count_discovered_artifacts())
            if manager.has_method("get_discovered_artifacts"):
                var records = manager.get_discovered_artifacts()
                if typeof(records) == TYPE_ARRAY:
                    return records.size()
                if typeof(records) == TYPE_DICTIONARY:
                    return records.size()
        elif typeof(manager) == TYPE_DICTIONARY and manager.has("artifacts"):
            var manager_artifacts = manager["artifacts"]
            if typeof(manager_artifacts) == TYPE_ARRAY:
                return manager_artifacts.size()
            if typeof(manager_artifacts) == TYPE_DICTIONARY:
                return manager_artifacts.size()
    return 0

func _compute_master_line_continuity(state: Dictionary) -> float:
    if state.has("master_line_continuity"):
        return float(state["master_line_continuity"])
    if state.has("event_manager"):
        var manager = state["event_manager"]
        if typeof(manager) == TYPE_OBJECT:
            if manager.has_method("evaluate_master_line_continuity"):
                return float(manager.evaluate_master_line_continuity())
            var manager_payload := {}
            manager_payload["canonized_legends"] = manager.has_method("get_canonized_legends") ? manager.get_canonized_legends() : []
            manager_payload["seeded_schools"] = manager.has_method("get_seeded_schools") ? manager.get_seeded_schools() : []
            manager_payload["empowered_guilds"] = manager.has_method("get_empowered_guilds") ? manager.get_empowered_guilds() : []
            manager_payload["moments_of_memory"] = manager.has_method("get_memory_moments") ? manager.get_memory_moments() : []
            return _evaluate_master_line_from_manager(manager_payload)
        elif typeof(manager) == TYPE_DICTIONARY:
            return _evaluate_master_line_from_manager(manager)
    return _evaluate_master_line_from_manager(state)

func _evaluate_master_line_from_manager(data: Dictionary) -> float:
    var score := 0.0
    var legends := data.get("canonized_legends", [])
    if typeof(legends) == TYPE_DICTIONARY:
        legends = legends.values()
    if typeof(legends) == TYPE_ARRAY:
        for legend in legends:
            var significance := 1.0
            var tags: Array = []
            if typeof(legend) == TYPE_DICTIONARY:
                significance = float(legend.get("significance", 1.0))
                if legend.has("tags") and typeof(legend["tags"]) == TYPE_ARRAY:
                    tags = legend["tags"]
            score += max(0.5, significance) + 0.15 * tags.size()
    var schools := data.get("seeded_schools", [])
    if typeof(schools) == TYPE_DICTIONARY:
        schools = schools.values()
    if typeof(schools) == TYPE_ARRAY:
        for school in schools:
            var influence := 1.0
            var cadres: Array = []
            if typeof(school) == TYPE_DICTIONARY:
                influence = float(school.get("influence", 1.0))
                var primary_cadre = school.get("cadre", null)
                if typeof(primary_cadre) == TYPE_ARRAY:
                    cadres = primary_cadre
                else:
                    var alternate_cadre = school.get("cadres", [])
                    if typeof(alternate_cadre) == TYPE_ARRAY:
                        cadres = alternate_cadre
            score += max(0.25, influence * 0.75 + 0.2 * cadres.size())
    var guilds := data.get("empowered_guilds", [])
    if typeof(guilds) == TYPE_DICTIONARY:
        guilds = guilds.values()
    if typeof(guilds) == TYPE_ARRAY:
        for guild in guilds:
            var influence := 1.0
            var disciplines: Array = []
            var refugees: Array = []
            if typeof(guild) == TYPE_DICTIONARY:
                influence = float(guild.get("influence", 1.0))
                var raw_disciplines = guild.get("disciplines", [])
                if typeof(raw_disciplines) == TYPE_ARRAY:
                    disciplines = raw_disciplines
                var raw_refugees = guild.get("refugee_cohort", [])
                if typeof(raw_refugees) == TYPE_ARRAY:
                    refugees = raw_refugees
            score += max(0.5, influence) + 0.1 * disciplines.size() + 0.15 * refugees.size()
    var moments := data.get("moments_of_memory", [])
    if typeof(moments) == TYPE_DICTIONARY:
        moments = moments.values()
    if typeof(moments) == TYPE_ARRAY:
        score += 0.25 * moments.size()
    return score

func _collect_nodes(state: Dictionary) -> Array:
    var nodes: Array = []
    if state.has("tech_web"):
        var web = state["tech_web"]
        if typeof(web) == TYPE_OBJECT and web.has_method("get_nodes"):
            nodes = web.get_nodes()
        elif typeof(web) == TYPE_ARRAY:
            nodes = web.duplicate()
        elif typeof(web) == TYPE_DICTIONARY and web.has("nodes"):
            nodes = web["nodes"]
    if nodes.is_empty():
        if state.has("nodes"):
            var raw_nodes = state["nodes"]
            if typeof(raw_nodes) == TYPE_DICTIONARY:
                nodes = raw_nodes.values()
            else:
                nodes = raw_nodes
        elif state.has("tech_nodes"):
            var tech_nodes = state["tech_nodes"]
            if typeof(tech_nodes) == TYPE_DICTIONARY:
                nodes = tech_nodes.values()
            else:
                nodes = tech_nodes
    if typeof(nodes) != TYPE_ARRAY:
        return []
    return nodes

func _collect_links(state: Dictionary, nodes: Array) -> Array:
    if state.has("links"):
        var links = state["links"]
        if typeof(links) == TYPE_ARRAY:
            return links
        if typeof(links) == TYPE_DICTIONARY:
            return links.values()
    if state.has("tech_web"):
        var web = state["tech_web"]
        if typeof(web) == TYPE_OBJECT and web.has_method("get_links"):
            return web.get_links()
        if typeof(web) == TYPE_DICTIONARY and web.has("links"):
            var link_data = web["links"]
            if typeof(link_data) == TYPE_ARRAY:
                return link_data
            if typeof(link_data) == TYPE_DICTIONARY:
                return link_data.values()
    var derived_links: Array = []
    var seen: Dictionary = {}
    for node in nodes:
        if node == null:
            continue
        if node is TECH_WEB.TechNode:
            for link in node.get_links():
                var key := _link_key(link)
                if key == "":
                    continue
                if not seen.has(key):
                    seen[key] = link
                    derived_links.append(link)
        elif typeof(node) == TYPE_DICTIONARY and node.has("neighbors") and node.has("id"):
            var node_id := str(node["id"])
            var neighbors := node["neighbors"]
            if typeof(neighbors) != TYPE_ARRAY:
                continue
            for neighbor_id in neighbors:
                var key := _pair_key(node_id, str(neighbor_id))
                if key == "":
                    continue
                if not seen.has(key):
                    seen[key] = {"node_a": node_id, "node_b": str(neighbor_id)}
                    derived_links.append(seen[key])
    return derived_links

func _count_unique_links(links: Array, nodes: Array) -> float:
    if links.is_empty():
        return 0.0
    var seen: Dictionary = {}
    var count := 0.0
    for link in links:
        var key := _link_key(link)
        if key == "":
            continue
        if seen.has(key):
            continue
        seen[key] = true
        count += 1.0
    return count

func _extract_node_state(node) -> int:
    if node == null:
        return TECH_WEB.NodeState.OPERABLE
    if node is TECH_WEB.TechNode:
        return int(node.state)
    if typeof(node) == TYPE_DICTIONARY:
        var state_value = node.get("state", node.get("state_index", node.get("status", "Operable")))
        if typeof(state_value) == TYPE_INT:
            return int(state_value)
        if typeof(state_value) == TYPE_STRING:
            return TECH_WEB.STATE_LOOKUP.get(state_value, TECH_WEB.NodeState.OPERABLE)
    if typeof(node) == TYPE_OBJECT:
        if node.has_method("get_state"):
            return int(node.get_state())
        if node.has_method("get_state_name"):
            var name := str(node.get_state_name())
            return TECH_WEB.STATE_LOOKUP.get(name, TECH_WEB.NodeState.OPERABLE)
    return TECH_WEB.NodeState.OPERABLE

func _link_key(link) -> String:
    if link == null:
        return ""
    if link is TECH_WEB.TechLink:
        var node_a = link.node_a
        var node_b = link.node_b
        if node_a == null or node_b == null:
            return ""
        var id_a := _node_identifier(node_a)
        var id_b := _node_identifier(node_b)
        return _pair_key(id_a, id_b)
    if typeof(link) == TYPE_DICTIONARY:
        var id_a := str(link.get("node_a", link.get("a", "")))
        var id_b := str(link.get("node_b", link.get("b", "")))
        if id_a == "" and link.has("id_a"):
            id_a = str(link["id_a"])
        if id_b == "" and link.has("id_b"):
            id_b = str(link["id_b"])
        return _pair_key(id_a, id_b)
    if typeof(link) == TYPE_ARRAY and link.size() >= 2:
        return _pair_key(str(link[0]), str(link[1]))
    return str(hash(link))

func _pair_key(a: String, b: String) -> String:
    if a == "" or b == "":
        return ""
    if a > b:
        var temp := a
        a = b
        b = temp
    return "%s::%s" % [a, b]

func _node_identifier(node) -> String:
    if node == null:
        return ""
    if node is TECH_WEB.TechNode:
        if node.id != null and str(node.id) != "":
            return str(node.id)
        return str(node.get_instance_id())
    if typeof(node) == TYPE_DICTIONARY and node.has("id"):
        return str(node["id"])
    if typeof(node) == TYPE_OBJECT and node.has_method("get_id"):
        var identifier := node.get_id()
        if typeof(identifier) in [TYPE_STRING, TYPE_INT]:
            return str(identifier)
    return str(hash(node))
