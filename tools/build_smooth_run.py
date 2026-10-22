"""Build a 16-pose run cycle from the original textured character using a two-bone leg rig.
No translucent frame blending: every pose has two opaque, separately articulated legs.
"""
from pathlib import Path
import io, base64, math
import numpy as np
import cv2
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
source=Image.open(ROOT/'Assets/Drifter/frames/run/00.png').convert('RGBA')
W,H=source.size

def part(poly):
 mask=Image.new('L',(W,H));ImageDraw.Draw(mask).polygon(poly,fill=255)
 out=source.copy();out.putalpha(Image.fromarray(np.minimum(np.array(source.getchannel('A')),np.array(mask))))
 return np.array(out)

# Texture cutouts retain original seams, freckles, sock and shoe artwork.
parts={
 'front_thigh':(part([(184,320),(214,319),(242,346),(249,383),(232,395),(215,376),(197,355)]),(205,332),(238,380)),
 'front_shin':(part([(230,373),(244,373),(259,400),(270,425),(254,439),(243,412)]),(238,380),(260,425)),
 'front_foot':(part([(255,441),(270,432),(294,411),(300,425),(275,458),(260,457)]),(264,450),(294,419)),
 'back_thigh':(part([(181,331),(205,345),(188,379),(174,395),(155,390),(156,375)]),(188,339),(165,383)),
 'back_shin':(part([(156,368),(171,376),(174,389),(157,396),(130,384),(115,379),(117,358),(142,362)]),(165,383),(127,373)),
 'back_foot':(part([(102,349),(118,353),(130,371),(125,399),(110,414),(96,401),(95,376)]),(127,373),(109,398)),
}
body=part([(0,0),(383,0),(383,321),(232,321),(215,333),(197,339),(179,337),(161,342),(145,343),(122,333),(0,343)])

def warp(segment,a,b):
 image,s0,s1=segment;s0=np.array(s0,dtype=float);s1=np.array(s1,dtype=float)
 a=np.array(a,dtype=float);b=np.array(b,dtype=float)
 v=s1-s0;u=b-a
 vp=np.array([-v[1],v[0]]);vp=vp/np.linalg.norm(vp)*14
 up=np.array([-u[1],u[0]]);up=up/np.linalg.norm(up)*14
 mat=cv2.getAffineTransform(np.float32([s0,s1,s0+vp]),np.float32([a,b,a+up]))
 return Image.fromarray(cv2.warpAffine(image,mat,(W,H),flags=cv2.INTER_CUBIC,borderMode=cv2.BORDER_CONSTANT))

def knee(hip,ankle,l1=60.,l2=55.):
 h=np.array(hip,dtype=float);a=np.array(ankle,dtype=float);v=a-h;d=np.linalg.norm(v)
 d=min(d,l1+l2-0.1);u=v/np.linalg.norm(v)
 along=(l1*l1-l2*l2+d*d)/(2*d);side=math.sqrt(max(0,l1*l1-along*along))
 return h+u*along+np.array([u[1],-u[0]])*side

def pose(p,back=False):
 hip=np.array([194. if back else 205., 334.+3*math.cos(p*math.tau*2)])
 if p<0.52:
  t=p/.52;x=43.-86*t;y=440.
  foot_angle=0.02 if t<.7 else -.38*((t-.7)/.3)
 else:
  t=(p-.52)/.48;s=t*t*(3-2*t);x=-43.+86*s;y=440.-54*math.sin(math.pi*t)
  foot_angle=-.65*math.sin(math.pi*t)
 ankle=np.array([200.+x,y]);k=knee(hip,ankle)
 result=Image.new('RGBA',(W,H))
 prefix='front'  # Retarget the clean leading-leg cutouts to both articulated legs.
 result.alpha_composite(warp(parts[prefix+'_thigh'],hip,k))
 result.alpha_composite(warp(parts[prefix+'_shin'],k,ankle+np.array([0.,16.])))
 # The source rear foot is differently oriented. The same target sole direction makes both support the ground.
 direction=np.array([math.cos(foot_angle),math.sin(foot_angle)])*35
 heel=ankle+np.array([-8*math.cos(foot_angle)-24*math.sin(foot_angle),-8*math.sin(foot_angle)+24*math.cos(foot_angle)])
 foot=warp(parts[prefix+'_foot'],heel,heel+direction)
 result.alpha_composite(foot)
 if back:
  arr=np.array(result);arr[:,:,:3]=(arr[:,:,:3]*.80).astype('uint8');result=Image.fromarray(arr)
 return result

frames=[]
for i in range(16):
 p=i/16
 frame=Image.new('RGBA',(W,H))
 frame.alpha_composite(pose((p+.5)%1,True))
 frame.alpha_composite(pose(p,False))
 bob=round(3*math.cos(p*math.tau*2))
 shifted=cv2.warpAffine(body,np.float32([[1,0,0],[0,1,bob]]),(W,H),flags=cv2.INTER_CUBIC)
 frame.alpha_composite(Image.fromarray(shifted))
 frames.append(frame)
sheet=Image.new('RGBA',(W*4,H*4))
for i,frame in enumerate(frames):sheet.paste(frame,((i%4)*W,(i//4)*H))
out=io.BytesIO();sheet.quantize(colors=256,method=Image.Quantize.FASTOCTREE).save(out,format='PNG',optimize=True)
folder=ROOT/'Assets/Drifter/smooth_run';folder.mkdir(exist_ok=True)
(folder/'run_atlas.tres').write_text('[gd_resource type="ImageTexture" load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/environment/embedded_png_texture.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\npng_base64 = "'+base64.b64encode(out.getvalue()).decode()+'"\n')
preview_dir = ROOT / 'tools' / 'previews'
preview_dir.mkdir(exist_ok=True)
preview=[]
for f in frames:
 bg=Image.new('RGBA',(384,512),'#213034');bg.alpha_composite(f);bg=bg.resize((192,256),Image.Resampling.LANCZOS);preview.append(bg.convert('RGB'))
preview[0].save(str(preview_dir/'smooth_run_preview.gif'),save_all=True,append_images=preview[1:],duration=42,loop=0)
contact=Image.new('RGB',(8*192,2*256),'#213034')
for i,p in enumerate(preview):contact.paste(p,((i%8)*192,(i//8)*256))
contact.save(str(preview_dir/'smooth_run_poses.jpg'))
print('16 distinct rigged poses;',len(out.getvalue()),'atlas bytes')
