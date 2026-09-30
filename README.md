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

## Bosses, Loot & Weapons

15 world bosses in 6 rarities. **One boss per map**: it climbs out of the Dark
Portal, hunts players who own a tycoon plot, and 20 minutes after it's defeated
the next one emerges. Kills drop Pets and Armors into every contributor's saved
inventory.

**Studio setup, tycoon integration, custom animations and weapons: see [docs/BOSS_SETUP.md](docs/BOSS_SETUP.md).**

| Rarity | Bosses (walk style) | Spawn chance (each) | HP | Size |
|---|---|---|---|---|
| Common | Cursed Skeleton (March), Rotting Ghoul (Shamble), Bog Hag (Hunch) | 16% | ~5,000 | 1.4–1.6× |
| Uncommon | Wraith Knight (GlideArmor), Plague Rat King (Scurry), Gravebound Golem (Lumber) | 9% | ~9,000 | 1.9–2.1× |
| Rare | Ancient Pumpkin Lord (Scarecrow), Bloodmoon Werewolf (Stalk), Crypt Lich (Levitate) | 5% | ~16,500 | 2.5–2.7× |
| Epic | Frostbound Banshee (Glide), Abyssal Warden (Tread) | 3% | ~30,000 | 3.3× |
| Legendary | Infernal Colossus (Stomp), The Eclipse Seraph (Soar) | 1.5% | ~55,000 | 4.0–4.6× |
| Mythic | Nyx'thal (Drift), The Pale King (Regal) | 0.5% | ~100,000 | 5.5–6.1× |

- **Models**: each boss is a detailed Motor6D rig built by its own design module
  (`src/server/Bosses/Models/Designs`), 106–248 parts, with particles, runes and
  lights.
- **Animation**: procedural and client-side, with 15 themed walk/idle styles and
  attack poses synced to each ability's telegraph. You can swap in uploaded
  Animation Editor animations.
- **Movement**: 8–10 studs/s, so bosses are slow, relentless pursuers (players
  run at 16). They path around obstacles.
- **Targeting**: only players assigned to a plot, and never inside their own
  tycoon. Guests are ignored and can't be hurt.
- **Weapons** (`WeaponCatalog`): starter 5 → Rusty Pumpkin Carver 15 → … →
  Reaper's Mythic Blade 1000 damage per hit, all dealt on the server.

**Tests**

With [Lune](https://github.com/lune-org/lune) installed (`aftman install`), run from the repo root:

```
lune run tests/run         # roster, scaling, spawn odds, loot odds, weapon ladder
lune run tests/models      # builds all 15 rigs: joints, attachments, budgets, size order
lune run tests/poses       # animation math on real rigs (limbs, wings, capes, orbits)
lune run tests/plots       # plot assignment and safe-zone detection
lune run tests/weapons     # builds every weapon Tool
lune run tests/inventory   # DataStore inventory against a mock store (~16 s)
```
