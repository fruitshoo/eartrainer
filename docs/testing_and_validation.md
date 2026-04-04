# Testing And Validation

This project does not currently include an external Godot test plugin such as GUT or GdUnit4.
To keep validation lightweight, the repository now includes a small in-project runner scene:

- `res://tests/test_runner.tscn`

## What The Runner Covers

The runner checks three things:

1. `MusicTheory` logic smoke tests
2. Autoload API availability for core singletons
3. Basic scene loading and instantiation for key entry points

It is intentionally small. Its job is to catch obvious regressions such as:

- broken script parsing
- missing resources
- invalid scene references
- changed theory helpers returning unexpected values

## How To Run The Automated Checks

From the Godot editor:

1. Open the project.
2. In the FileSystem panel, open `res://tests/test_runner.tscn`.
3. Run the current scene with `F6`.
4. Check the Output panel.

Expected result:

- `[TestRunner] ALL TESTS PASSED`

If any assertion fails, the Output panel will show one or more `[FAIL]` lines.

## Manual Runtime Validation

Run the main scene:

1. Open `res://scenes/main/main.tscn`.
2. Run the project with `F5` or run the current scene with `F6`.

Validate the following flows:

### Startup

- The main scene opens without script errors or missing resource warnings.
- The fretboard, player, HUD, and side panel UI appear.
- Clicking a fret tile moves the player and plays one note attack.

### Interval Quiz

- Open the ear trainer panel and start the interval tab.
- `Replay` repeats the prompt without changing the question.
- `Next` generates a new question.
- `Diatonic`, `Context`, `Fixed Pos`, and string mode controls change quiz behavior.

### Chord Quiz

- Start the chord tab in both theory mode and voicing mode.
- Partial progress should feel incremental, and a completed answer should advance cleanly.
- Wrong inputs should not end the quiz state.

### Progression Quiz

- Start the progression tab and confirm the slot UI updates as playback advances.
- Correct answers should advance the active slot.
- Finishing the sequence should start a fresh question after the success delay.

### Stop And Resume

- Close the side panel while a quiz is active.
- After closing, fret clicks should behave like free play rather than continuing the hidden quiz.
- Re-open the panel and start a fresh quiz.

## Current Watchpoints

These are the highest-value behaviors to re-check after quiz-related changes:

- fret clicks should not double-trigger audio
- stopping a quiz should fully stop hidden input handling
- chord quiz partial progress should not be counted as final success
- interval string constraints should be enforced during answer checking
