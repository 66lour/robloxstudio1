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
