import pickle, numpy as np, os
from dec import layer
from PIL import Image
info=pickle.load(open('info.pkl','rb'))
DW,DH=4875,3075
_cache={}
def disp(i):
    if i not in _cache:
        p=f'cache/{i}.npy'
        if os.path.exists(p): _cache[i]=np.load(p)
        else:
            a=layer(info[i][0])
            a=None if a is None else np.ascontiguousarray(a.transpose(1,0,2)[::-1,::-1])
            os.makedirs('cache',exist_ok=True)
            if a is not None: np.save(p,a)
            _cache[i]=a
    return _cache[i]
def bbox(i):
    a=disp(i)[...,3]; ys=np.nonzero(a.any(1))[0]; xs=np.nonzero(a.any(0))[0]
    return (xs[0],ys[0],xs[-1]+1,ys[-1]+1) if len(xs) else None
def composite(idxs):
    acc=np.zeros((DH,DW,4),np.float32)
    for i in sorted(idxs):
        a=disp(i)
        if a is None: continue
        s=a.astype(np.float32)/255; acc=s+acc*(1-s[...,3:4])
    return acc
def to_img(acc):
    a=acc[...,3:4]; rgb=(acc[...,:3]/np.maximum(a,1e-4)).clip(0,1)
    return Image.fromarray((np.dstack([rgb,a])*255).astype(np.uint8),'RGBA')
