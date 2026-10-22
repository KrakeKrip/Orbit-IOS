"""Round 2: selected Orbit mark, colour assets and proposed settings. No app changes."""
from pathlib import Path
from math import sin,cos,radians
from PIL import Image,ImageDraw,ImageFont
import json
ROOT=Path(__file__).resolve().parent;OUT=ROOT/'assets';S=4
BG='#F7F3E9';INK='#282725';PAPER='#F4F0E8';DARK='#17171B';CORAL='#E56C5C';UI='#B94236';SECOND='#746E67';LINE='#DED8CE'
# Selected design retained. Optical centring +4 units (0.78% canvas width).
CX=260;CY=256;R=155;W=42
BACKGROUNDS=[('ivory','Слоновая кость',BG,INK),('white','Белая','#FFFFFF',INK),('night','Ночная',DARK,PAPER)]
ACCENTS=[('coral','Коралл','#E56C5C','#F18A79'),('sage','Шалфей','#547B68','#8CB69A'),('blue','Синий','#527EAA','#83A9D1'),('lilac','Сирень','#8970A8','#BA9CCE')]
def point(a):return CX+R*cos(radians(a)),CY+R*sin(radians(a))
def arcpath(a,b):
 x,y=point(a);u,v=point(b)
 return f'M {x:.4f} {y:.4f} A {R} {R} 0 {int(b-a>180)} 1 {u:.4f} {v:.4f}'
def paths(ink,accent):return ''.join(f'<path d="{arcpath(a,b)}" fill="none" stroke="{col}" stroke-width="{W}" stroke-linecap="round"/>' for a,b,col in [(40,290,ink),(325,370,accent)])
def svg(bg,ink,accent):
 rect=f'<rect width="512" height="512" fill="{bg}"/>' if bg else ''
 return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512" role="img" aria-label="Orbit">{rect}{paths(ink,accent)}</svg>'
def raster(bg,ink,accent,size):
 im=Image.new('RGBA',(512*S,512*S),bg or (0,0,0,0));d=ImageDraw.Draw(im)
 for a,b,col in [(40,290,ink),(325,370,accent)]:
  rr=R+W/2;d.arc(((CX-rr)*S,(CY-rr)*S,(CX+rr)*S,(CY+rr)*S),a,b,fill=col,width=W*S)
  for t in (a,b):
   x,y=point(t);r=W/2;d.ellipse(((x-r)*S,(y-r)*S,(x+r)*S,(y+r)*S),fill=col)
 return im.resize((size,size),Image.Resampling.LANCZOS)
def font(n,w='Regular'):
 f=ImageFont.truetype('/System/Library/Fonts/SFNS.ttf',round(n));f.set_variation_by_name(w);return f
def text(d,x,y,t,n=20,c=INK,w='Regular'):d.text((x,y),t,font=font(n,w),fill=c,anchor='lt')
def centre(d,x,y,t,n=20,c=INK,w='Regular'):
 f=font(n,w);d.text((x-d.textlength(t,font=f)/2,y),t,font=f,fill=c,anchor='lt')
def icon(board,x,y,size,bg,ink,accent):
 im=raster(bg,ink,accent,size);mask=Image.new('L',(size,size),0)
 ImageDraw.Draw(mask).rounded_rectangle((0,0,size-1,size-1),radius=size*.225,fill=255)
 board.paste(im,(round(x),round(y)),mask)
 # White preview gets a quiet boundary outside the artwork.
 if bg=='#FFFFFF':ImageDraw.Draw(board).rounded_rectangle((x,y,x+size-1,y+size-1),radius=size*.225,outline='#E5E0D8',width=1)
manifest={'stage':'design proposal; not integrated','geometry':{'canvas':512,'centre':[CX,CY],'radius':R,'stroke':W,'main_arc':[40,290],'accent_arc':[325,370]},'default':'ivory-coral','variants':[]}
for bid,bname,bg,ink in BACKGROUNDS:
 for aid,aname,light,dark in ACCENTS:
  accent=dark if bid=='night' else light;key=f'{bid}-{aid}'
  (OUT/f'{key}.svg').write_text(svg(bg,ink,accent));raster(bg,ink,accent,1024).convert('RGB').save(OUT/f'{key}-1024.png')
  manifest['variants'].append({'id':key,'label':f'{bname} · {aname}','background':bg,'ring':ink,'accent':accent,'svg':f'assets/{key}.svg','png':f'assets/{key}-1024.png'})
for key,ink,accent in [('mark',INK,CORAL),('mark-inverse',PAPER,'#F18A79'),('mark-mono',INK,INK),('mark-mono-inverse',PAPER,PAPER)]:
 (OUT/f'{key}.svg').write_text(svg(None,ink,accent));raster(None,ink,accent,1024).save(OUT/f'{key}.png')
(OUT/'wordmark.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 950 250" width="950" height="250"><g transform="translate(0 -3) scale(.5)">{paths(INK,CORAL)}</g><text x="263" y="173" font-family="SF Pro Display, Helvetica, Arial, sans-serif" font-size="145" font-weight="600" letter-spacing="-5" fill="{INK}">Orbit</text></svg>')
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
# Main comparison sheet.
b=Image.new('RGB',(1280,1330),'#FDFCFA');d=ImageDraw.Draw(b)
text(d,64,42,'Orbit · открытая орбита',42,w='Semibold')
text(d,64,104,'Выбранный знак. Варианты для настройки иконки.',22,c=SECOND)
text(d,64,147,'ДИЗАЙН-ПРЕДЛОЖЕНИЕ · ПРИЛОЖЕНИЕ НЕ МЕНЯЛОСЬ',13,c=SECOND,w='Medium')
mark=raster(None,INK,CORAL,140);b.paste(mark,(57,183),mark);text(d,213,219,'Orbit',64,w='Semibold')
text(d,605,220,'Одна форма — разные цвета.',22,w='Medium');text(d,605,256,'Базовый вариант: слоновая кость + коралл.',18,c=SECOND)
for j,(_,name,_,_) in enumerate(ACCENTS):centre(d,285+j*260,355,name,22,w='Semibold')
for i,(bid,name,bg,ink) in enumerate(BACKGROUNDS):
 y=405+i*240
 if bid=='ivory':text(d,64,y+56,'Слоновая',20,w='Medium');text(d,64,y+84,'кость',20,w='Medium')
 else:text(d,64,y+71,name,20,w='Medium')
 for j,(_,_,light,dark) in enumerate(ACCENTS):icon(b,200+j*260,y,170,bg,ink,dark if bid=='night' else light)
 d.line((64,y+208,1216,y+208),fill=LINE,width=1)
text(d,64,1158,'Малые размеры',18,w='Semibold')
for size,x in [(32,300),(48,430),(60,580)]:
 icon(b,x,1147,size,BG,INK,CORAL);text(d,x+size+14,1161,f'{size} px',14,c=SECOND)
text(d,64,1240,'Цвет иконки выбирается отдельно от оформления приложения.',20)
text(d,64,1287,'На листе показан стандартный вид. Маска углов условная; SVG и квадратные PNG сохранены отдельно.',14,c=SECOND)
b.save(ROOT/'icon-colours.png')
# Proposed settings screen, rendered at 3x. Explicit draft + Apply.
Q=3;im=Image.new('RGB',(414*Q,904*Q),'#EEEAE3');screen=Image.new('RGB',(390*Q,844*Q),BG);d=ImageDraw.Draw(screen)
def t(x,y,s,n=17,c=INK,w='Regular'):text(d,x*Q,y*Q,s,n*Q,c,w)
def rc(box,fill,r=12,outline=None,width=1):d.rounded_rectangle(tuple(round(v*Q) for v in box),radius=r*Q,fill=fill,outline=outline,width=width*Q)
def circ(x,y,r,fill,outline=None,width=1):d.ellipse(((x-r)*Q,(y-r)*Q,(x+r)*Q,(y+r)*Q),fill=fill,outline=outline,width=width*Q)
t(24,18,'9:41',15,w='Semibold');rc((143,11,247,36),INK,13);rc((333,19,356,29),INK,3)
t(17,64,'‹ Назад',17,UI);t(163,64,'Иконка',17,w='Semibold')
icon(screen,147*Q,124*Q,96*Q,BG,INK,ACCENTS[2][2])
t(94,241,'Слоновая кость · Синий',17,w='Medium')
t(20,294,'ФОН',12,SECOND,w='Medium')
rc((16,319,374,461),'#FFFDF8',14)
for j,(bid,name,bg,ink) in enumerate(BACKGROUNDS):
 x=31+j*116
 if j==0:rc((x-6,329,x+86,451),'#F4E8DE',11,UI,1)
 icon(screen,x*Q,339*Q,80*Q,bg,ink,ACCENTS[2][3] if bid=='night' else ACCENTS[2][2])
 label=['Слоновая','Белый','Ночной'][j];t(x+(0 if j==0 else 17),430,label,12,UI if j==0 else SECOND,w='Medium' if j==0 else 'Regular')
t(20,487,'АКЦЕНТ',12,SECOND,w='Medium');rc((16,512,374,605),'#FFFDF8',14)
for j,(_,name,col,_) in enumerate(ACCENTS):
 x=62+j*89
 if j==2:circ(x,545,21,None,UI,2)
 circ(x,545,15,col)
 if j==2:
  d.line(((x-6)*Q,545*Q,(x-1)*Q,550*Q,(x+8)*Q,540*Q),fill='white',width=2*Q)
 label=['Коралл','Шалфей','Синий','Сирень'][j];f=font(11*Q);xx=x-d.textlength(label,font=f)/Q/2;t(xx,577,label,11,SECOND)
t(20,626,'Не меняет тему и цвета интерфейса.',13,SECOND)
rc((16,675,374,725),UI,13);t(109,692,'Применить иконку',17,'white',w='Semibold')
t(20,746,'Сначала выберите сочетание, затем примените.',12,SECOND)
rc((136,835,254,839),INK,2)
im.paste(screen,(12*Q,34*Q));dd=ImageDraw.Draw(im)
text(dd,12*Q,10*Q,'МАКЕТ НАСТРОЙКИ · НЕ РЕАЛИЗОВАНО',11*Q,UI,'Semibold')
text(dd,12*Q,884*Q,'Предпросмотр и одно подтверждение выбора',11*Q,SECOND)
im.save(ROOT/'settings-proposal.png')
print('Created 12 colour combinations, vector masters, manifest and 2 proposal sheets.')
