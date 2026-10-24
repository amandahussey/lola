# Lola and the Lost Ring: the game

*Read the story, play along, and help Lola find her ring!*

The whole book as a 2D mobile story game, built in **Godot 4.7** from the book's Procreate
files. Each page is rebuilt from its layers, so Lola, Ned and the diamond can move, and
small games happen inside the story.

## How it plays

The book, chapter by chapter. Facing pages that make one scene (the bedroom, the tornado,
BONK!) are shown together as one spread with the words underneath; single scenes (Lola
loves purple, the stairs, dinner with Grandpa) are shown as one page with the words beside
them. Tap Next (or anywhere) to turn the page; recorded narration plays when it's there.

1. **Lola Loves Purple** (pages 2-6), then the **purple tornado** game: Lola's things whirl
   around the tornado from the book; tap 10 to catch them into the toy box.
2. **Something Sparkly** (7-14): the mirror zooms in all foggy and you rub it clean with
   your finger (Ned's cloth follows along) until his reflection shows. DUCK! Tap Lola to
   help her duck... too late, BONK! Tap the bucket to splash her, then the sparkle to find
   the diamond.
3. **Dinner with Grandpa** (15-16): "Diiinnnerrr!" Tap to hop Lola down the stairs one step
   at a time to Ned. At the table, pass Grandpa the bread, then tap him for a story.
4. **The Ring Is Lost!** (17-20): search the room. Tap the glowing places (her desk, the
   covers, under the bed... and Ned, who's ticklish); none of them has the ring.
5. **Clean-Up Time** (21-26): Lola's room (below). Halfway through, the book's sad page
   and Ned's kind words (pages 23-26) play over the room, then you keep going.
6. **Found!** (27-36): the shimmer, the diamond, The End (almost?), Lola & Ned's real-life
   clean-up game, and the real The End.

Reaching a chapter unlocks it on the title screen.

**Lola's messy room** (chapter 5): 50 pieces of mess, each cut from its own Procreate layer.
   - **Make the bed first!** Ned says "If you only make your bed, you'll feel better!" and
     you **rub the covers** with your finger to smooth them out; the neatly made bed from
     *Bedroom_Cleanest* appears wherever you rub. Until it's made, tapping anything else
     just points back at the bed. Then Lola: "See? Isn't that better already?"
   - **The fluffies go on top**: Mr. Teddy sits up on the pillow and the flower pillow
     props up beside him, just like the clean room. Ned's hints point at them first.
   - **Clothes: tap** to see them up close, then fold them with three swipes:
     **swipe left** (the right side folds over), **swipe right** (the left side folds
     over), **swipe up** (the bottom folds up). The folded piece goes into the dresser,
     whose top-left drawer slides open for it. The throw blanket folds the same way and
     lands folded across the foot of the bed.
   - **Tap the sock** hanging out of the dresser to tuck it back in.
   - **The end table**: the tipped-over cup and the used tissue go in the trash.
   - **Toys: tap** to tidy. They hop into the toy box, the dollhouse, the trash or
     the pencil cup, where Lola's pencil stands up with the others like on the
     book's clean-room page. Mr. Teddy, the flower, butterfly, cloud and bear go back on the bed;
     the coloring book and notebook go on the desk. The butterfly, cloud and bear go in
     the toy box.
   - In the close-up, a swipe the wrong way just wiggles the clothes, and the X closes
     it without folding.
   - Pinch or scroll to zoom, and drag on empty floor to look around.
   - **Ned helps!** Tap **Ask Ned** (or wait 9 s) and Ned pops up waving from the bottom
     of the screen with a tip about one thing to tidy, which glows and sparkles. He
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
scenes/   main.tscn (flow), title.tscn (Play + chapters), room.tscn (the cleaning game + HUD),
          fold_station.tscn (the close-up folding view)
scripts/  main.gd (chapter flow + saved progress), title.gd, room.gd (cleaning gameplay),
          fold_station.gd, ned_helper.gd (Ned popping up with tips), mess_item.gd, hud.gd,
          sfx.gd, narration.gd (finds recorded lines)
          story/  story_player.gd (plays pages and spreads), story_script.gd (the whole book)
          games/  tornado.gd (chapter 1's purple tornado)
ui/       theme.tres (fonts + button style)
assets/
  room/     background.png (the *clean* room), items/ (each piece of mess),
            closeup/ (full-size clothes for folding), props/ (toy box, drawer, pencil cups),
            bed/ (unmade and made bed, posts, and how the teddy, flower pillow and throw
            look once they're on the bed), overlays/, manifest.json (positions + rules)
  story/    title picture, and pages/ (every book page split into parts, plus pages.json)
  ui/       Lola portraits (worried / happy / joy), Ned (waving, holding clothes, badge),
            ring, sparkle, glow (Lola and Ned are cut from the book's Procreate pages)
  audio/    synthesized sound effects + music-box loop (original, royalty-free)
  fonts/    Patrick Hand + Sniglet (SIL Open Font License)
tools/
  art_pipeline/  Python scripts that rebuild the room, the book pages and the character
                 pictures from the .procreate files
  narration_script.py  writes the recording list in assets/narration/SCRIPT.md
  autotest.gd    dev-only playthrough that saves screenshots
```

## Changing things

- **The story:** `scripts/story/story_script.gd` has every chapter as a list of beats (turn
  to a page or spread, show a line, show/move a part, wait for a tap). The order of chapters
  and games is `FLOW` in `scripts/main.gd`.
- **Narration:** record the lines listed in `assets/narration/SCRIPT.md` and drop the files
  in `assets/narration/` named by their id (`p02_a.ogg` ...). After changing the story's
  words, run `python3 tools/narration_script.py` to refresh the list.
- **Which layers move on a page:** `PAGES` in `tools/art_pipeline/book_pages.py` (see below).
- **The little games inside pages** are story beats too: `rub` (the mirror), `hop` (the
  stairs: one `[dx, dy]` per step), `spots` (searching: positions are page pixels on the
  spread, 1300 tall). See the list at the top of `story_script.gd`.

- **Lola's lines:** search `_hud.say(` in `scripts/room.gd`.
- **Ned's tips:** `_ned_tip()` in `scripts/room.gd`; his folding lines are `NED_LINES` in
  `scripts/fold_station.gd`.
- **How much rubbing makes the bed:** `BED_BRUSH` and `BED_DONE` at the top of `scripts/room.gd`.
- **Lola and Ned pictures:** `tools/art_pipeline/book_chars.py` cuts them from the book's
  Procreate pages (2, 7, 10, 28 and 36); see the top of that file to rebuild them.
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

### Rebuilding the storybook pages and character pictures

```sh
cd tools/art_pipeline
for n in $(seq 2 36); do mkdir -p book/$n && unzip -o ~/Downloads/$n.procreate -x 'video/*' -d book/$n; done
./venv/bin/python book_pages.py      # writes assets/story/pages/* (or: book_pages.py 13 14)
./venv/bin/python book_chars.py      # Lola, Ned and Grandpa portraits in assets/ui
```

## Dev playthrough

```sh
godot --path . -- --autotest
```
This plays the whole book (reading every page, catching the tornado toys, cleaning the
room with real tap and swipe input) and saves screenshots to `user://autotest/`.
