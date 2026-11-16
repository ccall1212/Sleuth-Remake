# Dialogue data schema

Wording for questioning, confessions and narrator text lives in two JSON files under
`assets/dialogue/`. Both are plain UTF-8 JSON with `{slot}` markers. Code lives in
`tools/case_design/dialogue.py` (loader and renderer) and is checked by
`tools/case_design/validate_dialogue.py` and `tests/case_design/test_dialogue.py`.

## Files

- `personalities.json`: `{personality_id: {line_type: [variants...]}}` for the eight voices
  `warm, nervous, proud, guarded, hot_tempered, curious, fragile, calm`. Every personality has every
  line type, with at least 6 variants each.
- `system.json`: narrator text not tied to a personality. A value is a list of variants, or a single
  string where noted below.

## Personality line types and slots

| Line type | Slots (bold = must appear) | Notes |
| --- | --- | --- |
| `opening` | **speaker** | Narration before the speech. Ends with a comma. No quotes. |
| `claim_solo` | **room** | Core claim, alone. Says "alone" and "evening". No quotes. |
| `claim_pair` | **partner**, **room** | Core claim, with a partner. Says "evening". No quotes. |
| `commentary_victim` | **victim** | Standalone sentence(s). Mixes grief, dislike, indifference. |
| `commentary_suspect` | **other**, victim | Standalone. Points at another guest. |
| `commentary_self` | none | Standalone. About their own situation. |
| `refusal` | **speaker** | **Silent narration only** (user, 2026-11-16): the game never shows the question, so nobody is quoted. One short sentence (at most 100 characters), no hint to ask again (the game lets you retry), no body-part phrasing, no alibi, never final. The rate is 10% of questions. |
| `repeat_lead` | none | Starts a repeated answer. Ends with a comma. |
| `repeat_close` | none | Closes a repeated answer. One short sentence. |
| `confession_defiant`, `_remorseful`, `_triumphant`, `_furious`, `_resigned` | **speaker, victim, weapon, room** | Full block, narration then speech. |
| `ambush_locked` | **speaker, victim, room, weapon** | Murderer locks the door, explains, threatens. |
| `ambush_grab` | **speaker, weapon** | Murderer snatches the carried weapon and strikes. |
| `culprit_corrects_room` | **speaker, victim, weapon, room, chosen_room** | Accused correctly, wrong room. |
| `culprit_corrects_person` | **speaker, victim, weapon, room** | Right room, wrong person. |
| `culprit_corrects_weapon` | **speaker, victim, weapon, chosen_weapon**, room | Right person and room, wrong item in hand (`weapon` is the true weapon, `chosen_weapon` the item carried). |

`claim_*`, `commentary_*` and `repeat_*` lines contain no quotation marks: the game adds them.
`refusal`, confession, ambush and corrects lines are complete blocks and quote their own speech.

## System keys

Single string: `guest_list_header`, `accuse_need_assembly`. Lists (at least 3 unless stated), with the slots each must use:

`assemble_ok` {room}; `accuse_wrong_both` {culprit} {victim} {true_room} {chosen_room};
`win` {culprit} {victim} {moves} {rank}; `ranks` exactly 5 titles, best to worst, 2-3 words;
`warning_suspicious`; `warning_stalking`; `floor_nothing` (someone is watching);
`floor_nothing_unwatched`; `floor_blood` {room}; `weapon_blood` {weapon};
`item_flavor_generic` exactly 12 slotless lines; `too_far_to_hear` {speaker}; `front_stoop`; `secret_panel`.

Carrying and the lens (user, 2026-11-16; the player holds one item and the glass is an item): `assemble_need_item` (assembling needs a non-glass item);
`lens_stain` {item} (at least 6; shown for the weapon and for decoys alike, so the wording must never tell them apart); `lens_clean` {item} (at least 4);
`wound_blunt`, `wound_sharp`, `wound_heavy` (shown with the murder-room trace; never name the item); `hands_full` {item}; `take_item` {item}; `take_glass`;
`drop_item` {item}; `drop_glass`. The old `assemble_need_weapon_found`, `assemble_need_weapon_carried`, `get_refused_not_weapon` and `carrying_limit` are gone.

## Text colours (`styles.json`, user decision 2026-11-16)

`assets/dialogue/styles.json` tells the game which lines to colour. It holds no wording.

| Colour | Hex | Used for |
| --- | --- | --- |
| yellow | `#FFD84A` | `warning_suspicious` |
| orange | `#FF9F40` | `warning_stalking`, `lens_stain` (a stain is only a possible clue and is shown on decoys too, so it is deliberately not red; red would read as "this is the weapon") |
| red | `#FF4D4D` | `floor_blood`, `weapon_blood`, `wound_blunt`, `wound_sharp`, `wound_heavy`, the ambush death scenes (`ambush_locked`, `ambush_grab`) and the runtime's ambush result line |

Layout: `colors` (name to `#RRGGBB`), `system` and `personality_lines` (line key to colour name) and `runtime_text` (`ambush_result`, the
"X killed Y in the Z with the W. Your investigation has ended." text the game builds around an ambush). The validator checks that every key
exists and every colour is defined. Hex values are suggestions for a dark background; the three names are the decision.

Both warnings must say the murderer's state in plain words: every `warning_suspicious` variant contains "The murderer is suspicious of you" and
every `warning_stalking` variant contains "The murderer is stalking you" (validator rule).

## Composing a reply

`compose_reply(data, personality, claim_kind, slots, repeat, pick)`; `claim_kind` is `"solo"` or
`"pair"`, and `pick(n)` returns an int in `[0, n)` (use `Rng.below` so cases replay from a seed).

- First ask: `opening "claim commentary"`: the claim and one commentary sentence form one quoted block.
  The commentary type (victim, suspect or self) is also picked; types that need a slot missing from
  `slots` are skipped.
- Repeat: `"repeat_lead claim repeat_close"`, no opening. The claim's first letter is lowercased to follow
  the comma unless it starts with `I` or a slot.

Pick order is fixed: claim, then (first ask) opening, commentary type, commentary line, or (repeat) lead, close.

## Rules (enforced by the validator)

- Only the slots listed above, written `{name}` exactly; no other braces.
- At most 240 characters per string; no string appears twice anywhere in the dataset.
- Never gendered pronouns (he, she, his, her, him): speakers, victims and suspects have no fixed gender.
- Outside confession, ambush and `culprit_corrects_*` lines, never mention guilt or innocence
  ("guilty", "innocent", "I did it", "I killed", "murderer", "culprit"). Tone must never prove guilt.
- Refusals say nothing about where the speaker was, and never say "never".
- No phrase from the banned list in `validate_dialogue.py` (distinctive phrases of an existing game).
- Optional: set `SLEUTH_REFERENCE_DIR` to a folder and any 6-word run shared with a file in it fails.

## Adding a line

1. Append a string to the right list in `personalities.json` (or `system.json`), matching the voice of
   its neighbours. Write it so it combines with any opening, claim and commentary.
2. Run `python tools/case_design/validate_dialogue.py` (exit 0 means valid).
3. Run `python -m pytest tests/case_design/test_dialogue.py -q`.

To add a new line type or system key, declare it (slots, required slots) in `dialogue.py` first.
