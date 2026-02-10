extends Node
## Contextual sales pitch templates indexed by NPC personality and pitch angle

const PITCHES := {
	"skeptical": {
		"premium": [
			"This blade defies physics itself. Worth every coin.",
			"The craftsmanship speaks for itself. Rare quality.",
			"Perfectly balanced. A collector's treasure."
		],
		"exotic": [
			"Notice how it vibrates? That's quantum sharpness.",
			"The dimensional flux is a feature, not a flaw.",
			"It phases between realities. Unprecedented cutting power."
		],
		"discount": [
			"Slight instability, but 70% off today only.",
			"Minor calibration issues. Still functional. Half price.",
			"Clearance sale. Some assembly required."
		]
	},
	"gullible": {
		"premium": [
			"Forged in the heart of a dying star. Legendary.",
			"This weapon chose YOU. Destiny made manifest.",
			"Ancient prophecy foretold this transaction."
		],
		"exotic": [
			"It hungers for battle! The spirit awakens!",
			"That tremor? Contained lightning. Pure raw power.",
			"Four-dimensional projection. Your enemies won't understand it either."
		],
		"discount": [
			"Vintage patina. Character-building experience included.",
			"The instability builds reflexes. Training weapon.",
			"Budget-friendly. Results may vary. No refunds."
		]
	},
	"neutral": {
		"premium": [
			"Superior materials. Excellent condition.",
			"Market value confirmed. Fair price.",
			"Standard premium tier. Reliable performance."
		],
		"exotic": [
			"Unique properties. Experimental design.",
			"Unconventional mechanics. Adaptable users only.",
			"Prototype technology. Early adopter advantage."
		],
		"discount": [
			"Cosmetic defects. Functionality intact.",
			"Last season's model. Deep discount applied.",
			"As-is condition. Substantial savings."
		]
	}
}

const BUG_EUPHEMISMS := {
	0.1: "minor quirk",
	0.3: "unique characteristic",
	0.5: "dimensional instability",
	0.7: "aggressive personality",
	0.9: "experimental prototype"
}

func get_pitch_templates(npc_personality: String, angle: String) -> Array:
	if not PITCHES.has(npc_personality):
		return PITCHES["neutral"][angle]

	if not PITCHES[npc_personality].has(angle):
		return []

	return PITCHES[npc_personality][angle]

func get_euphemism(bug_level: float) -> String:
	for threshold in BUG_EUPHEMISMS.keys():
		if bug_level <= threshold:
			return BUG_EUPHEMISMS[threshold]

	return BUG_EUPHEMISMS[0.9]
