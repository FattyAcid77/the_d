# Yazzed Fight — everything you can change

Five scripts. This lists **every** setting on each, what it does, and how to
add animations.

Scene shape in the test file:

	YazzedFight (Node2D)
	├── Juice          BossJuice     screen shake / hit-stop / flash
	├── Fight          BossFight     the brain — stages, HP, win/reset
	├── TV             BossTV        drops in, takes the 2 key hits
	├── Yazzed         YazzedBoss    the charging body
	├── Trap1 / Trap2  BossObject    hurt him when he charges through
	├── Throwable1     BossObject    Sami picks up and throws
	├── Hazard1        BossObject    hurts Sami
	└── StartTrigger   Area2D        walk in to begin

To change any of these: click the node, edit in the **Inspector** on the right.

---

## 1. Fight  (boss_fight.gd) — the one you'll touch most

**Pieces**
| Setting | What it does |
|---|---|
| `boss` | drag the Yazzed node here |
| `tv` | drag the TV node here |
| `objects` | every trap/throwable — they get reset with the fight |
| `juice` | drag the Juice node here |

**Start**
| Setting | What it does |
|---|---|
| `trigger_area` | walk into this Area2D to begin. Leave empty and call `start_fight()` yourself |
| `intro_dialog` | a Dialog resource played before the fight |
| `boss_name` | speaker name for that dialog |

**Stages**
| Setting | What it does |
|---|---|
| **`start_stage`** | **TESTING: 1, 2 or 3 — jump straight into a stage instead of playing through** |
| `start_stage2_hp` | HP he has if you start at stage 2 (-1 = full) |
| `stage3_hp` | stage 2 ends when his HP drops to this (default 50) |
| `stage_pause` | breathing room between stages (seconds) |

**Ending**
| Setting | What it does |
|---|---|
| `victory_comic` | Nada's comic, played when he dies |
| `victory_video` | or a single .ogv instead |
| `won_flag` | flag raised on victory (dialogs/doors react to it) |

**UI**
| Setting | What it does |
|---|---|
| `show_health_bar` | the bar at the top |
| `health_bar_name` | what it's labelled |

---

## 2. Yazzed  (yazzed_boss.gd) — how he feels

**Health**
| Setting | What it does |
|---|---|
| `max_hp` | total health (100) |
| `stage3_hp_threshold` | his own copy of the threshold |

**Timing — stage 1 & 2 (readable)**
| Setting | What it does |
|---|---|
| `telegraph_seconds` | wind-up before he launches (1.0) — **the fairness dial** |
| `rest_seconds` | pause between attacks (1.4) |
| `charge_speed` | how fast he charges (420) |
| `stun_seconds` | how long he's stunned after a wall (1.6) — his opening |

**Timing — stage 3 (fast & aggressive)**
| Setting | What it does |
|---|---|
| `telegraph_seconds_s3` | shorter wind-up (0.5) |
| `rest_seconds_s3` | shorter rest (0.8) |
| `charge_speed_s3` | faster charge (620) |
| `max_bounces` | wall bounces before he gives up (3) |
| `wall_feint_chance` | 0..1 — how often he charges a WALL on purpose to come at Sami from an angle (0.35) |
| `bounce_speed_keep` | speed kept per bounce (0.95 = barely slows) |

**Contact**
| Setting | What it does |
|---|---|
| `contact_damage` | damage to Sami on hit |
| `contact_cuts` | does the hit open a bleeding wound? |
| `contact_cause` | which DeathCause is blamed |
| `contact_cooldown` | seconds before he can hurt Sami again |

**Look**
| Setting | What it does |
|---|---|
| `sprite` | the AnimatedSprite2D to drive |
| `anim_idle` / `anim_telegraph` / `anim_charge` / `anim_stunned` / `anim_hurt` / `anim_dead` | animation names |
| `use_squash_stretch` | squash on wind-up, stretch on charge (works with no art) |
| `telegraph_squash` | how much he squashes (1.25, 0.78) |
| `charge_stretch` | how much he stretches (1.18, 0.86) |
| `shake_pixels` | the wind-up rattle (3.0) |

---

## 3. TV  (boss_tv.gd)

| Setting | What it does |
|---|---|
| `drop_height` | how far above it starts (420) |
| `drop_seconds` | how long the drop takes (0.9) |
| `land_bounce_pixels` | the settle bounce on landing (18) |
| `lift_seconds` | how fast it retreats between stages (0.7) |
| `shake_on_land` | screen shake strength on landing (8) |
| `max_hits` | hits before it's wrecked (2 = the whole fight) |
| `sprite` | AnimatedSprite2D |
| `anim_idle` / `anim_hit` / `anim_broken` | animation names |
| `hit_particles` | a PackedScene spawned on each hit (sparks, glass) |

---

## 4. Objects  (boss_object.gd) — one script, three flavours

Set `kind`:
- **TRAP** — sits there; damages Yazzed when he charges through
- **THROWABLE** — Sami presses interact to pick up, interact again to throw
- **HAZARD** — hurts Sami; Yazzed can shove it at him

| Setting | What it does |
|---|---|
| `boss_damage` | damage to Yazzed (traps/throwables) |
| `player_damage` | damage to Sami (hazards, or a thrown miss) |
| `player_cuts` | does it open a bleeding wound? |
| `damage_cause` | DeathCause blamed |
| `debuff_seconds` | how long the debuff lasts (0 = none) |
| `debuff_name` | free text: "slow", "blind"… so one handler can tell them apart |
| `throw_speed` / `throw_range` | how it flies |
| `boss_can_push` / `push_speed` | can Yazzed shove it at Sami |
| `one_use` | consumed after landing a hit |
| `respawn_seconds` | comes back after N seconds (0 = gone for good) |
| `sprite` | the visual node (used for spin + hop) |
| `spin_while_flying` | rotation speed in the air |
| `spawn_hop_pixels` | little bounce when it appears |

To hook up a debuff, connect the object's `debuffed_player(seconds)` signal
to your own code and do whatever you want (slow Sami, blur the screen…).

---

## 5. Juice  (boss_juice.gd) — the feel

| Setting | What it does |
|---|---|
| `shake_decay` | how fast shakes die out (6) |
| `shake_max_offset` | biggest shake in pixels (24) |
| `shake_max_roll` | camera tilt during shakes (0.06) |
| `hit_stop_seconds` | freeze-frame length on a hit (0.07) |
| `hit_stop_scale` | how slow (0.02 = near freeze) |
| `flash_color` / `flash_seconds` | the white flash |
| `zoom_amount` / `zoom_seconds` | camera zoom punch |

Call from anywhere: `juice.shake(12.0)`, `juice.hit_stop()`, `juice.flash()`,
`juice.zoom_punch()`.

---

## Adding sprite animations (per stage)

**The short version:** Yazzed doesn't have per-stage animation names — he has
per-STATE names. If you want stage 3 to look different, the simplest route is
a second set of animations plus one line of setup (below).

### Step 1 — make the SpriteFrames
1. Click the `Sprite` node inside `Yazzed` (the AnimatedSprite2D).
2. In the Inspector, `Sprite Frames` → **New SpriteFrames**.
3. Click it to open the SpriteFrames panel at the bottom.
4. Create these animations (the "Add Animation" button, top-left):

       idle        standing, breathing
       telegraph   the wind-up (set it to LOOP)
       charge      flying forward
       stunned     dazed after a wall
       hurt        taking damage
       dead        the end

5. Drag your frames into each. Turn **loop off** on `hurt` and `dead`.

### Step 2 — check the names match
Those six names are exports on the Yazzed node (`anim_idle`, `anim_telegraph`
and so on). If you'd rather call them `Yazzed_Idle`, just type that into the
matching field — the code plays whatever name is in the export.

Missing animations are skipped safely: he keeps his current art and the
squash-stretch still carries the read.

### Step 3 — different art per stage (optional)
Add this to your own script (or ask me to build it in):

```gdscript
# when the stage changes, swap to the stage-3 animation names
func _on_stage_changed(stage: int) -> void:
	if stage == 3:
		$Yazzed.anim_idle = "idle_angry"
		$Yazzed.anim_telegraph = "telegraph_angry"
		$Yazzed.anim_charge = "charge_angry"
```

Connect `Fight`'s `stage_changed(stage)` signal to that function. Now stage 3
uses a whole different animation set.

### The TV and the objects
Same idea: the TV wants `idle`, `hit`, `broken`. Objects use a plain Node2D
(`sprite`) — Sprite2D or AnimatedSprite2D both work, since only rotation and
position are touched.

---

## Signals — for adding your own juice

On **Fight**: `fight_started`, `stage_changed(stage)`, `boss_damaged(hp, max)`,
`fight_won`, `fight_reset`

On **Yazzed**: `charge_started(target)`, `charge_ended`, `wall_hit(normal)`,
`tv_hit`, `player_hit`, `stunned_started(seconds)`, `damaged(amount, hp_left)`,
`died`

On **TV**: `dropped`, `hit`, `destroyed`

On **Objects**: `hit_boss(damage)`, `hit_player`, `debuffed_player(seconds)`,
`picked_up`, `thrown(direction)`, `used_up`

Example — sound on every charge: connect `charge_started` to a function that
plays an AudioStreamPlayer.

---

## Testing recipes

- **Jump to the bouncy phase**: `Fight → start_stage = 3`. Run, walk into the
  trigger, and you're straight into stage 3 with the TV down.
- **Make him harmless while you test movement**: `contact_damage = 0`.
- **See the wind-up clearly**: `telegraph_seconds = 2.0`.
- **Test the reset**: call `Fight.reset_fight()` — hook it to
  `Deaths.player_died` so dying restarts the fight.
