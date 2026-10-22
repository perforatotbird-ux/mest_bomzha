#!/usr/bin/env python3
"""Normalize AI sprite sheets into self-contained text textures.
Usage: python tools/build_campaign_art.py enemies.jpg traps.jpg
Sources/provenance and art constraints: docs/sewer-01.md.
"""
from pathlib import Path
from PIL import Image
import numpy as np
import base64,io,sys
ROOT=Path(__file__).resolve().parents[1]
def texture(im,path):
    buf=io.BytesIO();im.save(buf,format='PNG',optimize=True)
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text('[gd_resource type="ImageTexture" load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/environment/embedded_png_texture.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\npng_base64 = "'+base64.b64encode(buf.getvalue()).decode()+'"\n')
def cut(source,box,max_size):
    a=np.array(source.crop(box).convert('RGB'));r,g,b=[a[:,:,i].astype(float) for i in range(3)]
    alpha=255*(1-np.clip((np.minimum(r,b)-g-30)/80,0,1))
    a[:,:,0]=np.minimum(r,g+65).astype('uint8');a[:,:,2]=np.minimum(b,g+50).astype('uint8')
    rgba=Image.fromarray(np.dstack((a,alpha.astype('uint8'))));rgba=rgba.crop(rgba.getbbox())
    rgba.thumbnail(max_size,Image.Resampling.LANCZOS)
    return rgba
if __name__=='__main__':
    enemies=Image.open(sys.argv[1]).resize((1024,1024))
    for name,box in [('guard',(8,8,503,503)),('rat',(520,8,1018,503)),('dog',(8,520,503,1018)),('drone',(520,520,1018,1018))]:
        texture(cut(enemies,box,(256,256)),ROOT/f'Assets/Enemies/{name}.tres')
    traps=Image.open(sys.argv[2]).resize((1024,1024))
    for name,box in [('crusher_head',(8,8,331,1016)),('steam_vent',(350,8,674,1016)),('arc_post',(691,8,1016,1016))]:
        texture(cut(traps,box,(192,320)),ROOT/f'Assets/Environment/Sewer/{name}.tres')
