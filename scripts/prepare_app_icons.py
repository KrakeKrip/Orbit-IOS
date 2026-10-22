from pathlib import Path
from PIL import Image
import zipfile,json,io
root=Path(__file__).resolve().parents[1]
assets=root/'apple/OrbitIOS/OrbitIOS/Assets.xcassets'
import argparse
parser=argparse.ArgumentParser();parser.add_argument('archive', help='Path to original refined-01.zip');args=parser.parse_args()
with zipfile.ZipFile(args.archive) as z:
 manifest=json.loads(z.read('refined-01/manifest.json'))
 names=[]
 for v in manifest['variants']:
  key=v['id']; bg,accent=key.split('-'); name='AppIcon' if key=='ivory-coral' else 'Icon'+bg.title()+accent.title()
  if name!='AppIcon':names.append(name)
  folder=assets/(name+'.appiconset');folder.mkdir(exist_ok=True)
  standard=z.read('refined-01/'+v['png']);dark=z.read('refined-01/assets/night-'+accent+'-1024.png')
  # A grayscale foreground on black is the system tint input; no pre-drawn mask.
  mono=Image.open(io.BytesIO(z.read('refined-01/assets/mark-mono-inverse.png'))).convert('RGBA')
  tinted=Image.new('RGB',mono.size,'black');tinted.paste(Image.new('RGB',mono.size,'white'),mask=mono.getchannel('A'))
  (folder/'OrbitIcon.png').write_bytes(standard);(folder/'Dark.png').write_bytes(dark);tinted.save(folder/'Tinted.png')
  images=[{'filename':'OrbitIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}]
  for appearance,file in [('dark','Dark.png'),('tinted','Tinted.png')]:images.append({'filename':file,'idiom':'universal','platform':'ios','size':'1024x1024','appearances':[{'appearance':'luminosity','value':appearance}]})
  (folder/'Contents.json').write_text(json.dumps({'images':images,'info':{'author':'xcode','version':1}},indent=2)+'\n')
  preview=assets/('IconPreview-'+key+'.imageset');preview.mkdir(exist_ok=True)
  (preview/'Preview.png').write_bytes(standard)
  (preview/'Contents.json').write_text(json.dumps({'images':[{'filename':'Preview.png','idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
  dest=root/'docs/brand/refined-01'/v['svg'];dest.write_bytes(z.read('refined-01/'+v['svg']))
 project=root/'apple/OrbitIOS/OrbitIOS.xcodeproj/project.pbxproj';s=project.read_text();import re;s=re.sub(r'\n\t{4}ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = [^;]+;', '', s);s=s.replace('ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;','ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n\t\t\t\tASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "'+ ' '.join(names)+'";');project.write_text(s)
print('Prepared 12 icons with standard/dark/tinted appearances and 12 previews')
