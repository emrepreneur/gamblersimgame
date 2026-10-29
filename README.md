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
- `scripts/world.gd` isometric neighbourhood map (tap to walk, tap a building to enter); `building.gd`, `larry.gd` placeholder art drawn in code
- `scripts/sports.gd`, `roulette.gd` gambling screens
- `i18n/strings.csv` all text (key, en, tr)
