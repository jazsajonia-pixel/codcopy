class_name MatchRules
extends RefCounted
## Pure scoring/timer rules for Team Deathmatch and Free-For-All (no nodes: unit-testable).

signal finished(winner_team: int)

var mode := "tdm"
var score_limit := 40
var time_limit := 480.0
var time_left := 480.0
var team_scores := {0: 0, 1: 0}
var individual := {}   ## actor id -> kills (FFA)
var over := false
var winner := -1


func setup(p_mode: String, p_score_limit: int, p_time_limit: float) -> void:
	mode = p_mode
	score_limit = p_score_limit
	time_limit = p_time_limit
	time_left = p_time_limit
	team_scores = {0: 0, 1: 0}
	individual.clear()
	over = false
	winner = -1


## killer_team: team of the killer (or -1 for suicide/world). killer_id used for FFA.
func register_kill(killer_team: int, victim_team: int, killer_id: int) -> void:
	if over:
		return
	if mode == "tdm":
		if killer_team >= 0 and killer_team != victim_team:
			team_scores[killer_team] = team_scores.get(killer_team, 0) + 1
			if team_scores[killer_team] >= score_limit:
				_end(killer_team)
	else:
		if killer_id >= 0 and killer_team != victim_team:
			individual[killer_id] = individual.get(killer_id, 0) + 1
			if individual[killer_id] >= score_limit:
				_end(killer_team)


func tick(delta: float) -> void:
	if over:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		_end(leader())


func leader() -> int:
	if mode == "tdm":
		if team_scores[0] == team_scores[1]:
			return -1
		return 0 if team_scores[0] > team_scores[1] else 1
	var best_id := -1
	var best := -1
	var tie := false
	for id in individual.keys():
		if individual[id] > best:
			best = individual[id]
			best_id = id
			tie = false
		elif individual[id] == best:
			tie = true
	return -1 if tie else best_id


func _end(w: int) -> void:
	over = true
	winner = w
	finished.emit(w)
