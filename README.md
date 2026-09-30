# robloxstudio1

Projeto Roblox sincronizado com o Studio via [Rojo](https://rojo.space).

## Estrutura

- `src/shared` → `ReplicatedStorage.Shared`
- `src/server` → `ServerScriptService.Server`
- `src/client` → `StarterPlayer.StarterPlayerScripts.Client`

## Como usar

1. Instale o [Aftman](https://github.com/LPGhatguy/aftman) e rode `aftman install` (instala o Rojo).
2. Instale o plugin Rojo no Roblox Studio (`rojo plugin install` ou pelo Toolbox).
3. Rode `rojo serve` na pasta do projeto.
4. No Studio, abra o plugin Rojo e clique em **Connect**.

Para gerar um place: `rojo build -o game.rbxl`.

## Bosses & Loot (Step 3)

15 world bosses in 6 rarities. Kills drop Pets and Armors straight into every contributor's saved inventory.

| Rarity | Bosses | Spawn chance (each) | HP | Damage | Size | Loot rolls |
|---|---|---|---|---|---|---|
| Common | Cursed Skeleton, Rotting Ghoul, Bog Hag | 16% | ~1.5k | ~12 | 1.5× | 1 |
| Uncommon | Wraith Knight, Plague Rat King, Gravebound Golem | 9% | ~4k | ~18 | 2.0× | 1 (≥ Uncommon) |
| Rare | Ancient Pumpkin Lord, Bloodmoon Werewolf, Crypt Lich | 5% | ~10k | ~27 | 2.6× | 2 (1st ≥ Rare) |
| Epic | Frostbound Banshee, Abyssal Warden | 3% | ~25k | ~38 | 3.3× | 2 (1st ≥ Epic) |
| Legendary | Infernal Colossus, The Eclipse Seraph | 1.5% | ~60k | ~58 | 4.2× | 3 (1st ≥ Legendary) |
| Mythic | Nyx'thal, The Pale King | 0.5% | ~150k | ~84 | 5.5× | 3 (1st ≥ Mythic) |

Every boss also has its own exclusive item (3–10% drop chance) and its own mix of abilities (Slam, Charge, Blink, Drain, Meteor, Nova, Enrage).

**Where to tune things**

- `src/shared/Config/Rarities.luau`: tier colors, spawn weights, base HP, damage and size
- `src/shared/Config/BossRoster.luau`: the 15 bosses (looks, abilities, ±10% stat modifiers)
- `src/shared/Config/ItemCatalog.luau`: all Pets and Armors (item ids are saved, so never rename one)
- `src/shared/Config/LootTables.luau`: loot rarity weights per boss tier
- `src/server/Bosses/BossSettings.luau`: spawn cap, interval, aggro and leash ranges

Loading these modules checks the data: a boss that breaks the rarity scaling, or a missing exclusive item, raises an error.

**Setup in Studio**

- Add a `Workspace.BossSpawns` folder with Parts where bosses should appear. Without one, bosses spawn in a ring around the origin.
- Optional: put custom models named after a boss id (e.g. `pumpkin_lord`) in `ServerStorage.BossModels`. Each needs a Humanoid and a PrimaryPart. Bosses without one get a procedural model.
- To test saving, turn on *Game Settings → Security → Enable Studio Access to API Services*. Without it the inventory runs in memory.
- In Studio every player gets a **Test Soulreaver** sword, and chatting `!boss <id>` (e.g. `!boss pale_king`) spawns a boss.

**Damage credit**

`DamageTracker` records damage per player on each boss (`Model.DamageTags`). Your combat code should call `DamageTracker.ApplyDamage(bossModel, player, amount)`. Weapons that use the classic `creator` ObjectValue tag are credited automatically.

**Tests**

With [Lune](https://github.com/lune-org/lune) installed (`aftman install`), run:

```
lune run tests/run         # roster, scaling, spawn odds and loot odds
lune run tests/inventory   # DataStore inventory against a mock store (~16 s)
```
