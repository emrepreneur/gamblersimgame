# Gambler Life

A darkly funny life sim about Rıza, a gambler who would sell the iron to place one more bet. Built with Godot 4.5, portrait, for iOS, Android and web. English + Turkish.

## Run
Open the folder in Godot 4.5 and press Play.

## Test
```
godot --headless --import
godot --headless --script res://tests/test_game_state.gd
```

## Layout
- `scripts/game_state.gd` game rules, no UI
- `scripts/main.gd` UI, built in code
- `i18n/strings.csv` all text (keys, en, tr)
