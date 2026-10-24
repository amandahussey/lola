import os
import numpy as np, wave
SR=44100; OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../assets/audio') + '/'
rs=np.random.RandomState(1)
def save(name,x,vol=0.8):
    x=x/ (np.abs(x).max()+1e-9)*vol
    w=wave.open(OUT+name,'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((x*32767).astype(np.int16).tobytes()); w.close()
def t(d): return np.arange(int(SR*d))/SR
def env(n,a=0.005,r=None):
    e=np.ones(n); ai=int(a*SR); e[:ai]=np.linspace(0,1,ai)
    return e
def bell(f,d,decay=6):
    tt=t(d); return (np.sin(2*np.pi*f*tt)+0.35*np.sin(2*np.pi*f*2*tt)+0.12*np.sin(2*np.pi*f*3.01*tt))*np.exp(-decay*tt)*env(len(tt))
def lowpass(x,a):
    y=np.zeros_like(x); acc=0
    for i,v in enumerate(x): acc+=a*(v-acc); y[i]=acc
    return y
# pop (tap a toy)
tt=t(0.14); f=np.linspace(950,420,len(tt)); pop=np.sin(2*np.pi*np.cumsum(f)/SR)*np.exp(-28*tt)*env(len(tt),0.002); save('pop.wav',pop)
# whoosh (swipe / fold)
tt=t(0.38); n=rs.randn(len(tt)); sh=np.sin(np.pi*tt/0.38)**2
wh=lowpass(n,0.08)*sh+lowpass(n,0.25)*sh*0.3; save('whoosh.wav',wh,0.6)
# fold: two soft fwips
tt=t(0.09); fw=lowpass(rs.randn(len(tt)),0.3)*np.sin(np.pi*tt/0.09)
fold=np.concatenate([fw,np.zeros(int(SR*0.05)),fw*0.8,np.zeros(int(SR*0.05))]); save('fold.wav',fold,0.55)
# plop (lands in box)
tt=t(0.22); f=np.linspace(260,110,len(tt)); plop=np.sin(2*np.pi*np.cumsum(f)/SR)*np.exp(-16*tt)*env(len(tt),0.003)
plop+=bell(660,0.22,14)*0.25; save('plop.wav',plop)
# boop (gentle hint / wrong gesture)
boop=bell(520,0.25,12)+bell(392,0.25,12)*0.5; save('boop.wav',boop,0.45)
# sparkle (ring appears)
sp=np.zeros(int(SR*1.4))
for i,f in enumerate([1046.5,1318.5,1568,2093,2637]):
    b=bell(f,0.9,5)*0.6; s=int(i*0.09*SR); sp[s:s+len(b)]+=b
save('sparkle.wav',sp,0.6)
# win fanfare (music box arpeggio + chord)
notes=[523.25,659.25,783.99,1046.5,783.99,1046.5,1318.5]
win=np.zeros(int(SR*2.6))
for i,f in enumerate(notes):
    b=bell(f,1.4,3.5); s=int(i*0.12*SR); win[s:s+len(b)]+=b
for f in [523.25,659.25,783.99,1046.5]:
    b=bell(f,1.6,2.2)*0.5; s=int(0.95*SR); win[s:s+len(b)]+=b
save('win.wav',win,0.7)
# music box loop: 100 bpm, 16 bars of 3/4 waltz feel -> simple and soft
bpm=104; beat=60/bpm
C4,D4,E4,F4,G4,A4,B4=261.63,293.66,329.63,349.23,392.0,440.0,493.88
C5,D5,E5,F5,G5,A5=523.25,587.33,659.25,698.46,783.99,880.0
mel=[(E5,1),(G5,1),(E5,1),(D5,1),(C5,2),(D5,1),(E5,1),(G5,2),(E5,2),
     (A5,1),(G5,1),(E5,1),(D5,1),(C5,2),(D5,1),(E5,1),(D5,4),
     (E5,1),(G5,1),(E5,1),(D5,1),(C5,2),(D5,1),(E5,1),(G5,2),(A5,2),
     (G5,1),(E5,1),(D5,1),(E5,1),(C5,4),(0,2)]
bass=[C4,G4,A4,F4]*2+[C4,G4,F4,C4]  # one per 4 beats
total=sum(d for _,d in mel)*beat
music=np.zeros(int(SR*(total+2)))
pos=0
for f,d in mel:
    if f: b=bell(f,beat*d+0.6,3.2)*0.55; s=int(pos*SR); music[s:s+len(b)]+=b
    pos+=d*beat
for i in range(int(total/(4*beat))):
    f=bass[i%len(bass)]
    for j,mult in enumerate([1,1.5,2]):
        b=bell(f*mult/2,beat*1.5,3)*0.22; s=int((i*4+j*1.33)*beat*SR); 
        if s+len(b)<len(music): music[s:s+len(b)]+=b
n=int(total*SR); tail=music[n:]; music=music[:n]; music[:len(tail)]+=tail  # wrap tail for seamless loop
save('music_box.wav',music,0.35)
print('done', total)
