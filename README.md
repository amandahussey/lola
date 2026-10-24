# Lola and the Lost Ring: the game

*Swipe to fold, tap to tidy, help Lola clean to find the ring!*

A 2D mobile game (with a little 2.5D depth: items lift, arc through the air and cast
shadows on the floor) built in **Godot 4.7** from the *Bedroom_Messiest_V4* Procreate
file and pages from the book.

## How it plays

1. **Title** → **story page** (the "The diamond!" spread from the book).
2. **Lola's messy room**: 48 pieces of mess, each cut from its own Procreate layer.
   - **Clothes: tap** to see them up close, then fold them with three swipes:
     **swipe left** (the right side folds over), **swipe right** (the left side folds
     over), **swipe up** (the bottom folds up). The folded piece goes into the dresser,
     whose top-left drawer slides open for it. The throw blanket folds the same way and
     goes to the foot of the bed.
   - **Swipe the duvet** to make the bed, and **tap the sock** hanging out of the
     dresser to tuck it back in.
   - **Toys: tap** to tidy. They hop into the toy box, the dollhouse, the trash or
     the pencil cup, where Lola's pencil stands up with the others like on the
     book's clean-room page. Mr. Teddy, the flower, butterfly, cloud and bear go back on the bed;
     the coloring book and notebook go on the desk.
   - In the close-up, a swipe the wrong way just wiggles the clothes, and the X closes
     it without folding.
   - Pinch or scroll to zoom, and drag on empty floor to look around.
   - **Ned helps!** Tap **Ask Ned** (or wait 9 s) and Ned pops up from the bottom of
     the screen with a tip about one thing to tidy, which glows and sparkles. He
     introduces the game, cheers at the halfway point and when the ring is found, and
     coaches each swipe in the folding close-up.
3. Like in the book, when the **very last thing** is put away, the ring shimmers
   **right there on the ground** where it was. Tap it!
4. Ring close-up spread → Lola and Ned high-five → Play again.

## Running it

1. Install Godot 4.7 (standard version, not .NET): https://godotengine.org/download
2. Open Godot → **Import** → choose `lola-game/project.godot`.
3. Press **F5** (▶) to play. On desktop the mouse acts as a finger.

## Putting it on a phone

The project uses the **Compatibility** renderer and landscape orientation, so it runs on
older phones and tablets too.

- **Android:** Editor → *Manage Export Templates* → download. Then *Project → Export → Add →
  Android*, install the Android SDK/JDK the dialog asks for, and plug in a phone with USB
  debugging to use the one-click deploy button.
- **iOS:** needs a Mac with Xcode and an Apple developer account. *Project → Export → Add → iOS*,
  fill in your Team ID and bundle identifier (e.g. `com.bluerosestudios.lola`), and export
  an Xcode project to run on a device.

## Project layout

```
project.godot
scenes/   main.tscn (flow), title.tscn, story_card.tscn, room.tscn (the game + HUD),
          fold_station.tscn (the close-up folding view)
scripts/  main.gd, title.gd, story_card.gd, room.gd (gameplay), fold_station.gd,
          ned_helper.gd (Ned popping up with tips), mess_item.gd, hud.gd, sfx.gd
ui/       theme.tres (fonts + button style)
assets/
  room/     background.png (the *clean* room), items/ (each piece of mess),
            closeup/ (full-size clothes for folding), props/ (toy box, drawer, pencil cups), overlays/, manifest.json (positions + rules)
  story/    book pages used for the intro and ending
  ui/       Lola portraits (worried / happy / joy), Ned (full + badge), ring, sparkle, glow
  audio/    synthesized sound effects + music-box loop (original, royalty-free)
  fonts/    Patrick Hand + Sniglet (SIL Open Font License)
tools/
  art_pipeline/  Python scripts that rebuild assets/room from the .procreate file
  autotest.gd    dev-only playthrough that saves screenshots
```

## Changing things

- **Lola's lines:** search `_hud.say(` in `scripts/room.gd`.
- **Ned's tips:** `_ned_tip()` in `scripts/room.gd`; his folding lines are `NED_LINES` in
  `scripts/fold_station.gd`. `tools/art_pipeline/ned_art.py` re-cuts his picture from the book.
- **Where tidied toys end up:** the `SLOTS` and `D` (destinations) tables in
  `tools/art_pipeline/export.py`. Re-run the export (below), or edit the numbers in
  `assets/room/manifest.json` directly.
- **Which layers count as mess:** `tools/art_pipeline/items.py` (`fold` = tap for the folding close-up, `tap` = tap to tidy).

### Rebuilding the room art after editing the Procreate file

```sh
cd tools/art_pipeline
python3 -m venv venv && ./venv/bin/pip install lz4 pillow numpy
mkdir -p proc && unzip -o ~/Downloads/Bedroom_Messiest_V4.procreate -x 'video/*' -d proc
rm -rf cache && ./venv/bin/python comp.py   # decodes layers
./venv/bin/python export.py   # writes assets/room/*
```

Layer numbers in `items.py` are the layer's position counting **up from the bottom**
of the Procreate layer list. Adding or removing layers shifts them, so check
`items.py` after big edits.

## Dev playthrough

```sh
godot --path . -- --autotest
```
This plays the whole game (including real tap and swipe input) and saves screenshots to
`user://autotest/`.
