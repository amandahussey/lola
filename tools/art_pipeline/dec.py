import struct, lz4.block, numpy as np, os
def bv41(raw):
    out=b''; i=0
    while i < len(raw):
        tag=raw[i:i+4]
        if tag==b'bv4$': break
        if tag==b'bv41':
            ds,es=struct.unpack('<II',raw[i+4:i+12])
            out+=lz4.block.decompress(raw[i+12:i+12+es],uncompressed_size=ds,dict=out[-65536:]); i+=12+es
        elif tag==b'bv4-':
            ds=struct.unpack('<I',raw[i+4:i+8])[0]; out+=raw[i+8:i+8+ds]; i+=8+ds
        else: raise ValueError(tag)
    return out
W,H,T=3075,4875,256
def layer(uuid):
    img=np.zeros((H,W,4),np.uint8)
    d='proc/'+uuid
    if not os.path.isdir(d): return None
    for f in os.listdir(d):
        if not f.endswith('.lz4'): continue
        c,r=map(int,f[:-4].split('~'))
        b=bv41(open(d+'/'+f,'rb').read())
        a=np.frombuffer(b,np.uint8)
        n=len(a)//4; side=int(n**0.5)
        tw=min(T,W-c*T); th=min(T,H-r*T)
        if n==T*T: a=a.reshape(T,T,4)[:th,:tw]
        else: a=a.reshape(th,tw,4)
        img[r*T:r*T+th, c*T:c*T+tw]=a
    return img
