extends Node
class_name EventManager

signal crisis_triggered(event_data: Dictionary)
signal crisis_resolved(event_data: Dictionary)
signal opportunity_triggered(event_data: Dictionary)
signal opportunity_resolved(event_data: Dictionary)
signal memory_choice_committed(moment_id: String, moment_data: Dictionary)

const CRISIS_KIND := "crisis"
const OPPORTUNITY_KIND := "opportunity"

const DEFAULT_CRISIS_DEFINITIONS := {
    "epidemic": {
        "type": "epidemic",
        "name": "Epidemic Outbreak",
        "description": "A virulent sickness sweeps through the settlements, testing communal fortitude.",
        "kind": CRISIS_KIND,
        "base_duration": 6,
        "duration_variance": 3,
        "severity": {"min": 0.8, "max": 2.5},
        "default_tags": ["population", "health"],
        "memory_prompt": "The Plague Years",
    },
    "blight": {
        "type": "blight",
        "name": "Crop Blight",
        "description": "Harvests fail beneath a creeping blight that starves both soil and story.",
        "kind": CRISIS_KIND,
        "base_duration": 8,
        "duration_variance": 2,
        "severity": {"min": 1.0, "max": 3.5},
        "default_tags": ["agriculture", "sustenance"],
        "memory_prompt": "Fields Gone Ash",
    },
}

const DEFAULT_OPPORTUNITY_DEFINITIONS := {
    "artifact": {
        "type": "artifact",
        "name": "Unearthed Artifact",
        "description": "Fragments of the old world rise to the surface, beckoning interpretation.",
        "kind": OPPORTUNITY_KIND,
        "base_duration": 5,
        "duration_variance": 1,
        "value": {"min": 1.0, "max": 3.0},
        "default_tags": ["legacy", "memory"],
        "memory_prompt": "Remembered Relic",
    },
    "refugee_experts": {
        "type": "refugee_experts",
        "name": "Refugee Experts Arrive",
        "description": "A caravan of displaced masters offers their craft in exchange for sanctuary.",
        "kind": OPPORTUNITY_KIND,
        "base_duration": 4,
        "duration_variance": 1,
        "value": {"min": 1.0, "max": 2.5},
        "default_tags": ["guild", "knowledge"],
        "memory_prompt": "The Opened Gates",
    },
}

var _rng := RandomNumberGenerator.new()
var _time_elapsed := 0.0
var _event_counter := 0

var _crisis_definitions: Dictionary = {}
var _opportunity_definitions: Dictionary = {}

var _active_crises: Array = []
var _active_opportunities: Array = []
var _resolved_events: Array = []

var _moments_by_id: Dictionary = {}
var _canonized_legends: Dictionary = {}
var _seeded_schools: Dictionary = {}
var _empowered_guilds: Dictionary = {}
var _artifact_catalog: Dictionary = {}
var _refugee_networks: Array = []

func _init() -> void:
    _rng.randomize()
    for crisis_type in DEFAULT_CRISIS_DEFINITIONS.keys():
        register_crisis_definition(crisis_type, DEFAULT_CRISIS_DEFINITIONS[crisis_type])
    for opportunity_type in DEFAULT_OPPORTUNITY_DEFINITIONS.keys():
        register_opportunity_definition(opportunity_type, DEFAULT_OPPORTUNITY_DEFINITIONS[opportunity_type])

func register_crisis_definition(crisis_type: String, definition: Dictionary) -> void:
    if crisis_type == "":
        return
    var normalized := _normalize_definition(definition, CRISIS_KIND)
    normalized["type"] = crisis_type
    _crisis_definitions[crisis_type] = normalized

func register_opportunity_definition(opportunity_type: String, definition: Dictionary) -> void:
    if opportunity_type == "":
        return
    var normalized := _normalize_definition(definition, OPPORTUNITY_KIND)
    normalized["type"] = opportunity_type
    _opportunity_definitions[opportunity_type] = normalized

func get_crisis_definition(crisis_type: String) -> Dictionary:
    if _crisis_definitions.has(crisis_type):
        return _crisis_definitions[crisis_type].duplicate(true)
    return {}

func get_opportunity_definition(opportunity_type: String) -> Dictionary:
    if _opportunity_definitions.has(opportunity_type):
        return _opportunity_definitions[opportunity_type].duplicate(true)
    return {}

func has_crisis_definition(crisis_type: String) -> bool:
    return _crisis_definitions.has(crisis_type)

func has_opportunity_definition(opportunity_type: String) -> bool:
    return _opportunity_definitions.has(opportunity_type)

func trigger_crisis(crisis_type: String, overrides: Dictionary = {}) -> Dictionary:
    if not _crisis_definitions.has(crisis_type):
        return {}
    var definition := _crisis_definitions[crisis_type]
    var event := _create_event_instance(CRISIS_KIND, definition, overrides)
    _active_crises.append(event)
    crisis_triggered.emit(event.duplicate(true))
    return event

func trigger_epidemic(region: String = "", overrides: Dictionary = {}) -> Dictionary:
    var params := overrides.duplicate(true)
    var context := params.get("context", {})
    if typeof(context) == TYPE_DICTIONARY:
        context = context.duplicate(true)
    else:
        context = {}
    if region != "":
        context["region"] = region
    params["context"] = context
    return trigger_crisis("epidemic", params)

func trigger_blight(affected_crops: Array = [], overrides: Dictionary = {}) -> Dictionary:
    var params := overrides.duplicate(true)
    var context := params.get("context", {})
    if typeof(context) == TYPE_DICTIONARY:
        context = context.duplicate(true)
    else:
        context = {}
    if not affected_crops.is_empty():
        context["affected_crops"] = affected_crops.duplicate()
    params["context"] = context
    return trigger_crisis("blight", params)

func trigger_opportunity(opportunity_type: String, overrides: Dictionary = {}) -> Dictionary:
    if not _opportunity_definitions.has(opportunity_type):
        return {}
    var definition := _opportunity_definitions[opportunity_type]
    var event := _create_event_instance(OPPORTUNITY_KIND, definition, overrides)
    _active_opportunities.append(event)
    opportunity_triggered.emit(event.duplicate(true))
    return event

func trigger_artifact_discovery(location: String = "", overrides: Dictionary = {}) -> Dictionary:
    var params := overrides.duplicate(true)
    var context := params.get("context", {})
    if typeof(context) == TYPE_DICTIONARY:
        context = context.duplicate(true)
    else:
        context = {}
    if location != "":
        context["location"] = location
    params["context"] = context
    var event := trigger_opportunity("artifact", params)
    return event

func trigger_refugee_experts(home_region: String = "", overrides: Dictionary = {}) -> Dictionary:
    var params := overrides.duplicate(true)
    var context := params.get("context", {})
    if typeof(context) == TYPE_DICTIONARY:
        context = context.duplicate(true)
    else:
        context = {}
    if home_region != "":
        context["origin"] = home_region
    params["context"] = context
    var event := trigger_opportunity("refugee_experts", params)
    return event

func progress_events(elapsed_ticks: float = 1.0) -> void:
    if elapsed_ticks <= 0.0:
        return
    _time_elapsed += elapsed_ticks
    _advance_events(_active_crises, elapsed_ticks, true)
    _advance_events(_active_opportunities, elapsed_ticks, false)

func resolve_crisis(identifier, resolution: Dictionary = {}) -> Dictionary:
    var event := _resolve_event_lookup(_active_crises, identifier)
    if event == null:
        return {}
    _active_crises.erase(event)
    var completed := _finalize_crisis(event, resolution)
    return completed

func resolve_opportunity(identifier, resolution: Dictionary = {}) -> Dictionary:
    var event := _resolve_event_lookup(_active_opportunities, identifier)
    if event == null:
        return {}
    _active_opportunities.erase(event)
    var completed := _finalize_opportunity(event, resolution)
    return completed

func record_memory_choice(moment_id: String, choice: Dictionary) -> Dictionary:
    var normalized_id := moment_id != "" ? moment_id : "moment_%s" % _moments_by_id.size()
    var moment := _moments_by_id.get(normalized_id, null)
    if moment == null:
        var context_value := {}
        var raw_context := choice.get("context", {})
        if typeof(raw_context) == TYPE_DICTIONARY:
            context_value = raw_context.duplicate(true)
        moment = {
            "id": normalized_id,
            "prompt": choice.get("prompt", ""),
            "context": context_value,
            "choices": [],
            "resolved_at": null,
        }
        _moments_by_id[normalized_id] = moment
    var choice_entry := {
        "timestamp": _time_elapsed,
        "selection": choice.duplicate(true),
    }
    moment["choices"].append(choice_entry)
    var effects := _resolve_memory_effect(choice)
    choice_entry["effects"] = effects.duplicate(true)
    moment["resolved_at"] = _time_elapsed
    moment["outcome"] = effects.duplicate(true)
    memory_choice_committed.emit(normalized_id, moment.duplicate(true))
    return effects

func get_active_crises() -> Array:
    return _duplicate_event_array(_active_crises)

func get_active_opportunities() -> Array:
    return _duplicate_event_array(_active_opportunities)

func get_resolved_events() -> Array:
    return _duplicate_event_array(_resolved_events)

func get_memory_moments() -> Array:
    var results: Array = []
    for moment in _moments_by_id.values():
        results.append(moment.duplicate(true))
    return results

func get_memory_moment(moment_id: String) -> Dictionary:
    if _moments_by_id.has(moment_id):
        return _moments_by_id[moment_id].duplicate(true)
    return {}

func get_canonized_legends() -> Array:
    return _duplicate_dictionary_values(_canonized_legends)

func get_seeded_schools() -> Array:
    return _duplicate_dictionary_values(_seeded_schools)

func get_empowered_guilds() -> Array:
    return _duplicate_dictionary_values(_empowered_guilds)

func get_discovered_artifacts() -> Array:
    return _duplicate_dictionary_values(_artifact_catalog)

func count_discovered_artifacts() -> int:
    return _artifact_catalog.size()

func evaluate_master_line_continuity() -> float:
    var score := 0.0
    for legend in _canonized_legends.values():
        var significance := float(legend.get("significance", 1.0))
        var weight := max(0.5, significance)
        weight += 0.15 * legend.get("tags", []).size()
        score += weight
    for school in _seeded_schools.values():
        var influence := float(school.get("influence", 1.0))
        var cadres: Array = []
        if school.has("cadre") and typeof(school["cadre"]) == TYPE_ARRAY:
            cadres = school["cadre"]
        elif school.has("cadres") and typeof(school["cadres"]) == TYPE_ARRAY:
            cadres = school["cadres"]
        var cadre_bonus := 0.2 * cadres.size()
        score += max(0.25, influence * 0.75 + cadre_bonus)
    for guild in _empowered_guilds.values():
        var influence := float(guild.get("influence", 1.0))
        var disciplines: Array = []
        if guild.has("disciplines") and typeof(guild["disciplines"]) == TYPE_ARRAY:
            disciplines = guild["disciplines"]
        var refugee_cohort: Array = []
        if guild.has("refugee_cohort") and typeof(guild["refugee_cohort"]) == TYPE_ARRAY:
            refugee_cohort = guild["refugee_cohort"]
        var discipline_bonus := 0.1 * disciplines.size()
        var continuity_bonus := 0.15 * refugee_cohort.size()
        score += max(0.5, influence) + discipline_bonus + continuity_bonus
    score += 0.25 * _moments_by_id.size()
    return score

func summarize_for_legacy() -> Dictionary:
    return {
        "crises": _duplicate_event_array(_active_crises),
        "opportunities": _duplicate_event_array(_active_opportunities),
        "resolved": _duplicate_event_array(_resolved_events),
        "canonized_legends": get_canonized_legends(),
        "seeded_schools": get_seeded_schools(),
        "empowered_guilds": get_empowered_guilds(),
        "artifacts": get_discovered_artifacts(),
        "moments_of_memory": get_memory_moments(),
        "master_line_continuity": evaluate_master_line_continuity(),
    }

func _create_event_instance(kind: String, definition: Dictionary, overrides: Dictionary) -> Dictionary:
    var event_id := _next_event_id()
    var event := {
        "id": event_id,
        "type": definition.get("type", kind),
        "kind": kind,
        "name": definition.get("name", definition.get("type", kind).capitalize()),
        "description": definition.get("description", ""),
        "tags": _extract_tags(definition),
        "memory_prompt": definition.get("memory_prompt", ""),
        "metadata": {},
        "context": {},
        "started_at": _time_elapsed,
        "duration": _resolve_duration(definition, overrides.get("duration", null)),
        "remaining_duration": 0.0,
        "elapsed": 0.0,
        "timeline": [],
    }
    event["remaining_duration"] = float(event["duration"])
    var metadata := definition.get("metadata", {})
    if typeof(metadata) == TYPE_DICTIONARY:
        event["metadata"] = metadata.duplicate(true)
    if overrides.has("metadata") and typeof(overrides["metadata"]) == TYPE_DICTIONARY:
        var override_metadata := overrides["metadata"].duplicate(true)
        for key in override_metadata.keys():
            event["metadata"][key] = override_metadata[key]
    var context := overrides.get("context", {})
    if typeof(context) == TYPE_DICTIONARY:
        event["context"] = context.duplicate(true)
    if overrides.has("tags") and typeof(overrides["tags"]) == TYPE_ARRAY:
        event["tags"] = _merge_unique_array(event["tags"], overrides["tags"])
    if kind == CRISIS_KIND:
        var base_severity := definition.get("base_severity", definition.get("severity", 1.0))
        var severity_range := definition.get("severity", base_severity)
        event["severity"] = _resolve_random_range(severity_range, overrides.get("severity", null), float(base_severity))
    else:
        var base_value := definition.get("base_value", definition.get("value", 1.0))
        var value_range := definition.get("value", base_value)
        event["value"] = _resolve_random_range(value_range, overrides.get("value", null), float(base_value))
    if overrides.has("source"):
        event["source"] = overrides["source"]
    if overrides.has("initiated_by"):
        event["initiated_by"] = overrides["initiated_by"]
    event["timeline"].append({"time": _time_elapsed, "state": "started"})
    return event

func _advance_events(events: Array, elapsed_ticks: float, is_crisis: bool) -> void:
    var resolved: Array = []
    for event in events:
        var elapsed := float(event.get("elapsed", 0.0)) + elapsed_ticks
        event["elapsed"] = elapsed
        var duration := float(event.get("duration", elapsed_ticks))
        event["remaining_duration"] = max(0.0, duration - elapsed)
        event["timeline"].append({
            "time": _time_elapsed,
            "state": "progress",
            "remaining": event["remaining_duration"],
        })
        if event["remaining_duration"] <= 0.0:
            resolved.append(event)
    for event in resolved:
        if is_crisis:
            resolve_crisis(event, {"auto": true})
        else:
            resolve_opportunity(event, {"auto": true})

func _resolve_event_lookup(events: Array, identifier) -> Dictionary:
    if typeof(identifier) == TYPE_DICTIONARY:
        var idx := events.find(identifier)
        if idx != -1:
            return identifier
    else:
        for event in events:
            if event.get("id", null) == identifier:
                return event
    return null

func _finalize_crisis(event: Dictionary, resolution: Dictionary) -> Dictionary:
    event["state"] = "resolved"
    event["ended_at"] = _time_elapsed
    event["remaining_duration"] = 0.0
    event["resolution"] = resolution.duplicate(true)
    event["timeline"].append({"time": _time_elapsed, "state": "resolved"})
    var impact := _derive_crisis_impact(event)
    event["impact"] = impact
    if resolution.has("memory_choice") and typeof(resolution["memory_choice"]) == TYPE_DICTIONARY:
        var choice := resolution["memory_choice"]
        var moment_id := choice.get("moment_id", "crisis_%s" % event.get("id", 0))
        var effects := record_memory_choice(moment_id, choice)
        event["impact"]["memory_effects"] = effects
    _resolved_events.append(event)
    crisis_resolved.emit(event.duplicate(true))
    return event

func _finalize_opportunity(event: Dictionary, resolution: Dictionary) -> Dictionary:
    event["state"] = "resolved"
    event["ended_at"] = _time_elapsed
    event["remaining_duration"] = 0.0
    event["resolution"] = resolution.duplicate(true)
    event["timeline"].append({"time": _time_elapsed, "state": "resolved"})
    var outcome := _derive_opportunity_result(event)
    if resolution.has("memory_choice") and typeof(resolution["memory_choice"]) == TYPE_DICTIONARY:
        var choice := resolution["memory_choice"]
        var moment_id := choice.get("moment_id", "opportunity_%s" % event.get("id", 0))
        var effects := record_memory_choice(moment_id, choice)
        outcome["memory_effects"] = effects
    event["outcome"] = outcome
    _resolved_events.append(event)
    opportunity_resolved.emit(event.duplicate(true))
    return event

func _derive_crisis_impact(event: Dictionary) -> Dictionary:
    var severity := float(event.get("severity", 1.0))
    var duration := float(event.get("duration", 1.0))
    var tags := event.get("tags", [])
    var resolution := event.get("resolution", {})
    var mitigation := 0.0
    var community_focus := 1.0
    if typeof(resolution) == TYPE_DICTIONARY:
        mitigation = float(resolution.get("mitigation", resolution.get("aid", 0.0)))
        community_focus = float(resolution.get("community_focus", 1.0))
    var net_severity := max(0.0, severity - mitigation)
    var disruption := (severity + net_severity) * 0.5 * duration
    var population_loss := roundi(disruption * 1.5 / max(0.5, community_focus))
    var infrastructure_loss := roundi(disruption * community_focus)
    var resilience_tested := net_severity * (1.0 + tags.size() * 0.1)
    var recovery_index := max(0.0, community_focus * 5.0 - net_severity * 2.0)
    return {
        "severity": severity,
        "net_severity": net_severity,
        "duration": duration,
        "disruption": disruption,
        "population_loss": population_loss,
        "infrastructure_loss": infrastructure_loss,
        "resilience_tested": resilience_tested,
        "recovery_index": recovery_index,
        "tags": tags.duplicate(),
    }

func _derive_opportunity_result(event: Dictionary) -> Dictionary:
    var outcome := {
        "value": event.get("value", 1.0),
        "type": event.get("type", ""),
        "tags": event.get("tags", []).duplicate(),
    }
    match event.get("type", ""):
        "artifact":
            outcome["artifact"] = _register_artifact_from_event(event, event.get("resolution", {}))
        "refugee_experts":
            outcome["refugees"] = _integrate_refugee_experts(event, event.get("resolution", {}))
        _:
            pass
    return outcome

func _register_artifact_from_event(event: Dictionary, resolution: Dictionary) -> Dictionary:
    var artifact_id := str(resolution.get("artifact_id", event.get("context", {}).get("artifact_id", "")))
    if artifact_id == "":
        artifact_id = "artifact_%03d" % (_artifact_catalog.size() + 1)
    var record := _artifact_catalog.get(artifact_id, {})
    record["id"] = artifact_id
    record["name"] = str(resolution.get("artifact_name", event.get("context", {}).get("artifact_name", event.get("name", artifact_id.capitalize()))))
    record["discovered_at"] = event.get("started_at", _time_elapsed)
    record["catalogued_at"] = _time_elapsed
    record["rarity"] = float(event.get("value", 1.0))
    record["preserved"] = resolution.get("preserve", true)
    record["curator"] = resolution.get("curator", record.get("curator", ""))
    record["significance"] = float(resolution.get("significance", record.get("significance", event.get("value", 1.0))))
    record["story"] = resolution.get("story", record.get("story", event.get("context", {}).get("story", "")))
    var combined_tags := _merge_unique_array(event.get("tags", []), record.get("tags", []))
    if resolution.has("tags") and typeof(resolution["tags"]) == TYPE_ARRAY:
        combined_tags = _merge_unique_array(combined_tags, resolution["tags"])
    record["tags"] = combined_tags
    record["moment_id"] = resolution.get("moment_id", record.get("moment_id", ""))
    _artifact_catalog[artifact_id] = record
    return record.duplicate(true)

func _integrate_refugee_experts(event: Dictionary, resolution: Dictionary) -> Dictionary:
    var guild_id := str(resolution.get("guild_id", event.get("context", {}).get("guild_id", "")))
    if guild_id == "":
        guild_id = "guild_%03d" % (_empowered_guilds.size() + 1)
    var guild_record := _empowered_guilds.get(guild_id, {
        "id": guild_id,
        "name": str(resolution.get("guild_name", event.get("context", {}).get("guild_name", guild_id.capitalize()))),
        "disciplines": [],
        "influence": 0.0,
        "refugee_cohort": [],
        "last_empowered": _time_elapsed,
    })
    guild_record["influence"] = float(guild_record.get("influence", 0.0)) + float(event.get("value", 1.0)) * float(resolution.get("influence_multiplier", 1.0))
    guild_record["last_empowered"] = _time_elapsed
    guild_record["disciplines"] = _merge_unique_array(guild_record.get("disciplines", []), _extract_disciplines(event, resolution))
    guild_record["refugee_cohort"] = _merge_unique_array(guild_record.get("refugee_cohort", []), _extract_refugee_names(event, resolution))
    guild_record["sponsor"] = resolution.get("sponsor", guild_record.get("sponsor", ""))
    _empowered_guilds[guild_id] = guild_record
    var network_entry := {
        "guild_id": guild_id,
        "experts": _extract_refugee_names(event, resolution),
        "established_at": _time_elapsed,
        "origin": event.get("context", {}).get("origin", ""),
    }
    _refugee_networks.append(network_entry)
    return guild_record.duplicate(true)

func _resolve_memory_effect(choice: Dictionary) -> Dictionary:
    var effect_key := ""
    if choice.has("effect"):
        effect_key = str(choice["effect"]).to_lower()
    elif choice.has("type"):
        effect_key = str(choice["type"]).to_lower()
    elif choice.has("path"):
        effect_key = str(choice["path"]).to_lower()
    elif choice.has("mode"):
        effect_key = str(choice["mode"]).to_lower()
    match effect_key:
        "canonization", "canonize", "canonised":
            return _apply_canonization(choice)
        "school", "school_seeding", "seed_school", "seeding":
            return _apply_school_seeding(choice)
        "guild", "empower_guild", "guild_empowerment":
            return _apply_guild_empowerment(choice)
        _:
            return {
                "type": "memory",
                "impact": 0.0,
                "description": choice.get("description", "No lasting effect recorded."),
                "metadata": choice.duplicate(true),
            }

func _apply_canonization(choice: Dictionary) -> Dictionary:
    var legend_id := str(choice.get("legend_id", choice.get("id", "")))
    if legend_id == "":
        legend_id = "legend_%03d" % (_canonized_legends.size() + 1)
    var record := _canonized_legends.get(legend_id, {})
    record["id"] = legend_id
    record["title"] = str(choice.get("title", choice.get("name", legend_id.capitalize())))
    record["significance"] = float(choice.get("significance", record.get("significance", 1.0)))
    record["tags"] = _merge_unique_array(record.get("tags", []), _extract_tags(choice))
    record["timestamp"] = _time_elapsed
    record["source"] = choice.get("source", record.get("source", ""))
    _canonized_legends[legend_id] = record
    return {
        "type": "canonization",
        "legend": record.duplicate(true),
        "legacy_weight": max(1.0, record.get("significance", 1.0)) + 0.1 * record.get("tags", []).size(),
    }

func _apply_school_seeding(choice: Dictionary) -> Dictionary:
    var school_id := str(choice.get("school_id", choice.get("id", "")))
    if school_id == "":
        school_id = "school_%03d" % (_seeded_schools.size() + 1)
    var record := _seeded_schools.get(school_id, {})
    record["id"] = school_id
    record["name"] = str(choice.get("name", record.get("name", school_id.capitalize())))
    record["region"] = choice.get("region", record.get("region", ""))
    record["focus"] = choice.get("focus", choice.get("specialization", record.get("focus", "")))
    record["cadre"] = _merge_unique_array(record.get("cadre", []), choice.get("cadre", choice.get("cadres", [])))
    record["influence"] = float(choice.get("influence", record.get("influence", 1.0)))
    record["seeded_at"] = _time_elapsed
    _seeded_schools[school_id] = record
    return {
        "type": "school_seeding",
        "school": record.duplicate(true),
        "legacy_weight": max(0.75, record.get("influence", 1.0) + 0.15 * record.get("cadre", []).size()),
    }

func _apply_guild_empowerment(choice: Dictionary) -> Dictionary:
    var guild_id := str(choice.get("guild_id", choice.get("id", "")))
    if guild_id == "":
        guild_id = "guild_%03d" % (_empowered_guilds.size() + 1)
    var record := _empowered_guilds.get(guild_id, {})
    record["id"] = guild_id
    record["name"] = str(choice.get("name", record.get("name", guild_id.capitalize())))
    record["disciplines"] = _merge_unique_array(record.get("disciplines", []), choice.get("disciplines", choice.get("specializations", [])))
    record["influence"] = float(record.get("influence", 1.0)) + float(choice.get("influence", 1.0))
    record["refugee_cohort"] = _merge_unique_array(record.get("refugee_cohort", []), choice.get("refugee_cohort", []))
    record["empowered_at"] = _time_elapsed
    _empowered_guilds[guild_id] = record
    return {
        "type": "guild_empowerment",
        "guild": record.duplicate(true),
        "legacy_weight": max(1.0, record.get("influence", 1.0)) + 0.1 * record.get("disciplines", []).size(),
    }

func _normalize_definition(definition: Dictionary, expected_kind: String) -> Dictionary:
    var normalized := definition.duplicate(true)
    normalized["kind"] = expected_kind
    if not normalized.has("type"):
        normalized["type"] = expected_kind
    if not normalized.has("name"):
        normalized["name"] = str(normalized["type"]).capitalize()
    if not normalized.has("default_tags"):
        normalized["default_tags"] = []
    return normalized

func _resolve_random_range(range_data, override, fallback: float) -> float:
    if override != null and typeof(override) in [TYPE_INT, TYPE_FLOAT]:
        return float(override)
    if typeof(range_data) == TYPE_DICTIONARY:
        var minimum := float(range_data.get("min", range_data.get("minimum", fallback)))
        var maximum := float(range_data.get("max", range_data.get("maximum", fallback)))
        if minimum > maximum:
            var temp := minimum
            minimum = maximum
            maximum = temp
        if is_equal_approx(minimum, maximum):
            return minimum
        return _rng.randf_range(minimum, maximum)
    elif typeof(range_data) == TYPE_ARRAY and range_data.size() >= 2:
        var minimum := float(range_data[0])
        var maximum := float(range_data[1])
        if minimum > maximum:
            var temp := minimum
            minimum = maximum
            maximum = temp
        if is_equal_approx(minimum, maximum):
            return minimum
        return _rng.randf_range(minimum, maximum)
    elif typeof(range_data) in [TYPE_INT, TYPE_FLOAT]:
        return float(range_data)
    return fallback

func _resolve_duration(definition: Dictionary, override) -> int:
    if override != null and typeof(override) in [TYPE_INT, TYPE_FLOAT]:
        return max(1, int(round(override)))
    var base_duration := float(definition.get("base_duration", 1.0))
    var variance := float(definition.get("duration_variance", 0.0))
    if variance <= 0.0:
        return max(1, int(round(base_duration)))
    var offset := _rng.randf_range(-variance, variance)
    return max(1, int(round(base_duration + offset)))

func _next_event_id() -> int:
    _event_counter += 1
    return _event_counter

func _extract_tags(source: Dictionary) -> Array:
    var tags: Array = []
    if source.has("tags") and typeof(source["tags"]) == TYPE_ARRAY:
        tags = source["tags"].duplicate()
    elif source.has("default_tags") and typeof(source["default_tags"]) == TYPE_ARRAY:
        tags = source["default_tags"].duplicate()
    return tags

func _merge_unique_array(base: Array, additional) -> Array:
    var result: Array = []
    if typeof(base) == TYPE_ARRAY:
        result = base.duplicate()
    if additional == null:
        return result
    if typeof(additional) != TYPE_ARRAY:
        additional = [additional]
    for value in additional:
        if not result.has(value):
            result.append(value)
    return result

func _extract_disciplines(event: Dictionary, resolution: Dictionary) -> Array:
    var disciplines: Array = []
    if event.get("context", {}).has("disciplines") and typeof(event.get("context", {}).get("disciplines")) == TYPE_ARRAY:
        disciplines = event.get("context", {}).get("disciplines").duplicate()
    if resolution.has("disciplines") and typeof(resolution["disciplines"]) == TYPE_ARRAY:
        disciplines = _merge_unique_array(disciplines, resolution["disciplines"])
    return disciplines

func _extract_refugee_names(event: Dictionary, resolution: Dictionary) -> Array:
    var names: Array = []
    if event.get("context", {}).has("refugees") and typeof(event.get("context", {}).get("refugees")) == TYPE_ARRAY:
        names = event.get("context", {}).get("refugees").duplicate()
    if resolution.has("refugees") and typeof(resolution["refugees"]) == TYPE_ARRAY:
        names = _merge_unique_array(names, resolution["refugees"])
    return names

func _duplicate_event_array(events: Array) -> Array:
    var result: Array = []
    for event in events:
        result.append(event.duplicate(true))
    return result

func _duplicate_dictionary_values(source: Dictionary) -> Array:
    var result: Array = []
    for value in source.values():
        if typeof(value) == TYPE_DICTIONARY:
            result.append(value.duplicate(true))
        else:
            result.append(value)
    return result
