import os
from PIL import Image, ImageDraw, ImageFilter
import numpy as np, math
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../assets/ui') + '/'
INK=(38,26,46,255); k=4
# ---- ring: gold band + hexagonal purple diamond (like the book's close-up) ----
W=H=320*k; im=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(im)
cx,cy=160*k,205*k
d.ellipse((cx-101*k,cy-76*k,cx+101*k,cy+96*k),outline=INK,width=34*k)
d.ellipse((cx-95*k,cy-70*k,cx+95*k,cy+90*k),outline=(232,196,92,255),width=22*k)
d.arc((cx-88*k,cy-63*k,cx+88*k,cy+83*k),200,260,fill=(255,236,170,255),width=6*k)
# setting
d.polygon([(cx-38*k,cy-62*k),(cx+38*k,cy-62*k),(cx+26*k,cy-40*k),(cx-26*k,cy-40*k)],fill=(232,196,92,255),outline=INK)
# gem: hex top face + prism sides
gy=cy-118*k
top=[(cx+math.cos(a)*62*k,gy+math.sin(a)*24*k) for a in [i*math.pi/3 for i in range(6)]]
bottom=[(x,y+58*k) for x,y in top]
sides=[(top[0],top[1],bottom[1],bottom[0]),(top[1],top[2],bottom[2],bottom[1]),(top[2],top[3],bottom[3],bottom[2])]
shades=[(118,84,160,255),(140,104,182,255),(104,72,146,255)]
for s,c in zip(sides,shades): d.polygon(s,fill=c,outline=INK)
d.polygon(top,fill=(176,146,214,255),outline=INK)
for s in sides: d.line(list(s)+[s[0]],fill=INK,width=8*k,joint='curve')
d.line(top+[top[0]],fill=INK,width=8*k,joint='curve')
d.line([(cx-30*k,gy-6*k),(cx-6*k,gy-14*k)],fill=(240,230,255,255),width=7*k)
im.resize((320,320),Image.LANCZOS).save(OUT+'ring.png')
# ---- sparkle (4-point star) ----
S=128*k; im=Image.new('RGBA',(S,S),(0,0,0,0)); d=ImageDraw.Draw(im); c=S/2
pts=[]
for i in range(8):
    r=(c*0.95) if i%2==0 else c*0.2; a=i*math.pi/4-math.pi/2; pts.append((c+math.cos(a)*r,c+math.sin(a)*r))
d.polygon(pts,fill=(255,255,255,255))
im=im.resize((128,128),Image.LANCZOS); im.save(OUT+'sparkle.png')
# ---- soft glow ----
n=256; y,x=np.mgrid[0:n,0:n]; r=np.sqrt((x-n/2)**2+(y-n/2)**2)/(n/2)
a=np.clip(1-r,0,1)**2
Image.fromarray(np.dstack([np.full_like(a,255),np.full_like(a,255),np.full_like(a,255),a*255]).astype(np.uint8),'RGBA').save(OUT+'glow.png')
# ---- dust puff ----
n=96*k; im=Image.new('RGBA',(n,n),(0,0,0,0)); d=ImageDraw.Draw(im)
d.ellipse((6*k,6*k,n-6*k,n-6*k),fill=(250,244,255,255),outline=INK,width=5*k)
im.resize((96,96),Image.LANCZOS).save(OUT+'puff.png')
# ---- speech bubble (9-slice friendly) ----
n=192*k; im=Image.new('RGBA',(n,n),(0,0,0,0)); d=ImageDraw.Draw(im)
d.rounded_rectangle((8*k,8*k,n-8*k,n-8*k),radius=60*k,fill=(250,244,255,255),outline=INK,width=8*k)
im.resize((192,192),Image.LANCZOS).save(OUT+'bubble.png')
print('ok')
# ---- swipe arrow (points right; rotated in-game) ----
n=256*k; im=Image.new('RGBA',(n,n//2),(0,0,0,0)); d=ImageDraw.Draw(im)
pts=[(16*k,46*k),(150*k,46*k),(150*k,14*k),(240*k,64*k),(150*k,114*k),(150*k,82*k),(16*k,82*k)]
d.polygon(pts,fill=(255,236,170,255))
d.line(pts+[pts[0]],fill=INK,width=10*k,joint='curve')
im.resize((256,128),Image.LANCZOS).save(OUT+'arrow.png')
