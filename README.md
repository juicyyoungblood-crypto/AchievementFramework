# Achievement Framework (Project Zomboid B42)

**Version 0.11.0+**

Framework mod: lifetime counters, JSON achievement packs from any activated mod, player-authored goals, Qualify → Claim rewards, and an in-character **Achievements** tab.

---

## Install

1. Place the mod folder at:

   `User/Zomboid/mods/AchievementFramework/`

   Keep the `42/` (and `common/` if present) layout.

2. Enable **Achievement Framework** in the main Mods list.

3. Enable it again on the **save** (Load → Mods / `Saves/.../mods.txt` must list `AchievementFramework`).  
   Menu-only enable loads Lua at the title screen but **not** in the world.

4. Full quit and relaunch after updates.

---

## Player usage

| Control | What it does |
|--------|----------------|
| **J** (sandbox option; default key code 36) | Opens the character sheet on the **Achievements** tab (progress + Claim). |
| Character sheet → **Achievements** | See progress; **Claim reward** when a row is `[Ready]`. |
| Debug / admin **Sandbox options** → **Achievement Framework** → **Open Achievement Browser** | Authoring UI only (pack list left, your world list + Add form right). |

Rewards are granted on **Claim** (not automatically when the goal is met).

---

## Where JSON packs live

### 1) Framework’s own pack (shipped demo)

```text
Zomboid/mods/AchievementFramework/42/media/data/achievements/pack.json
```

Also accepted (same mod):

```text
.../media/data/achievements.json
.../media/data/achievements/sample.json
```

(Paths without the `media/` prefix are tried as a fallback.)

### 2) Other mods (e.g. KnoxSystem)

Any **activated** mod can ship a pack. AF scans activated mod IDs and loads the same conventional paths from each:

```text
Zomboid/mods/<ModFolder>/42/media/data/achievements/pack.json
```

or:

```text
Zomboid/mods/<ModFolder>/42/media/data/achievements.json
```

**Example for KnoxSystem** (once you add a list):

```text
Zomboid/mods/KnoxSystem/42/media/data/achievements/pack.json
```

Use the mod’s **id** from `mod.info` (`id=KnoxSystem`), not necessarily the folder name, for load logging. The file must be under that mod’s B42 media tree so `getModFileReader` can see it.

Multiple packs merge. **Goal Signature** (`action|modifier|amount`) is unique: first pack that registers a signature wins; later duplicates are skipped.

### 3) Player-authored list (Browser Add form)

Stored per machine (not inside the AF mod folder):

```text
Zomboid/Lua/AF_player_defs.json
```

Written via `getFileWriter` when you Add/Delete in the Browser. This is the **world-local / personal** authored list (local evaluation). It is separate from pack JSON.

Do **not** put player lists in `media/data/achievements/` unless you intend them as a shared pack for everyone who installs that mod.

---

## JSON format

File must be a **JSON array** of objects:

```json
[
  {
    "name": "Prepper",
    "action": "kill",
    "modifier": "none",
    "amount": 1,
    "rewardType": "item",
    "reward": "Base.Whiskey",
    "rewardAmount": 1
  }
]
```

| Field | Required | Meaning |
|-------|----------|---------|
| `name` | yes | Display name |
| `action` | yes | One of: `kill`, `damage`, `eat`, `fish`, `made`, `read`, `daysSurvived` |
| `modifier` | no | `"none"` = total for that action; or a catalog id (weapon family, item key, read bucket, etc.) |
| `amount` | yes | Integer ≥ 1 — how many times / how much |
| `rewardType` | no | `item` (default), `skill_xp`, or `trait` |
| `reward` | yes | See rewards below |
| `rewardAmount` | no | Item stack / XP amount (traits forced to 1). Defaults: item 1, skill_xp 150 |

**Goal Signature** = `action|modifier|amount` (e.g. `kill|none|500`). Two achievements cannot share the same signature.

### Actions and modifiers (high level)

| action | `modifier: "none"` | Other modifiers (examples) |
|--------|--------------------|----------------------------|
| `kill` | Total zombie kills | `type.axe`, `type.firearm`, `base.crowbar`, … |
| `damage` | Total zombie damage | Same weapon/type style as kill |
| `eat` | Meals fully finished | `base.egg`, food fullType keys |
| `fish` | Fish caught | specific fish fullType keys |
| `made` | Craft + build finishes | (totals; intermediates may appear in tracking) |
| `read` | Meaningful reads (anti-spam) | `none`, or buckets `magazinecomic` / `recipe` / `book` / `skillbook` |
| `daysSurvived` | Floor(hours/24) | `none` only |

Only modifiers that map to live track counters are valid (Browser dropdowns enforce this).

---

## Rewards

### Items (`rewardType`: `"item"`)

`reward` must be a **full type** string:

```text
Base.AssaultRifle
Base.Bag_ALICEpack
Base.556Clip
```

**Vanilla B42 names** (from game ItemName data) for the shipped pack:

| Display idea | fullType |
|--------------|----------|
| Military Backpack | `Base.Bag_ALICEpack` |
| M16 | `Base.AssaultRifle` |
| M16 Magazine | `Base.556Clip` |
| Carton of 5.56 | `Base.556Carton` |
| Hatchet | `Base.HandAxe` |
| Firefighter Axe | `Base.Axe` |

### Items from **other mods**

1. Find the item’s **module.type** (e.g. `KnoxSystem.SomeLoot`, `AuthenticZClothing.Something`).
2. Put that exact string in `"reward"`.
3. Ensure that mod is activated on the same save so the item script exists at Claim time.
4. If Claim fails, check console for `[AF] deliver item ... item_fail` — usually a wrong fullType or missing mod.

There is no separate “mod item” field: fullType already includes the module prefix.

### Skill XP (`rewardType`: `"skill_xp"`)

`reward` = **Perks field name** (not always the Skills-tab label):

| Skills tab label | `reward` value |
|------------------|----------------|
| Electrical | `Electricity` |
| Carpentry | `Woodwork` |
| First Aid | `Doctor` |
| Running | `Sprinting` |
| Axe | `Axe` |

`rewardAmount` = XP points granted **flat** (`AddXPNoMultiplier`).

### Traits (`rewardType`: `"trait"`)

`reward` = trait type id (e.g. `Graceful`). Positive traits only in the Browser catalog. Already-owned traits are skipped but Claim still completes.

---

## Shipped starter pack

`media/data/achievements/pack.json`:

| Name | Goal | Reward |
|------|------|--------|
| Good Start | Kill 500 | Military Backpack ×1 |
| God of War | Kill 1000 | M16 ×1 |
| Can't Have One Without the Other | Kill 1001 | M16 Magazine ×3 |
| Let's Up Those Numbers | Kill 1002 | 5.56 carton ×1 |
| Prepper | Survive 1 day | Hatchet ×1 |
| Survivor | Survive 14 days | Firefighter Axe ×1 |
| Reader | Read 20 (any meaningful) | 500 Electrical XP |

---

## Claim / progress notes

- Progress is per **character** (ModData); death clears.
- Scan ~every 5s + every game minute UI refresh.
- **Read** only counts when the read did something (new recipe, mood/title for comics/mags, skill-book pages). Re-reading the same recipe mag does not farm.
- Debug logs: `Zomboid/Lua/AF_debug.log`, totals dump `Zomboid/Lua/AF_check.log`.

---

## Troubleshooting

| Symptom | Check |
|---------|--------|
| No tracking / empty tab | Save `mods.txt` lists AF; console shows two `loading AchievementFramework` lines |
| Pack empty | Path under `42/media/data/achievements/pack.json`; console `[AF] pack ... +N` |
| Item Claim fails | fullType spelling; mod that defines the item is on |
| Hotkey wrong | Sandbox → Achievement Framework → key code (J ≈ 36) |

---

## License

Author-controlled distribution. For personal and private server use unless you have permission to redistribute.
