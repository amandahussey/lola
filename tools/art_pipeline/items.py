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
 # the fluffies: Mr. Teddy and the flower pillow go on the made bed (like Bedroom_Cleanest)
 ('teddy','tap',[88],'bed'),
 ('flower','tap',[45],'bed'),
 ('butterfly','tap',[107],'toybox'),
 ('cloud','tap',[117],'toybox'),
 ('bunny','tap',[116],'toybox'),
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
 # --- the end table: tipped-over cup (with its drips) and a used tissue ---
 ('cup','tap',[54,55],'trash'),
 ('tissue','tap',[57],'trash'),
]
EXCLUDE = {119}  # book gutter line
# things that aren't lying on the floor (the ring should appear on the ground, like in the book)
OFF_FLOOR = {'duvet', 'bed_shirt', 'throw_blanket', 'dresser_sock', 'cup', 'tissue', *[f'chair_{i}' for i in range(98, 104)]}
# the bed: the unmade bed (bare mattress + squashed pillow) sits over the made one from
# Bedroom_Cleanest, which is already in this file underneath it
BED_MESSY = [37, 38, 39, 40]
BED_MADE = [30]          # smooth duvet, revealed where you rub
BED_POSTS = [32, 33]     # front bed posts, drawn over the made duvet
BED_BAND = [31]          # the folded throw blanket lying across the foot of the bed
FLOWER_PILLOW = [35]     # the flower pillow sitting up next to Mr. Teddy
# Bedroom_Cleanest has the bed, end table and dresser 195 px right / 64 px up from this file;
# its Mr. Teddy layer didn't move with them, so shift him back onto the pillow
TEDDY_SHIFT = (-195, 64)
