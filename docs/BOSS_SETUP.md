# Boss system: Studio setup guide

Everything in `src/` syncs through Rojo. This guide covers what you set up in
Studio yourself, and how to plug the bosses into your tycoon, weapons and
animations.

## 1. Folder structure

Rojo creates these (don't edit them in Studio; edit the files instead):

```
ReplicatedStorage
└─ Shared
   ├─ Config
   │  ├─ BossRoster      15 bosses: stats, walk speed, animation style, abilities
   │  ├─ Rarities        tiers, spawn weights, base HP / damage / size
   │  ├─ WeaponCatalog   weapon damage ladder (5 → 1000)
   │  ├─ ItemCatalog, LootTables
   ├─ LootRoller, Remotes
ServerScriptService
└─ Server (Script)          starts everything
   ├─ Bosses
   │  ├─ BossSpawnCycle     one boss per map, every 20 min from the Dark Portal
   │  ├─ BossService        AI, targeting, damage, death
   │  ├─ BossSettings       all timings and ranges
   │  ├─ DarkPortal, BossNavigator, BossAbilities, BossEffects, BossBuilder, AssetAnimations
   │  └─ Models
   │     ├─ ModelKit, Armory
   │     └─ Designs         one module per boss (cursed_skeleton, pale_king, …)
   ├─ Services              PlotService, DamageTracker, InventoryService, LootService
   ├─ Weapons               WeaponService, WeaponModels
   └─ Dev                   Studio-only chat commands
StarterPlayer.StarterPlayerScripts
└─ Client (LocalScript)
   ├─ Bosses                BossAnimator, PoseSolver, AnimationStyles, ActionPoses, CameraShake
   └─ UI                    loot cards, banners, notices, damage numbers
```

You add these in Studio:

| What | Where | Required? |
|---|---|---|
| The Dark Portal | Any Part or Model named `DarkPortal` anywhere in Workspace | Recommended (a placeholder portal is built at `0, 0, -120` if missing) |
| Boss spawn spot | An `Attachment` named `BossSpawn` inside the portal | Optional (default: 10 studs in front of the portal, on its LookVector side) |
| Tycoon plots | Your tycoon's plot folder (e.g. `Workspace.Tycoons`) | Yes, for bosses to attack anyone (see section 2) |
| Safe zones | Parts named `SafeZone` inside each plot | Optional (default: the whole plot's bounding box) |
| Your weapon models | Tools in `ServerStorage.Weapons`, named like `WeaponCatalog` | Optional (built-in models otherwise) |
| Custom boss models | Models in `ServerStorage.BossModels`, named by boss id | Optional (built-in models otherwise) |
| Material textures | `MaterialVariant`s in `MaterialService` named `Obsidian` (base Glass), `ObsidianRough` (base Basalt), `PolishedGranite` (base Granite) | Optional |

Turn on *Game Settings → Security → Enable Studio Access to API Services* to
test saving loot.

## 2. Plot-only aggro (connecting your tycoon)

Bosses only chase and damage players who own a tycoon plot. Guests ("Not
Assigned") are ignored completely and can't be hurt, and players standing in
their own tycoon are safe. With the default settings guests can't damage
bosses either, so nobody farms loot while invulnerable
(`BossSettings.GuestsCanDamageBosses`).

Your tycoon code isn't in this repository, so `Services/PlotService` recognizes
the common ways kits mark ownership, checked in this order:

1. **A player attribute or value**: `player:SetAttribute("Plot", "Plot3")`, or an
   `ObjectValue`/`StringValue` named `Plot` under the Player. The values `Not Assigned`,
   `None`, empty string, `0` and `false` mean *guest*. Other accepted names:
   `PlotId`, `PlotName`, `Tycoon`, `TycoonId`, `AssignedPlot`.
2. **An owner marker on the plot model** inside `Workspace.Tycoons`, `Plots`,
   `TycoonPlots`, `PlayerPlots` or Zednov's `Tycoons` folder: an `ObjectValue`
   named `Owner` pointing at the Player, or an `Owner`/`OwnerId`/`OwnerUserId`
   attribute or value holding the player's UserId or name.
3. **Teams**: a team named `Not Assigned`, `For Hire`, `Neutral`, `Guests` or `Lobby`
   means guest; another team counts if a plot is named after it or has a
   matching `TeamColor`/`Team` value.

If your tycoon uses something else, the simplest fix is to set the attribute
from your claim code:

```lua
player:SetAttribute("Plot", plot.Name)        -- when they claim a plot
player:SetAttribute("Plot", "Not Assigned")   -- when they leave it
```

Everything is configurable in the `CONFIG` table at the top of
`PlotService.luau`. The server output says which plot folders it found.

## 3. Animations

### Built-in (works out of the box)

Every boss is a Motor6D rig (`Root`, `Waist`, `Neck`, `Jaw`, `LeftShoulder`,
`LeftElbow`, `LeftHip`, `LeftKnee`, …, plus `Cape1..n`, `Tail1..n`,
`TentacleA1..n`, `LeftWing`, `Orbit`, `Float1..n`). Each client animates it
procedurally (`Client.Bosses.BossAnimator`):

- **15 walk/idle styles**, one per boss (`AnimationStyles`): Skeleton *March*,
  Ghoul *Shamble*, Hag *Hunch*, Wraith Knight *GlideArmor* (floating armor pieces
  drift apart), Rat King *Scurry*, Golem *Lumber* and Colossus *Stomp* (both shake
  the camera), Pumpkin Lord *Scarecrow*, Werewolf *Stalk*, Lich *Levitate*,
  Banshee *Glide*, Warden *Tread*, Seraph *Soar*, Nyx'thal *Drift*, Pale King *Regal*.
- **Attack and event poses** synced to each ability's telegraph (`ActionPoses`):
  Melee, Slam, Charge, Blink, Drain, Meteor, Nova, Enrage, Spawn (climbing out of
  the portal) and Death (collapse).
- Strides match leg length and walk speed, so feet don't slide. Capes billow,
  tails and tentacles sway, wings beat, and the head tracks its target.

Tune a style by editing its numbers in `AnimationStyles.luau`. All angles are in
radians.

### Using your own animations (Animation Editor / Moon Animator)

1. Press **Play** in Studio and chat `!boss pale_king` (any boss id).
2. In the Explorer, select `Workspace.Bosses.<Boss Name>`, press **Ctrl+C**, then
   **Stop**.
3. Select `Workspace` and press **Ctrl+V**. You now have the rigged model in edit mode.
   Anchor its `HumanoidRootPart`.
4. Open **Avatar → Animation Editor**, click the model, and animate the joints.
   Make an `Idle` and a `Walk` (both looped), plus any actions you want:
   `Melee`, `Slam`, `Charge`, `Blink`, `Drain`, `Meteor`, `Nova`, `Enrage`, `Spawn`,
   `Death`. `Attack` is used for any action you don't make.
5. **Publish to Roblox** and copy each animation's asset id.
6. Add the ids to the boss in `BossRoster.luau`:
   ```lua
   Animations = {
       Idle = "rbxassetid://1234567890",
       Walk = "rbxassetid://1234567891",
       Melee = "rbxassetid://1234567892",
   },
   ```
   Or, for a custom model, put `Animation` objects with those names in a folder
   called `Animations` inside the model.

The server then plays them through the Humanoid's Animator (they replicate to
everyone). Walk speed is matched to the boss's movement, and action animations
are stretched to fit their telegraph. The procedural system keeps animating the
cape, tails, wings and orbits on top.

## 4. Models

- Each boss's look is in `Bosses/Models/Designs/<id>.luau`, built from
  `ModelKit` helpers (segments, spikes, horns, runes, capes, wings, particles…)
  in "rig units". The boss's rarity scale sizes it, so rarer bosses are bigger.
  `tests/models` checks that every boss towers over the tier below.
- **Materials**: Roblox has no Obsidian or polished-granite material, so they are
  emulated (glossy dark Glass, reflective Granite). Add `MaterialVariant`s
  named as in section 1 to give them real textures.
- **Custom model**: put a Model named after the boss id (e.g. `pumpkin_lord`) in
  `ServerStorage.BossModels`. It needs a `Humanoid` and a `HumanoidRootPart` set
  as its `PrimaryPart`. It is scaled with `Model:ScaleTo(scale)`. If you keep the
  joint names from a copied built-in rig, the procedural animations still work;
  otherwise give it uploaded animations.

## 5. Weapons

`Shared/Config/WeaponCatalog.luau` is the damage ladder:

| Weapon | Damage | Notes |
|---|---|---|
| Splintered Stake | 5 | starter, given on spawn |
| Rusty Pumpkin Carver | 15 | |
| Gravedigger's Spade | 30 | |
| Bonecleaver Axe | 60 | |
| Wraithsteel Longsword | 125 | |
| Hexfire Halberd | 250 | |
| Soulrender Greatsword | 500 | |
| Reaper's Mythic Blade | 1000 | ultimate |

`WeaponService` takes over any Tool whose **name** matches an entry (or that has
a `WeaponId` attribute), wherever it comes from: StarterPack, your shop, your
inventory. It deals the damage on the server, plays the default slash animation,
and shows the attacker a damage number. To keep your existing weapons:

1. Rename your Tools to the catalog names, or edit the catalog names to match
   yours. Add entries for any extra weapons.
2. **Delete the old damage scripts inside those Tools**, or they will deal damage twice.
3. Put the Tools in `ServerStorage.Weapons` (used by `WeaponService.Give`) or keep
   them where your shop gives them out.

Your own combat code should damage bosses with
`BossService.DamageBoss(bossModel, player, amount)`. It credits the damage for
loot and enforces the guest rule. Classic `creator`-tag weapons are credited
automatically.

## 6. Spawn cycle

- Only one boss exists at a time. `BossService.Spawn` refuses while one is alive.
- When the server starts, the portal counts down `FirstSpawnDelay` (1200 s). At
  zero a boss is rolled by rarity weight and climbs out of the Dark Portal.
- The countdown is paused while it lives. The moment it's defeated, the countdown
  restarts at `SpawnInterval` (1200 s = 20 minutes).
- The portal billboard shows the countdown. The workspace attribute
  `NextBossSpawnAt` holds the spawn time (server time) for your own UI.
- A boss that falls out of the world is replaced after 15 s.

Every timing and range is in `Bosses/BossSettings.luau`.

## 7. Studio test commands

| Chat | Does |
|---|---|
| `!plot` | toggle your `Plot` attribute; bosses only fight players with a plot |
| `!boss [id]` | replace the current boss with a new one now |
| `!despawn` | remove the boss (no loot); the 20-minute countdown restarts |
| `!timer [seconds]` | set the portal countdown (default 10) |
| `!weapon <id\|all>` | give yourself weapons, e.g. `!weapon reapers_mythic_blade` |
| `!bosses` | list boss ids |
