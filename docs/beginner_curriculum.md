# Beginner Ear Training: The Shape & Song Map 🎵

This curriculum focuses on connecting visual fretboard patterns (Shapes) with famous melodies (Songs) to build a fast, intuitive "Guitar Ear".

---

## 📅 Level 1: Essential Shapes (Root Fixed)

In this level, the **Root Note is always fixed** at a specific fret (e.g., 5th string, 3rd fret - C). The goal is to identify the second note based on its position relative to the root.

| Interval | Shape Description | Examples / Mnemonics | Vibe |
| :--- | :--- | :--- | :--- |
| **Major 2nd** | Right 2 Frets (Same String) | **Batman**, "Happy Birthday" (Start) | Suspenseful / Moving |
| **Major 3rd** | 1 String Down, 1 Fret Back | **When the Saints...**, "Oh Susanna" | Bright / Happy |
| **Perfect 4th** | 1 String Down (Same Fret) | **Amazing Grace**, "Bridal Chorus" | Calm / Open |
| **Perfect 5th** | 1 String Down, 2 Frets Right | **Star Wars**, **Superman**, "Twinkle Twinkle" | Heroic / Strong |
| **Major 7th** | 2 Strings Down, 1 Fret Right | **Take on Me** (Chorus End), **Superman** | Airy / Tense |
| **Octave (P8)** | 2 Strings Down, 2 Frets Right | **Over the Rainbow**, "Singing in the Rain" | Complete / Home |

---

## 🎹 Sequencer Integration: "The Riff Library"

Instead of static audio files, we will use the **built-in Chord/Melody Sequencer** to generate these examples dynamically. This allows the user to see the notes being played on the fretboard while hearing the mnemonic.

### 1. Song Fragment Database
We will store short "riffs" (2-4 note fragments) as preset sequences:
- **`riff_batman`**: [C3, C#3, C3, C#3] (Actually m2/M2 oscillation)
- **`riff_superman`**: [C3, G3] (P5 Leap)
- **`riff_rainbow`**: [C3, C4] (Octave)

### 2. Live Playback during Quiz
- When the user is struggling, a **"Mnemonic Riff"** button will appear.
- Clicking it triggers the sequencer to play the associated riff *starting from the current quiz's root note*.
- This bridges the gap between the "Abstract Interval" and the "Real Music" the user already knows.

### 3. Community / Custom Mnemonics
- Users can record their own mnemonic riffs using the sequencer.
- These can be tagged with specific intervals (e.g., "This riff helps me hear m6").

---

## 📈 Learning Path

### Phase 1: Two-Choice Battle
- **Level 1.1**: M2 (Batman) vs P5 (Superman).
- **Level 1.2**: M3 (Saints) vs P4 (Grace).
- **Goal**: Master binary choices before adding more complexity.

### Phase 2: The Major Scale Map
- Combine M2, M3, P4, P5.
- Connect them as a "Pattern" (The first half of the Major Scale).

### Phase 3: Moving the Anchor
- Keep the same shapes but change the Root Note to different frets.
- **Rule**: "The shape stays the same, so the song stays the same."

---

## 🛠 Design Considerations (For UI/Dev)
- **Overlay Layer**: Show a faint line connecting the Root to the Target to emphasize the "Shape".
- **Song Label**: Optionally show the song name (e.g., "Think: Batman") during the first few levels as a hint.
- **Fixed Root Logic**: Ensure the handler doesn't randomize the root until the student advances.
