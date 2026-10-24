import plistlib, numpy as np, pickle
from dec import layer
from PIL import Image
d=plistlib.load(open('proc/Document.archive','rb')); O=d['$objects']
R=lambda x: O[x.data] if isinstance(x,plistlib.UID) else x
top=R(d['$top']['root'])
L=[R(u) for u in R(top['layers'])['NS.objects']]
info=[]
acc=np.zeros((4875,3075,4),np.float32)
for l in reversed(L):  # bottom first
    u=R(l['UUID']); name=R(l['name']); hid=bool(R(l['hidden']))
    im=layer(u)
    if im is None: info.append((u,name,hid,None)); continue
    a=im[...,3]
    ys,xs=np.nonzero(a)
    bbox=(xs.min(),ys.min(),xs.max()+1,ys.max()+1) if len(xs) else None
    info.append((u,name,hid,bbox))
    if hid: continue
    s=im.astype(np.float32)/255  # premultiplied
    acc=s+acc*(1-s[...,3:4])
pickle.dump(info,open('info.pkl','wb'))
np.save('comp.npy',(acc*255).clip(0,255).astype(np.uint8))
