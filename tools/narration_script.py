"""Writes assets/narration/SCRIPT.md: every line in the story with the file name to record it as.
Run from the project folder:  python3 tools/narration_script.py"""
import re, json

src = open('scripts/story/story_script.gd', encoding='utf-8').read()
WHO = {'lola': 'Lola', 'lola_worried': 'Lola (worried)', 'lola_joy': 'Lola (so happy)', 'ned': 'Ned', 'grandpa': 'Grandpa'}
out = ['# Narration script', '',
       'Record each line and save it in this folder named after its id (for example `p02_a.ogg`;',
       '`.ogg`, `.mp3` or `.wav` all work). The game plays a recording when it finds one and',
       'turns the page by itself when the line ends; lines without a recording just show the words.', '']
chapter = None
for line in src.splitlines():
    m = re.match(r'\s*"(ch\d(?:_\w+)?)": \[', line)
    if m:
        chapter = m.group(1)
        out += ['', f'## {chapter}', '', '| id | who | line |', '|---|---|---|']
        continue
    if '"voice"' not in line:
        continue
    beat = json.loads(line.strip().rstrip(','))
    words = (beat.get('text') or beat.get('say')).replace('\n', ' ')
    out.append(f"| `{beat['voice']}` | {WHO.get(beat.get('who'), 'Narrator')} | {words} |")
open('assets/narration/SCRIPT.md', 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print('wrote assets/narration/SCRIPT.md')
