# kind: fold (swipe) / tap ; dest: where it goes
ITEMS = [
 # --- clothes: swipe to fold ---
 ('tights','fold',[4],'dresser'),
 ('pajamas','fold',[23],'dresser'),
 ('bed_shirt','fold',[44],'dresser'),
 *[(f'pile_{i}','fold',[i],'dresser') for i in range(58,67)],
 *[(f'chair_{i}','fold',[i],'dresser') for i in range(98,104)],
 ('throw_blanket','fold',[36,46],'bed_foot'),
 ('duvet','fold',[41,42],'make_bed'),
 # --- toys: tap to tidy ---
 ('teddy','tap',[88],'bed_teddy'),
 ('flower','tap',[45],'bed'),
 ('butterfly','tap',[107],'bed'),
 ('cloud','tap',[117],'bed'),
 ('bunny','tap',[116],'bed'),
 ('cat','tap',[118],'toybox'),
 ('ball','tap',[90],'toybox'),
 ('boat','tap',[83],'toybox'),
 ('teacup_a','tap',[84],'toybox'),
 ('teacup_b','tap',[85],'toybox'),
 ('block_a','tap',[86],'toybox'),
 ('block_b','tap',[87],'toybox'),
 *[(f'doll_{i}','tap',[i],'dollhouse') for i in range(72,83)],
 ('coloring_book','tap',[114],'desk'),
 ('notebook','tap',[115],'desk'),
 ('pencil','tap',[94],'pencil_cup'),
 ('wrapper','tap',[106],'trash'),
]
EXCLUDE = {119}  # book gutter line
# things that aren't lying on the floor (the ring should appear on the ground, like in the book)
OFF_FLOOR = {'duvet', 'bed_shirt', 'throw_blanket', 'dresser_sock', *[f'chair_{i}' for i in range(98, 104)]}
