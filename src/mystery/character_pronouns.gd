extends RefCounted
## Named roles prevent victim pronouns being applied to the accused or partner.
static var characters: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
	"res://assets/characters/pronouns.json")).get("characters", {})
const ROLES := ["speaker", "victim", "culprit", "accused", "partner", "other"]

static func slots(input: Dictionary) -> Dictionary:
	var result := input.duplicate()
	for role in ROLES:
		if not input.has(role): continue
		var actor := str(input[role])
		if actor.is_empty(): actor = "the guest"
		var subject := str(characters.get(actor, actor))
		var forms: Dictionary
		if subject == "she":
			forms = {"subject": "she", "object": "her", "possessive": "her", "reflexive": "herself"}
		elif subject == "he":
			forms = {"subject": "he", "object": "him", "possessive": "his", "reflexive": "himself"}
		else:
			# Unknown names stay explicit; never guess gender from a name.
			forms = {"subject": actor, "object": actor, "possessive": actor + "'s", "reflexive": actor}
		forms.Subject = str(forms.subject).substr(0, 1).to_upper() + str(forms.subject).substr(1)
		for form in forms:
			result[role + "_" + form] = forms[form]
	return result
