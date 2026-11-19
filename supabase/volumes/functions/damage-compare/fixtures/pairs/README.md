# Damage comparison — labelled photo pairs (manual live eval)

The deterministic replay (`fixtures/replay/`) proves the loop, the normaliser
and the verdict rules. This directory is for the **manual** evaluation with the
real vision model, which needs real photos. No images are committed here: keep
the pairs outside the repository or drop them in this folder locally (the files
are outside the `.gitignore` allowlist on purpose).

## Layout

```text
pairs/
├── A01-no-change/
│   ├── entry/01.jpg … 05.jpg
│   ├── exit/01.jpg … 05.jpg
│   └── labels.json
├── B01-new-scratch-left/
…
```

`labels.json`:

```json
{
  "category": "B",
  "same_vehicle": "yes",
  "overall": "possible_new_damage",
  "findings": [{ "zone": "left", "classification": "new" }],
  "must_not_say_none": false
}
```

`zone` uses the prompt's vocabulary (`front`, `rear`, `left`, `right`, `roof`,
`wheels`, `windows`, `interior`, `other`).

## Pair plan (24 pairs)

| Category | What it shows | Pairs | Expected verdict |
|---|---|---|---|
| A | no change, same angles | 5 | `no_new_damage` |
| B | clear new scratch or dent | 5 | `possible_new_damage`, right zone |
| C | pre-existing damage in both sets | 3 | no `new` finding |
| D | glare, rain or wet panels, no damage | 4 | `no_new_damage` (false-positive budget) |
| E | different angles or partial coverage | 3 | `insufficient_evidence` |
| F | mud or dust difference | 1 | `no_new_damage` |
| G | one set blurry or dark | 2 | `insufficient_evidence` |
| H | different vehicle swapped in | 1 | `insufficient_evidence` |

Capture at gate-realistic distances (2–4 m), whole vehicle in frame, same
corners on both sides, 3–5 photos per side. Entry photos first, exit photos at
check-out.

## Consent and privacy

Every pair needs the owner's written consent and every licence plate must be
blurred before the image leaves the lot. The live eval sends the photos to
DeepSeek's vision endpoint, exactly like production. Never commit a photo that
shows a plate, a person or a document.

## Run

```bash
DEEPSEEK_API_KEY=... deno task eval:damage
# or point it at a directory outside the repo
DAMAGE_FIXTURES_DIR=/secure/pairs DEEPSEEK_API_KEY=... deno task eval:damage
```

The task refuses to run in CI or without a key. It prints one line per pair and
fails when any pair breaks its own rule, when A+D exceed one false positive, or
when fewer than 80% of the B pairs flag the right zone. Record the resulting
table in `docs/agent-memory.md` (the design asks for the first run there).
