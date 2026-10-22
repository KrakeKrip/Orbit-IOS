"""Render audit proposals and contact sheets. Documentation only, no app code.

Run with Pillow and the macOS SF font. Coordinates are logical points; PNGs
are rendered at 3x. These are schematic proposals, not SwiftUI screenshots.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "proposals"
S = 3
C = dict(bg="#FAF6ED", surface="#FFFDF8", inset="#F0EBDF", ink="#292722",
         secondary="#69645D", line="#DED7CA", brand="#E75849", action="#B94236",
         tint="#F9E3DC", danger="#AD342C", done="#777168")

def font(size, weight="Regular"):
    f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", round(size*S))
    f.set_variation_by_name(weight)
    return f

class Screen:
    def __init__(self, title, mode=None, context=None, tab=0):
        self.im = Image.new("RGB", (390*S, 844*S), C["bg"])
        self.d = ImageDraw.Draw(self.im)
        self.text(24,17,"9:41",15,"Semibold")
        self.rect(143,11,247,36,"#292722",13)
        self.circle(322,24,2,C["ink"])
        self.rect(333,18,356,29,None,3,C["ink"],1)
        self.rect(335,20,352,27,C["ink"],1)
        self.rect(357,21,359,26,C["ink"],1)
        self.text(20,59,title,24,"Bold")
        self.text(343,60,"•••",19,"Semibold",C["secondary"])
        if context:
            self.text(20,105,context,14,"Regular",C["secondary"])
        if mode:
            self.text(277 if mode != "Повестка" else 250,103,mode,15,"Medium",C["action"])
            self.chevron(359,110)
        self.tab = tab

    def rect(self,x,y,x2,y2,fill,r=0,outline=None,width=1):
        b=tuple(round(v*S) for v in (x,y,x2,y2))
        self.d.rounded_rectangle(b,radius=r*S,fill=fill,outline=outline,width=round(width*S))

    def text(self,x,y,t,size=17,weight="Regular",color=None):
        self.d.text((x*S,y*S),t,font=font(size,weight),fill=color or C["ink"],anchor="lt")

    def line(self,x,y,x2,y2,color=None,width=0.5):
        self.d.line((x*S,y*S,x2*S,y2*S),fill=color or C["line"],width=max(1,round(width*S)))

    def circle(self,x,y,r,fill=None,outline=None,width=1):
        self.d.ellipse(((x-r)*S,(y-r)*S,(x+r)*S,(y+r)*S),fill=fill,outline=outline,width=round(width*S))

    def chevron(self,x,y):
        self.line(x-4,y-2,x,y+2,C["action"],1.5)
        self.line(x,y+2,x+4,y-2,C["action"],1.5)

    def check(self,x,y,done=False):
        self.circle(x,y,11,C["action"] if done else None,C["action"] if done else "#8C857A",1.3)
        if done:
            self.line(x-5,y,x-1,y+4,"white",1.5);self.line(x-1,y+4,x+6,y-4,"white",1.5)

    def row(self,y,lines,meta=None,done=False,flag=False):
        h=24*len(lines)+ (21 if meta else 0)+20
        self.check(31,y+22,done)
        for i,t in enumerate(lines):self.text(56,y+9+i*23,t,17,"Regular",C["secondary"] if done else C["ink"])
        if meta:self.text(56,y+12+23*len(lines),meta,13,"Regular",C["danger"] if flag else C["secondary"])
        self.line(56,y+h,370,y+h)
        return y+h

    def footer(self):
        # Schematic native tab bar; final rendering is owned by iOS.
        self.rect(12,759,378,827,C["surface"],29, C["line"],0.5)
        names=["Сегодня","Входящие","Предстоящее","Проекты"]
        for i,x in enumerate([59,149,240,332]):
            col=C["action"] if i==self.tab else C["secondary"]
            if i==self.tab:self.rect(x-39,765,x+39,817,C["tint"],22)
            if i==0:
                self.circle(x,783,6,None,col,1.4)
                for a in range(0,360,45):
                    a=math.radians(a);self.line(x+9*math.cos(a),783+9*math.sin(a),x+12*math.cos(a),783+12*math.sin(a),col,1.3)
            elif i==1:
                self.rect(x-11,775,x+11,791,None,3,col,1.5);self.line(x-10,784,x-4,784,col,1.5);self.line(x+4,784,x+10,784,col,1.5)
            elif i==2:
                self.rect(x-10,773,x+10,792,None,3,col,1.5);self.line(x-10,779,x+10,779,col,1)
                for dx in [-5,0,5]:self.circle(x+dx,785,1.2,col)
            else:
                self.rect(x-11,776,x+11,792,None,2,col,1.5);self.line(x-11,776,x-11,772,col,1.5);self.line(x-11,772,x-2,772,col,1.5)
            w=self.d.textlength(names[i],font=font(10,"Medium"))/S
            self.text(x-w/2,801,names[i],10,"Medium",col)
        self.rect(136,835,254,839,C["ink"],2)
        self.circle(342,716,28,C["action"])
        self.line(331,716,353,716,"white",2);self.line(342,705,342,727,"white",2)

    def save(self,name,label):
        canvas=Image.new("RGB",(414*S,904*S),"#EEEAE3")
        d=ImageDraw.Draw(canvas)
        d.text((12*S,10*S),"ПРЕДЛОЖЕНИЕ · НЕ СКРИНШОТ",font=font(11,"Semibold"),fill=C["action"])
        canvas.paste(self.im,(12*S,34*S))
        d.text((12*S,884*S),label,font=font(11),fill=C["secondary"])
        canvas.save(OUT/name)

def today():
    s=Screen("Сегодня","Список","Чт, 22 октября")
    s.rect(20,143,370,187,C["inset"],12)
    s.text(31,154,"›",20,"Regular",C["secondary"])
    s.text(48,157,"Просроченные · 2",15,"Medium",C["danger"])
    s.text(283,158,"Перенести",13,"Medium",C["action"])
    s.text(20,212,"Открытые",15,"Semibold",C["secondary"])
    y=s.row(239,["Подготовить презентацию","проекта"],"09:00–10:30 · Работа")
    y=s.row(y,["Согласовать макет"],"09:30–10:30 · Работа")
    y=s.row(y,["Купить материалы для макета"],"Без времени · Личное")
    y=s.row(y,["Проверить план"],"Срок: 23 окт. · Напомнить: 18:00")
    s.text(20,y+28,"Завершённые · 1",15,"Semibold",C["secondary"])
    s.row(y+53,["Прочитать заметки"],done=True)
    s.footer();s.save("today-list.png","Один ритм строк и один порядок метаданных")

def day():
    s=Screen("Сегодня","День","Чт, 22 октября")
    s.text(20,150,"Без времени · 3",15,"Semibold",C["secondary"])
    s.chevron(355,158)
    s.rect(20,179,370,225,C["surface"],10)
    s.check(40,202);s.text(64,193,"Купить материалы для макета",15)
    s.rect(20,231,370,277,C["surface"],10)
    s.check(40,254);s.text(64,245,"Записать идеи после встречи",15)
    s.text(20,287,"Ещё 1",13,"Regular",C["action"])
    top=333
    for hour in range(8,15):
        y=top+(hour-8)*64
        s.text(16,y-5,f"{hour:02}:00",12,"Regular",C["secondary"])
        s.line(62,y,374,y)
    # Exact hour geometry retained. Overlap is encoded by lanes, not color.
    s.rect(64,397,215,493,C["tint"],8);s.rect(64,397,67,493,C["action"],1)
    s.text(76,408,"Подготовить",15,"Medium");s.text(76,428,"презентацию",15,"Medium")
    s.text(76,465,"09:00–10:30",13,"Regular",C["secondary"])
    s.rect(219,429,373,493,C["surface"],8);s.rect(219,429,222,493,C["action"],1)
    s.text(231,439,"Согласовать",15,"Medium");s.text(231,459,"09:30–10:30",13,"Regular",C["secondary"])
    s.rect(64,589,373,605,C["tint"],4);s.rect(64,589,67,605,C["action"],1)
    s.text(76,590,"Проверить план",12,"Medium")
    s.footer();s.save("today-day.png","Та же шапка; точная геометрия времени")

def agenda():
    s=Screen("Предстоящее","Повестка","Октябрь 2026  ›",2)
    for i,(wd,n) in enumerate(zip(["ПН","ВТ","СР","ЧТ","ПТ","СБ","ВС"],range(19,26))):
        x=34+i*53.5
        s.text(x-9,149,wd,11,"Medium",C["secondary"])
        if n==22:s.circle(x,184,18,C["action"])
        s.text(x-9,175,str(n),17,"Semibold" if n==22 else "Regular","white" if n==22 else C["ink"])
        if n in [22,23]:s.circle(x,209,2,C["action"])
    s.line(0,226,390,226)
    s.text(20,248,"Сегодня · 22 октября",17,"Semibold");s.text(350,246,"+",23,"Regular",C["action"])
    y=s.row(280,["Подготовить презентацию","проекта"],"09:00–10:30 · Работа")
    y=s.row(y,["Согласовать макет"],"09:30–10:30 · Работа")
    y=s.row(y,["Купить материалы для макета"],"Без времени · Личное")
    s.text(20,y+29,"Завтра · 23 октября",17,"Semibold");s.text(350,y+26,"+",23,"Regular",C["action"])
    s.row(y+61,["Проверить план"],"Срок: 23 окт. · Напомнить: 18:00")
    s.footer();s.save("upcoming-agenda.png","Те же строки и дата выбора для общего «+»")

def create():
    s=Screen("",tab=0)
    # A proposed native large sheet, with persistent navigation actions.
    s.rect(0,44,390,844,C["bg"],22)
    s.rect(174,51,216,55,"#C2BDB3",2)
    s.text(16,73,"Отмена",17,"Regular",C["action"])
    s.text(125,73,"Новая задача",17,"Semibold")
    s.text(291,73,"Добавить",17,"Semibold",C["action"])
    s.line(0,109,390,109)
    s.text(20,130,"Название",13,"Regular",C["secondary"])
    s.rect(16,152,374,221,C["surface"],12)
    s.text(30,166,"Подготовить презентацию",17)
    s.text(30,190,"проекта",17)
    s.line(93,187,93,210,C["action"],1.5)
    s.rect(16,237,374,401,C["surface"],12)
    for y,title,value in [(253,"Проект","Работа"),(305,"Дата","Сегодня, 22 окт."),(357,"Время","09:00–10:30")]:
        s.text(30,y,title,17);s.text(192,y,value,15,"Regular",C["secondary"])
        s.text(349,y-1,"›",20,"Regular",C["secondary"])
        if y<357:s.line(30,y+36,359,y+36)
    s.rect(16,413,374,465,C["surface"],12)
    s.text(30,430,"Дополнительно",17);s.text(350,429,"›",20,"Regular",C["secondary"])
    s.text(20,478,"Срок и напоминание задаются отдельно",13,"Regular",C["secondary"])
    # Keyboard is a schematic boundary illustration, not a pixel replica.
    s.rect(0,538,390,844,"#DEDDE0",18)
    s.line(0,538,390,538,"#C8C6CA")
    rows=[("йцукенгшщзх",8,584),("фывапролджэ",8,636),("ячсмитьбю",43,688)]
    for letters,x,y in rows:
        w=(390-2*x)/len(letters)
        for i,ch in enumerate(letters):
            xx=x+i*w;s.rect(xx+2,y,xx+w-2,y+44,"#FFFFFF",5);s.text(xx+w/2-6,y+12,ch,19)
    s.rect(8,743,72,790,"#C8C6CE",6);s.text(21,759,"123",15)
    s.rect(80,743,290,790,"#FFFFFF",6);s.text(148,759,"Пробел",15)
    s.rect(298,743,382,790,C["action"],6);s.text(320,759,"Ввод",15,"Medium","white")
    s.rect(136,832,254,837,C["ink"],2)
    s.save("create-task.png","Многострочное название и закреплённые действия")

OUT.mkdir(exist_ok=True)
today();day();agenda();create()
files=["today-list.png","today-day.png","upcoming-agenda.png","create-task.png"]
board=Image.new("RGB",(1720,970),"#EDE9E2")
for i,f in enumerate(files):
    im=Image.open(OUT/f);im.thumbnail((414,904),Image.Resampling.LANCZOS)
    board.paste(im,(16+i*426,28))
board.save(OUT/"overview.png")

# Contact sheet of unmodified captures; the originals retain native resolution.
names=["06-today-list.png","09-day-overlap.png","10-agenda.png","11-three-days.png","12-month.png","04-create-keyboard.png","08-date-editor-medium.png","23-three-days-accessibility-xxxl.png"]
board=Image.new("RGB",(1280,1460),"#EDE9E2")
d=ImageDraw.Draw(board)
for i,n in enumerate(names):
    im=Image.open(ROOT/"screenshots"/n);im.thumbnail((294,650),Image.Resampling.LANCZOS)
    x=13+(i%4)*320;y=35+(i//4)*720
    board.paste(im,(x,y));d.text((x,y+658),n,font=ImageFont.truetype("/System/Library/Fonts/SFNS.ttf",12),fill=C["ink"])
board.save(ROOT/"screenshots"/"contact-sheet.png")

def lum(rgb):
    a=[x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in rgb]
    return sum(x*y for x,y in zip(a,[.2126,.7152,.0722]))
def ratio(a,b):
    l=sorted([lum(a),lum(b)]);return (l[1]+.05)/(l[0]+.05)
def rgb(hex):return [int(hex[i:i+2],16)/255 for i in [1,3,5]]
accent=[.906,.345,.286];ivory=[.98,.96,.91]
white=[1,1,1]
mix=[.85*a+.15*b for a,b in zip(accent,ivory)]
results=[("Текущий accent / white",ratio(accent,white)),("Текущий accent 85% на ivory / white",ratio(mix,white)),("Текущий accent / ivory",ratio(accent,ivory)),("Предложение action / white",ratio(rgb(C['action']),white)),("Предложение secondary / ivory",ratio(rgb(C['secondary']),rgb(C['bg'])))]
(ROOT/"contrast-calculation.txt").write_text("sRGB relative luminance, formula (Lmax + 0.05) / (Lmin + 0.05).\nSource colors, not measured display pixels.\n"+"\n".join(f"{name}: {value:.2f}:1" for name,value in results)+"\n")
print("Rendered four proposals, overview, contact sheet and contrast calculation.")
