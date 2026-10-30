# Lucky Larry

A darkly funny gambling life sim set in Las Vegas. Godot 4.5 (GDScript), portrait, for web, iOS and Android. English + Turkish.

Play the latest build: https://emrepreneur.github.io/gamblersimgame/ (rebuilt on every push to `main`).

## Run locally
Open the folder in Godot 4.5 and press Play.

## Test
```
godot --headless --import
godot --headless --script res://tests/test_game_state.gd
godot --headless --script res://tests/smoke_screens.gd
```

## Layout
- `scripts/game_state.gd` all game rules, no UI (tested)
- `scripts/game.gd` autoload `Game`: current state, log, save file, shared UI helpers
- `scripts/world.gd` isometric neighbourhood map from Kenney tiles (tap to walk with A*, tap a building to enter, Joey walks in when a loan is due)
- `scripts/character.gd` 3D Kenney character rendered into the 2D map, with walk/idle animations
- `assets/` Kenney art/UI/audio (CC0) and Fredoka font, see `assets/CREDITS.txt`
- `scripts/vegas_night.gd` night sky, desert, lamps, glow pools and neon signs, all drawn in code
- `scripts/roulette.gd` + `roulette_wheel.gd` + `roulette_table.gd` roulette drawn in code: spinning wheel, ball, felt table, chips
- `scripts/race.gd` roach derby drawn in code: garage, crowd, track, raids, Larry's own roach
- `scripts/sports.gd` sports betting screen
- Web preview shortcut: add `#race`, `#roulette`, `#sports` to the URL to open a screen directly
- `i18n/strings.csv` all text (key, en, tr)
