{$resource _Pen.png}
{$resource sPen.png}
{$resource Fill.png}
{$resource sFill.png}
{$resource Vd.png}
{$resource sVd.png}
{$resource Palitra.png}
{TODO:
- Исправить проблемы с рисованием при нестандартном масштабе 777
- Вернуть Undo
- Пофиксить перерисовку при масштабировании
- Уменьшить количество вызовов Redraw
- Оптимизировать код
- Центровать отрисовку
}
Uses GraphABC,System.Drawing,System.Drawing.Imaging;
type
  HSV = record H,S,V: integer;end;
var
  ///Ширина тайла
  TW := 32;
  ///Высота тайла
  TH := 32;
  /// Массив пикселей которым заполняется Bmp.
  RawBmp:= new Byte[612 * 512 * 4];
  Bmp:Bitmap;
  ///Ширина окна
  W: integer;
  ///Высота окна
  H: integer;
  ///Тайл
  Tile: array[,] of Color;
  ///Параметры выделения
  VSX,VSY,VW,vH: integer;
  ///Выделение
  Buffer: array[,] of Color;
  ///Редактирование или просмотр
  ShowMaket := true;
  KeyCode: integer;// := -11000;
  KeyPressed: boolean;
  MouseX, MouseY: integer;
  MousePressed: boolean;
  MouseCode: integer;
  FirstColor := clBlack;
  TwoColor := clWhite;
  ///Инструмент. 0 - карандаш, 1 - заливка, 2 - выделение, сглаживание ... 
  Tool: byte := 0;
  ToolPics: array of Picture;
  PixelSize, ShowScale: integer;
  ///Сетка
  MP := 1;
  ///Editor work field place and size
  ESX,ESY,EDX,EDY: integer;
  ///Рабочая папка
  MainDir := System.IO.Directory.GetCurrentDirectory;
  Palitra: array[,] of Color;
  TileSet: array[,] of Picture;
  Hue := 90;
  Sat := 0;
  Ve := 0;
  
  //Цвет
  RawFHUE:= new Byte[100 * 10 * 4];
  FHUE:Bitmap;
  RawFHSV:= new Byte[100 * 100 * 4];
  FHSV:Bitmap;
  RawA:= new Byte[100 * 10 * 4];
  BA:Bitmap;//Bitmap A прозрачность
function Button(Name: string;X,Y,_W,_H: integer): boolean;
begin
  GraphABC.Brush.Color := clGray;
  FillRoundRect(X,Y,X+_W,Y+_H,4,4);
  GraphABC.Brush.Color := clWhite;
  FillRoundRect(X+1,Y+1,X+_W-2,Y+_H-2,4,4);
  DrawTextCentered(X,Y,X+_W,Y+_H,Name);
  if MousePressed and (MouseX > X) and (MouseX < X+_W) and (MouseY > Y) and (MouseY < Y+_H) then Result := true;
end;
procedure TextRect(X,Y,X2,Y2: integer; S: string; C: Color);
begin
  SetBrushColor(C);
  FillRect(X,Y,X2,Y2);
  DrawTextCentered(X,Y,X2,Y2,S);
end;
procedure TextOut(Title, Text: string);
var
  Pos: integer;
  Done: boolean;
  Tlen: integer;
procedure AccurateTextOut(TX, TY, Width, Height: integer; Text: string);
var
  WordA: array of string;
  NowWord: integer;
  NW: string;
  NumWords: integer;
  Done: boolean;
  now: integer;
begin
  ClearWindow(clSilver);
  Button(Title,(W+100) div 2 - Title.Length*GraphABC.Font.Size div 2,0,Title.Length*GraphABC.Font.Size,28);
  Button('Прочитал',(W+100) div 2 - 55,H-28,110,28);
  GraphABC.Brush.Color := clBlack;
  FillRect(TX-4,TY-4,TX+Width+4,TY+Height+4);
  GraphABC.Brush.Color := clGray;
  FillRect(TX-2,TY-2,TX+Width+2,TY+Height+2);
  
  NumWords := 1; //for end word...
  for i: integer := 1 to Length(Text) do
    if Text[i] = ' ' then NumWords += 1;
  SetLength(WordA, NumWords);
  for i: integer := 1 to Length(Text) do
  begin
    if Text[i] = ' ' then
    begin
      WordA[NowWord] := NW;
      NW := '';
      NowWord += 1;
    end
    else
      NW := NW + Text[i];
  end;
  WordA[NowWord] := NW;
  NowWord := 0;
  Tlen := 0;
  while (NowWord < NumWords) and (TY < Height) do
  begin
    NW := '';
    Done := false;
    while not Done do
    begin
      if WordA[NowWord] <> '\n' then
      NW := NW + ' ' + WordA[NowWord] else Done := true;
      NowWord += 1;
      if not ((NowWord < NumWords) and (TextWidth(NW + WordA[NowWord]) < Width)) then Done := true;
    end;
    now += 1;
    if now > pos then
    begin
      TextOut(TX, TY, NW);
      TY := TY + TextHeight(NW);
      Tlen += 1;
    end;
  end;
end;
procedure Control;
begin
  while (not MousePressed) and (not KeyPressed) do;
  if KeyCode = VK_Down then if Tlen >= (H-60) div TextHeight('W') then Pos += 1;
  if KeyCode = VK_Up then if Pos > 0 then Pos -= 1;
  if KeyCode = VK_Enter then Done := true;
  if Button('Прочитал',(W+100) div 2 - 55,H-28,110,28) then Done := true;
end;
begin
  while not Done do begin
  AccurateTextOut(10,30,W+80,H-60,Text);
  Redraw;
  Control end;
  while MousePressed do;
end;
procedure MyRect(X,Y,_w,_h: integer) := FillRect(X,Y,X+_w,Y+_h);
/// h - 0..360, s,v - 0..100;
function HSVtoRGB(h,s,v:integer): Color;
var
  r, g, b, Vi, Vm, Vd, a:real;
begin
  Vm:= (100-s)*v/100;
  a:= (v-Vm)*((h mod 60)/60);
  Vi:= Vm+a;
  Vd:= v-a; 
  
  case Floor(h/60) of
    0:begin r:= v; g:= Vi; b:= Vm; end;
    1:begin r:= Vd; g:= v; b:= Vm; end;
    2:begin r:= Vm; g:= v; b:= Vi; end;
    3:begin r:= Vm; g:= Vd; b:= v; end;
    4:begin r:= Vi; g:= Vm; b:= v; end;
    5:begin r:= v; g:= Vm; b:= Vd; end;
  end;
  Result:= RGB(Round((r/100)*255),Round((g/100)*255),Round((b/100)*255));
end;
function RGBtoHSV(r,g,b:byte): HSV;
var
  min,max,delta:byte;h,s,v:integer;
begin
  min:= System.Math.min(r,System.Math.min(g,b));
  max:= System.Math.max(r,System.Math.max(g,b));
  delta:= max - min;
  
  if max = min then h:= 0
  else if (max = r)and(g >= b) then
    h:= round(60*(((g-b)/255)/(delta/255)))
  else if (max = r)and(g < b) then
    h:= round(60*(((g-b)/255)/(delta/255)))+360
  else if max = g then 
    h:= round(60*(((b-r)/255)/(delta/255)))+120
  else if max = b then 
    h:= round(60*(((r-g)/255)/(delta/255)))+240;
  
  if max <> 0 then s:= round(delta/max*100) else s:= 0;
  v:= round(max/255*100);
  Result.H := h;
  Result.S := s;
  Result.V := v;
end;
procedure DrawHSV(var bytes:array of byte; Width:integer);
begin var i:integer;
  for var x:=0 to Width - 1 do
     for var y:=0 to Bytes.Length div (Width*4)-1 do begin
     i:= (y * Width + x)*4;
     bytes[i+0]:=  HSVtoRGB(HUE,x,y).B;// B
     bytes[i+1]:=  HSVtoRGB(HUE,x,y).G;// G
     bytes[i+2]:=  HSVtoRGB(HUE,x,y).R;// R
     bytes[i+3]:=  HSVtoRGB(HUE,x,y).A;// A
     end;
end;
procedure DrawHUE(var bytes:array of byte; Width:integer);
begin var i:integer;
  for var x:=0 to Width - 1 do
     for var y:=0 to Bytes.Length div (Width*4)-1 do begin
     i:= (y * Width + x)*4;
     bytes[i+0]:=  HSVtoRGB(Round(x*3.6),100,100).B;// B
     bytes[i+1]:=  HSVtoRGB(Round(x*3.6),100,100).G;// G
     bytes[i+2]:=  HSVtoRGB(Round(x*3.6),100,100).R;// R
     bytes[i+3]:=  HSVtoRGB(Round(x*3.6),100,100).A;// A
     end;
end;
procedure DrawA(var bytes:array of byte; Width:integer);
begin var i:integer;
  for var x:=0 to Width - 1 do
     for var y:=0 to Bytes.Length div (Width*4)-1 do begin
     i:= (y * Width + x)*4;
     bytes[i+0]:=  255-(x*2.55).Round;// B
     bytes[i+1]:=  255-(x*2.55).Round;// G
     bytes[i+2]:=  255-(x*2.55).Round;// R
     bytes[i+3]:=  255;// A
     end;
end;
procedure ClearTile(cl: color);
begin
  GraphABC.Brush.Color := cl;
  FillRect(0,0,W,H);
end;
function BytesToImage(bytes:array of byte; Width:integer):Bitmap;
begin
  var Height:= (bytes.Length div 4) div Width;
  result:= new Bitmap(Width,Height);
  var rect:= new Rectangle(0, 0, Width, Height);
  var bmData:= result.LockBits(rect, ImageLockMode.WriteOnly,result.PixelFormat);
  System.Runtime.InteropServices.Marshal.Copy(bytes, 0, bmData.Scan0, bytes.Length);
  result.UnlockBits(bmData);
end;
procedure KeyDown(key: integer);
begin
  KeyCode := key;
  KeyPressed := true;
end;
procedure KeyUp(key: integer);
begin
  KeyCode := -11000;
  KeyPressed := false;
end;
procedure MouseDown(x,y,mb: integer);
begin
  MouseX := x;
  MouseY := y;
  MousePressed := true;
  MouseCode := mb;
end;
procedure MouseMove(x,y,mb: integer);
begin
  MouseX := x;
  MouseY := y;
  MouseCode := mb;
end;
procedure MouseUp(x,y,mb: integer);
begin
  MouseX := x;
  MouseY := y;
  MousePressed := false;
end;
procedure Init;
begin  
  SetLength(Tile,TW,TH);
  SetLength(Buffer,TW,TH);
  for i: integer := 0 to TH-1 do
  for j: integer := 0 to TW-1 do
    Tile[j, i] := clWhite;
  if TW > TH then
    PixelSize := W div TW
  else
    PixelSize := H div TH;
  if PixelSize = 0 then PixelSize := 1;
  ShowScale := 1;
  ESX := W div PixelSize div 2 - TW div 2;
  ESY := H div PixelSize div 2 - TH div 2;
  EDX := (TW-ESX)-((TW-ESX)-(W div PixelSize));
  EDY := (TH-ESY)-((TH-ESY)-(H div PixelSize));
  SetLength(Palitra,8,8);
end;
procedure DrawTile(var Bytes:array of byte; Width:integer);
begin
var i,tx,ty:integer;
  // В цикле проходим по каждому пикселю.
  for var x:=0 to Width - 1 do
     for var y:=0 to Bytes.Length div (Width*4)-1 do begin
     i:= (y * Width + x)*4;
     tx:= (x div ShowScale) mod TW;
     ty:= (y div ShowScale) mod TH;
     bytes[i+0]:=  Tile[tx,ty].B;// B
     bytes[i+1]:=  Tile[tx,ty].G;// G
     bytes[i+2]:=  Tile[tx,ty].R;// R
     bytes[i+3]:=  Tile[tx,ty].A;// A
     end;
end;
procedure ToolsPanel;
begin
  System.Threading.Monitor.Enter(GraphABC.GraphABCControl);
  //Выбор цвета и Тон цвета
  GraphBufferGraphics.DrawImage(FHUE,W,200);
  DrawHSV(RawFHSV,100);
  FHSV := BytesToImage(RawFHSV,100);
  GraphBufferGraphics.DrawImage(FHSV,W,100);
  //Color
  GraphABC.Brush.Color := ARGB(192,0,0,0);
  FillRect(W+Sat-1,100,
           W+Sat+1,200);
  FillRect(W,100+Ve-1,
           W+100,100+Ve+1);
  //HUE
  GraphABC.Brush.Color := ARGB(192,0,0,0);
  FillRect(W+(HUE / 3.6).Round-1,200,W+(HUE / 3.6).Round+1,210);
  //Прозрачность цвета
  GraphBufferGraphics.DrawImage(BA,W,210);
  GraphABC.Brush.Color := ARGB(192,FirstColor.A,FirstColor.A,FirstColor.A);
  FillRect(W+(FirstColor.A / 2.55).Round-1,210,W+(FirstColor.A / 2.55).Round+1,220);
  //Палитра цветов
  GraphABC.Brush.Color := clSilver;
  FillRect(W,0,W+100,100);
  for i: integer := 0 to Length(Palitra,1)-1 do
  for j: integer := 0 to Length(Palitra,0)-1 do
  begin
    GraphABC.Brush.Color := Palitra[j,i];
    FillRect(W+(j*12.5).Round,0+(i*12.5).Round,W+((j+1)*12.5).Round,0+((i+1)*12.5).Round);
  end;
  //Палитра объектов
  GraphABC.Brush.Color := clSilver;
  FillRect(W,260,W+100,360);
  for i: integer := 0 to 7 do
  for j: integer := 0 to 7 do
  if (TileSet[j,i].Width > 0) and
     (TileSet[j,i].Height > 0) then
     TileSet[j,i].Draw(W+j*12,260+i*12,12,12);
  //Выбор инструмента
  GraphABC.Brush.Color := clSilver;
  FillRect(W,220,W+100,260);
  for i: integer := 0 to 2 do
  if Tool = i then ToolPics[i+3].Draw(W+i*33+2,222) else
                   ToolPics[i].Draw(W+i*33+2,222);
  //Выбранный объект
  if (Length(Buffer,0) > 1) and (Length(Buffer,1) > 1) then
  begin
    GraphABC.Brush.Color := clGray;
    FillRect(W,360,W+100,460);
    var PS: integer;
    if Length(Buffer,0) >= Length(Buffer,1) then PS := Round(100/Length(Buffer,0)) else
                                                 PS := Round(100/Length(Buffer,1));
    for i: integer := 0 to Length(Buffer,1)-1 do
    for j: integer := 0 to Length(Buffer,0)-1 do
    begin
      GraphABC.Brush.Color := Buffer[j,i];
      MyRect(j*PS+W,i*PS+360,PS,PS);
    end;
  end;
  //Позиция курсора
  TextRect(W,460,W+100,512,'X: '+IntToStr(1+MouseX div PixelSize)+newline+'Y: '+IntToStr(1+MouseY div PixelSize),clGray);
  System.Threading.Monitor.Exit(GraphABC.GraphABCControl);
end;
procedure DrawTile;
var
  i,j: integer;
begin
  ClearTile(clSilver);
  i := ESY; while (i < EDY) and (i*PixelSize < H) do begin
  j := ESX; while (j < EDX) and (j*PixelSize < W) do begin
    if (j-ESX > -1) and (j-ESX < TW) then
    if (i-ESY > -1) and (i-ESY < TH) then
    begin
      GraphABC.Brush.Color := Tile[j-ESX,i-ESY];
      if Tool = 2 then
      if (j >= VSX) and (j < VSX+VW) and (i >= VSY) and (i < VSY+VH) then
        GraphABC.Brush.Color := ARGB(Tile[j-ESX,i-ESY].A,Tile[j-ESX,i-ESY].R div 2+128,Tile[j-ESX,i-ESY].G div 2+64,Tile[j-ESX,i-ESY].B div 2+64);
      FillRect(Round(PixelSize * j),
               Round(PixelSize * i),
               Round(PixelSize * (j+1))-MP,
               Round(PixelSize * (i+1))-MP);
     end;
     j += 1;
    end;
    i += 1;
  end;
end;
procedure DrawBuffer;
var
  i,j: integer;
begin
  i := 0; while (i < VH) and (i*PixelSize < H) do begin
  j := 0; while (j < VW) and (j*PixelSize < W) do begin
    begin
      GraphABC.Brush.Color := Buffer[j,i];
      if Tool = 2 then
        GraphABC.Brush.Color := ARGB(Buffer[j,i].A,Buffer[j,i].R div 2+128,Buffer[j,i].G div 2+64,Buffer[j,i].B div 2+64);
      FillRect(Round(PixelSize * (j+VSX)),
               Round(PixelSize * (i+VSY)),
               Round(PixelSize * (j+1+VSX))-MP,
               Round(PixelSize * (i+1+VSY))-MP);
     end;
     j += 1;
    end;
    i += 1;
  end;
end;
procedure Show :=
if Not ShowMaket then
begin
  DrawTile(RawBmp,W+100);
  Bmp:= BytesToImage(RawBmp,W+100);
  GraphBufferGraphics.Clear(clGray);
  GraphBufferGraphics.DrawImage(Bmp,0,0);
end
else ToolsPanel;
procedure StartScreen := TextOut('Информация','H - справка \n Esc - очистить тайл \n Пробел - редактирование/просмотр \n Стрелки - перемещение картинки \n Мышь - редактирование \n -,+ - масштаб \n P - выбрать цвет \n ПКМ - закрасить пиксель \n ЛКМ - копировать цвет пикселя \n Колесико - поменять цвета местами \n R - залить поле случайными цветами \n A - сохранить выделенное \n S - сохранить тайл \n L - загрузить тайл \n G - вкл/выкл сетку \n N - новый тайл \n M - этот экран');
procedure _SetColor;
var
  DA1, DR1, DG1, DB1: integer;
  CA, CR, CG, CB: integer;
  Procedure Задать_цвет;
  Procedure Интерфейс;
  begin
    GraphABC.Brush.Color := clGray;
    FillRect(0,0,W,H);
    GraphABC.Brush.Color := RGB(100,100,100);
    FillRoundRect(10,10,W-10,30,5,5);
    GraphABC.Brush.Color := RGB(150,100,100);
    FillRoundRect(10,40,W-10,60,5,5);
    GraphABC.Brush.Color := RGB(100,150,100);
    FillRoundRect(10,70,W-10,90,5,5);
    GraphABC.Brush.Color := RGB(100,100,150);
    FillRoundRect(10,100,W-10,120,5,5);
    GraphABC.Brush.Color := RGB(200,200,200);
    FillRoundRect(10+Round((W-40)/255*CA),8,10+Round((W-40)/255*CA)+20,32,5,5);
    FillRoundRect(10+Round((W-40)/255*CR),38,10+Round((W-40)/255*CR)+20,62,5,5);
    FillRoundRect(10+Round((W-40)/255*CG),68,10+Round((W-40)/255*CG)+20,92,5,5);
    FillRoundRect(10+Round((W-40)/255*CB),98,10+Round((W-40)/255*CB)+20,122,5,5);
    GraphABC.Brush.Color := ARGB(175,150,150,150);
    TextOut(Round(W/2),10,IntToStr(CA));
    TextOut(Round(W/2),40,IntToStr(CR));
    TextOut(Round(W/2),70,IntToStr(CG));
    TextOut(Round(W/2),100,IntToStr(CB));
    
    GraphABC.Brush.Color := ARGB(CA,CR,CG,CB);
    FillRoundRect(10,130,W-10,H-60,5,5);
    
    GraphABC.Brush.Color := clGray;
    DrawTextCentered(10,H-50,W-10,H,'Нажмите Enter чтобы применить цвет'+newline+'BackSpace чтобы завершить настройку цвета');
    Redraw;
  end;
  Procedure Управление;
  begin
    if KeyPressed then if KeyCode = 13 then
    begin
    DA1 := CA;
    DR1 := CR;
    DG1 := CG;
    DB1 := CB;
    end;
    if MousePressed then
    begin
      case MouseY of
      10..30:
      begin
        CA := Round((MouseX-10)/((W-20)/255));
        if MouseX < 10 then CA := 0;
        if MouseX > W-10 then CA := 255;
      end;
      40..60:
      begin
        CR := Round((MouseX-10)/((W-20)/255));
        if MouseX < 10 then CR := 0;
        if MouseX > W-10 then CR := 255;
       end;
       70..90:
       begin
         CG := Round((MouseX-10)/((W-20)/255));
         if MouseX < 10 then CG := 0;
         if MouseX > W-10 then CG := 255;
       end;
       100..120:
       begin
         CB := Round((MouseX-10)/((W-20)/255));
         if MouseX < 10 then CB := 0;
         if MouseX > W-10 then CB := 255;
       end;
     end;
   end;
end;
begin
  while KeyCode <> 8 do
  begin
    Интерфейс;
    Управление;
  end;
end;
begin
  DA1 := FirstColor.A;
  DR1 := FirstColor.R;
  DG1 := FirstColor.G;
  DB1 := FirstColor.B;
  CA := DA1;
  CR := DR1;
  CG := DG1;
  CB := DB1;
  Задать_Цвет;
  FirstColor := ARGB(DA1,DR1,DG1,DB1);
  while KeyPressed do;
  HUE := RGBtoHSV(FirstColor.R,FirstColor.G,FirstColor.B).H;
  Sat := RGBtoHSV(FirstColor.R,FirstColor.G,FirstColor.B).S;
  Ve := RGBtoHSV(FirstColor.R,FirstColor.G,FirstColor.B).V;
end;
procedure Help := TextOut('Помощь','Программа PixelMaker v0.2.3 \n Разработчик DeadPixel vk.com/deadpixel_programmer \n Управление: \n Карандаш \n ЛКМ - закрасить пиксель \n ПКМ - пипетка \n Ролик - поменять первый и второй цвета местами \n Заливка \n ЛКМ - залить область одного цвета с позиции мыши \n ПКМ - пипетка \n Ролик - поменять первый и второй цвета местами \n Выделение \n ЛКМ в свободной области - вставить буфер \n ПКМ - без функции \n Ролик - поменять первый и второй цвета местами \n ЛКМ на выделении, тащить, отпустить - копировать выделение в новую область \n Область инструментов \n Цветовая палитра \n ЛКМ - задать цвет в нужном месте \n ПКМ - пипетка \n Ролик - загрузка и сохранение палитры \n Модель выбора цвета HUE \n ЛКМ/ПКМ - задать цвет (Квадрат - выбор яркости, полоса ниже - выбор тона, черно-белая полоса ниже - выбор прозрачности) \n Ролик - выбрать цвет точно по схеме ARGB (прозрачность красный зеленый синий) \n Выбор инструмента - карандаш, заливка или выделение \n Тайлсет \n ЛКМ - добавить тайл из буфера \n ПКМ - взять тайл из тайлсета в буфер \n Ролик - загрузка и сохранение тайлсета \n Миниатюра тайла в буфере \n Без взаимодействия \n Отображение координат мыши \n Вращение ролика мыши - масштаб \n Клавиатура (Обозначения букв на англ.) \n Пробел - редактирование/просмотр \n Стрелки - перемещение тайла \n Escape - очистить тайл \n N - новый тайл \n M - начальный экран \n S - сохранить тайл \n L - загрузить тайл \n G - вкл/выкл сетку \n Z - отменить действие \n \|/ (кнопка слева от Z) - повторить действие \n R - заполнить тайл случайными цветами');
procedure Fill(X1,Y1: integer; NewColor: Color);
var
  MainColor := Tile[X1,Y1];
  ToSee: array of point;
  TmSee: array of point;
begin
  if MainColor <> NewColor then
  begin
    SetLength(ToSee,1);
    ToSee[0].X := X1;
    ToSee[0].Y := Y1;
    while Length(ToSee) > 0 do
    begin
      Show;
      SetLength(TmSee,0);
      for i: integer := 0 to Length(ToSee)-1 do
      begin
        Tile[ToSee[i].X,ToSee[i].Y] := NewColor;
        
        if ToSee[i].X+1 < TW then
        if Tile[ToSee[i].X+1,ToSee[i].Y] = MainColor then
        begin SetLength(TmSee,Length(TmSee)+1);
              Tile[ToSee[i].X+1, ToSee[i].Y] := ARGB(254,198,1,128);
              TmSee[Length(TmSee)-1].X := ToSee[i].X+1;
              TmSee[Length(TmSee)-1].Y := ToSee[i].Y end;
              
        if ToSee[i].X-1 > -1 then
        if Tile[ToSee[i].X-1,ToSee[i].Y] = MainColor then
        begin SetLength(TmSee,Length(TmSee)+1);
              Tile[ToSee[i].X-1, ToSee[i].Y] := ARGB(254,198,1,128);
              TmSee[Length(TmSee)-1].X := ToSee[i].X-1;
              TmSee[Length(TmSee)-1].Y := ToSee[i].Y end;
              
        if ToSee[i].Y+1 < TH then
        if Tile[ToSee[i].X,ToSee[i].Y+1] = MainColor then
        begin SetLength(TmSee,Length(TmSee)+1);
              Tile[ToSee[i].X, ToSee[i].Y+1] := ARGB(254,198,1,128);
              TmSee[Length(TmSee)-1].Y := ToSee[i].Y+1;
              TmSee[Length(TmSee)-1].X := ToSee[i].X end;
              
        if ToSee[i].Y-1 > -1 then
        if Tile[ToSee[i].X,ToSee[i].Y-1] = MainColor then
        begin SetLength(TmSee,Length(TmSee)+1);
              Tile[ToSee[i].X, ToSee[i].Y-1] := ARGB(254,198,1,128);
              TmSee[Length(TmSee)-1].Y := ToSee[i].Y-1;
              TmSee[Length(TmSee)-1].X := ToSee[i].X end;
      end;
      SetLength(ToSee,Length(TmSee));
      for i: integer := 0 to Length(ToSee)-1 do
      begin
        ToSee[i].X := TmSee[i].X;
        ToSee[i].Y := TmSee[i].Y;
      end;
    end;
  end;
end;
procedure NewTile;
begin
  GraphABC.Brush.Color := ARGB(128,0,0,0);
  ClearWindow(clRandom);
  FillRoundRect((W+100) div 2-208,H div 2 - 16,(W+100) div 2 + 208, H div 2 + 16,10,10);
  DrawTextCentered(0,0,W+100,H,'Введите ширину тайла (4-512)');
  Redraw;
  TW := 0;
  while (TW < 4) or (TW > 512) do
  TW := ReadInteger;
  ClearWindow(clRandom);
  FillRoundRect((W+100) div 2-208,H div 2 - 16,(W+100) div 2 + 208, H div 2 + 16,10,10);
  DrawTextCentered(0,0,W+100,H,'Введите высоту тайла (4-512)');
  Redraw;
  TH := 0;
  while (TH < 4) or (TH > 512) do
  TH := ReadInteger;
  if TW > TH then
    PixelSize := W div TW
  else
    PixelSize := H div TH;
  if PixelSize = 0 then PixelSize := 1;
  ESX := W div PixelSize div 2 - TW div 2;
  ESY := H div PixelSize div 2 - TH div 2;
  ClearWindow(clGray);
  ShowMaket := true;
  Init;
  DrawTile;
  while KeyPressed do;
end;
function DelName(Str: string): string;
var
  LenN: integer;
begin
  while (LenN < Length(Str)) and
        (Str[Length(Str)-LenN-1] <> '\') do
        LenN += 1;
  SetLength(Str,Length(Str)-LenN);
  Result := Str;
end;
procedure IOPalitra;
begin
  Button('Load',W+10,10,80,25);
  Button('Save',W+10,45,80,25);
  Redraw;
  while MousePressed do;
  while not MousePressed do;
  if Button('Load',W+10,10,80,25) then
  begin
    //Запрос файла от пользователя
    var tmp := System.Windows.Forms.OpenFileDialog.Create;
    tmp.Filter := '*.png (картинки)|*.png';
    tmp.InitialDirectory := MainDir;
    tmp.ShowDialog;
    MainDir := DelName(tmp.FileName);
    if tmp.FileName <> '' then
    begin
      var ToLoad := Picture.Create(tmp.FileName);
      if (ToLoad.Width = 8) and (ToLoad.Height = 8) then
      begin
        for i: integer := 0 to 7 do
        for j: integer := 0 to 7 do
          Palitra[j,i] := ToLoad.GetPixel(j,i);
      end
      else
      begin
        Button('Error',W+10,10,80,25);
        Redraw;
        while not MousePressed do;
        while MousePressed do;
      end;
    end;
    while KeyPressed do;
    ClearTile(clGray);
    if ShowMaket then DrawTile else Show;
    Redraw;
  end;
  if Button('Save',W+10,45,80,25) then
  begin
    var ToSave := Picture.Create(8,8);
    for y: integer := 0 to 7 do
    for x: integer := 0 to 7 do
      ToSave.PutPixel(x,y,Palitra[x,y]);
    var tmp := System.Windows.Forms.SaveFileDialog.Create;
    tmp.Filter := '*.png (картинки)|*.png';
    tmp.InitialDirectory := MainDir;
    tmp.ShowDialog;
    MainDir := DelName(tmp.FileName);
    if tmp.FileName <> '' then
    begin
      ToSave.Save(tmp.FileName);
      ClearTile(clGray);
      DrawTile;
      Redraw;
    end;
    while KeyPressed do;
  end;
  while MousePressed do;
end;
procedure IOTileSet;
begin
  Button('Load',W+10,270,80,25);
  Button('Save',W+10,305,80,25);
  Redraw;
  while MousePressed do;
  while not MousePressed do;
  if Button('Load',W+10,270,80,25) then
  begin
    //Запрос файла от пользователя
    var tmp := System.Windows.Forms.OpenFileDialog.Create;
    tmp.Filter := '*.png (картинки)|*.png';
    tmp.InitialDirectory := MainDir;
    tmp.ShowDialog;
    MainDir := DelName(tmp.FileName);
    if tmp.FileName <> '' then
    begin
      var ToLoad := Picture.Create(tmp.FileName);
      if (ToLoad.Width mod 8 = 0) and (ToLoad.Height mod 8 = 0) then
      begin
        var mxW,mxH,x,y: integer;
        mxW := ToLoad.Width div 8;
        mxH := ToLoad.Height div 8;
        
        for i: integer := 0 to 7 do
        for j: integer := 0 to 7 do
        begin
          x := j*mxW;
          while ToLoad.GetPixel(x,i*mxH) <> RGB(1,2,3) do x += 1;
          y := i*mxH;
          while ToLoad.GetPixel(j*mxW,y) <> RGB(1,2,3) do y += 1;
          x -= j*mxW;
          y -= i*mxH;
          if (mxW > 0) and (mxH > 0) then
          begin
            TileSet[j,i] := Picture.Create(x,y);
            for k: integer := 0 to y-1 do
            for z: integer := 0 to x-1 do
              TileSet[j,i].PutPixel(z,k,ToLoad.GetPixel(j*mxW+z,i*mxH+k));
          end
          else
            TileSet[j,i] := Picture.Create(1,1);
          ToLoad.FillRect(j*mxW,i*mxH,(j+1)*mxW,(i+1)*mxH);
        end;
      end;
    end;
    while KeyPressed do;
  end;
  if Button('Save',W+10,305,80,25) then
  begin
    var mxW,mxH: integer;
    for i: integer := 0 to 7 do
    for j: integer := 0 to 7 do
    begin
      if TileSet[j,i].Width > mxW then mxW := TileSet[j,i].Width;
      if TileSet[j,i].Height > mxH then mxH := TileSet[j,i].Height;
    end;
    mxW += 1;
    mxH += 1;
    var ToSave := Picture.Create(8*mxW,8*mxH);
    ToSave.Clear(RGB(1,2,3));
    for y: integer := 0 to 7 do
    for x: integer := 0 to 7 do
      for i: integer := 0 to TileSet[x,y].Height-1 do
      for j: integer := 0 to TileSet[x,y].Width-1 do
        ToSave.PutPixel(x*mxW+j,y*mxH+i,TileSet[x,y].GetPixel(j,i));
    var tmp := System.Windows.Forms.SaveFileDialog.Create;
    tmp.Filter := '*.png (картинки)|*.png';
    tmp.InitialDirectory := MainDir;
    tmp.ShowDialog;
    MainDir := DelName(tmp.FileName);
    if tmp.FileName <> '' then ToSave.Save(tmp.FileName);
    while KeyPressed do;
  end;
  while MousePressed do;
end;
procedure MouseWheel(Sender:object; e:System.Windows.Forms.MouseEventArgs);
begin
  var delta := Sign(e.Delta);
  case delta of
  1: if not ShowMaket then
         begin if ShowScale < 64 then ShowScale += 1 end
       else
         if EDX > 8 then
         begin
         ESX-=1;
         ESY-=1;
         EDX -=2;
         EDY -=2;
         PixelSize := W div EDX;end;
  -1: if not ShowMaket then
         begin if ShowScale > 1 then ShowScale -= 1 end
       else
         begin
         ESX+=1;
         ESY+=1;
         EDX +=2;
         EDY +=2;
         PixelSize := W div EDX;
         end;
  end;
  System.Threading.Monitor.Enter(GraphABC.GraphABCControl);
  DrawTile;
  Show;
  System.Threading.Monitor.Exit(GraphABC.GraphABCControl);
end;
procedure Control;
var
  MX,MY: integer;
  Pause: boolean;
  notDraw: boolean;forUndo: color;
begin
  if Bmp <> nil then Bmp.Dispose;
  Show;
  while (not MousePressed) and (not KeyPressed) do
  if ShowMaket then begin System.Threading.Monitor.Enter(GraphABC.GraphABCControl);
                          ToolsPanel;Redraw;
                          System.Threading.Monitor.Exit(GraphABC.GraphABCControl);end;
  notDraw := true;
  if MousePressed then
  begin
    MX := Round((MouseX-PixelSize/2)/PixelSize)-ESX;
    MY := Round((MouseY-PixelSize/2)/PixelSize)-ESY;
    if MX+ESX < EDX then
    if MX >= 0 then
    if MY+ESY < EDY then
    if MY >= 0 then
    if ShowMaket then
        if MouseCode = 0 then begin Swap(FirstColor,TwoColor);Pause := true;
                                    if RGBtoHSV(FirstColor.R,FirstColor.G,FirstColor.B).H <> 0 then
                                    HUE := RGBtoHSV(FirstColor.R,FirstColor.G,FirstColor.B).H;
                                    Sat := RGBtoHSV(FirstColor.R,FirstColor.G,FirstColor.B).S;
                                    Ve := RGBtoHSV(FirstColor.R,FirstColor.G,FirstColor.B).V;end
      else
        if MouseCode = 2 then begin FirstColor := Tile[MX,MY];
                                    if RGBtoHSV(FirstColor.R,FirstColor.G,FirstColor.B).H <> 0 then
                                    HUE := RGBtoHSV(FirstColor.R,FirstColor.G,FirstColor.B).H;
                                    Sat := RGBtoHSV(FirstColor.R,FirstColor.G,FirstColor.B).S;
                                    Ve := RGBtoHSV(FirstColor.R,FirstColor.G,FirstColor.B).V;end
      else
      begin
        case Tool of
        0: begin
             while MousePressed do
             begin
               MX := Round((MouseX-PixelSize/2)/PixelSize)-ESX;
               MY := Round((MouseY-PixelSize/2)/PixelSize)-ESY;
               if (MX >= 0) and (MY >= 0) and (MX+ESX < EDX) and (MY+ESY < EDY) and
                                              (MX < Length(Tile,0)) and (MY < Length(Tile,1)) then
               begin
                 GraphABC.Brush.Color := FirstColor;
                 FillRect(Round(PixelSize * (ESX+MX)),
                          Round(PixelSize * (ESY+MY)),
                          Round(PixelSize * (ESX+(MX+1)))-MP,
                          Round(PixelSize * (ESY+(MY+1)))-MP);
                 if FirstColor.A > 0 then Tile[MX,MY] := GetPixel(Round(PixelSize * (ESX+MX))+1,Round(PixelSize * (ESY+MY))+1) else
                 Tile[MX,MY] := FirstColor;
                 Redraw;
               end;
             end;
             notDraw := false;
           end;
        1: begin Fill(MX,MY,FirstColor);if ShowMaket then DrawTile;Redraw end;
        2: begin
             if (MX < VSX) or (MY < VSY) or (MX+ESX > VSX+VW) or (MY+ESY > VSY+VH) then
             begin
               VSX := MX;
               VSY := MY;
               while MousePressed do;
               if (Abs(MX-Round((MouseX-PixelSize/2)/PixelSize)-ESX) > 1) and
                  (Abs(MY-Round((MouseY-PixelSize/2)/PixelSize)-ESY) > 1) then
               begin
                 VW := Round((MouseX-PixelSize/2)/PixelSize)-ESX - MX+1;
                 VH := Round((MouseY-PixelSize/2)/PixelSize)-ESY - MY+1;
                 if VW < 0 then begin VSX += VW-1;VW := -VW+2 end;
                 if VH < 0 then begin VSY += VH-1;VH := -VH+2 end;
                 if VSX < 0 then VSX := 0;
                 if VSY < 0 then VSY := 0;
                 if VSX+VW > TW then VW := ESX+EDX-VSX;
                 if VSY+VH > TH then VH := ESY+EDY-VSY;
                 if (VW > 1) and (VH > 1) then
                 begin
                   SetLength(Buffer,VW,VH);
                   for i: integer := 0 to VH-1 do
                   for j: integer := 0 to VW-1 do
                     Buffer[j,i] := Tile[j+VSX,i+VSY];
                   DrawTile;
                 end;
               end
               else
               begin
                 //Вставить буфер
                 for i: integer := 0 to VH-1 do
                 for j: integer := 0 to VW-1 do
                 if (j+MX > -1)  and (i+MY > -1) and (j+MX < TW) and (i+MY < TH) then
                 if Buffer[j,i].A > 0 then
                   Tile[j+MX,i+MY] := Buffer[j,i];
                 DrawTile;
               end;
               Pause := true;
             end
             else
             begin
               var MsX := MX-VSX;
               var MsY := MY-VSY;
               while MousePressed do
               begin
                 VSX := Round((MouseX-PixelSize/2)/PixelSize)-ESX-MsX;
                 VSY := Round((MouseY-PixelSize/2)/PixelSize)-ESY-MsY;
                 ClearTile(clGray);
                 DrawTile;
                 DrawBuffer;
                 Redraw;
               end;
               //Вставить буфер
               for i: integer := 0 to VH-1 do
               for j: integer := 0 to VW-1 do
               if (j+VSX > -1)  and (i+VSY > -1) and (j+VSX < TW) and (i+VSY < TH) then
               if Buffer[j,i].A > 0 then
                 Tile[j+VSX,i+VSY] := Buffer[j,i];
             end;
           end;
        end;
      end;
      if MouseX > W then
      if MouseX < W+100 then
      begin
        if MouseY > 0 then
        if MouseY < 100 then
        while MousePressed do
        if MouseY > 0 then
        if MouseY < 100 then
        begin
          if MouseCode = 2 then if MouseX > W then
                                 if MouseX < W+100 then
                                 begin
                                   FirstColor := GetPixel(MouseX,MouseY);
                                   if RGBtoHSV(FirstColor.R,FirstColor.G,FirstColor.B).H <> 0 then
                                   HUE := RGBtoHSV(FirstColor.R,FirstColor.G,FirstColor.B).H;
                                   Sat := RGBtoHSV(FirstColor.R,FirstColor.G,FirstColor.B).S;
                                   Ve := RGBtoHSV(FirstColor.R,FirstColor.G,FirstColor.B).V;
                                 end;
          if MouseCode = 1 then if MouseX > W then
                                 if MouseX < W+100 then
                                 Palitra[((MouseX-W-6.25)/12.5).Round,((MouseY-6.25)/12.5).Round] := FirstColor;
          if MouseCode = 0 then IOPalitra;
          ToolsPanel;
          Redraw;
        end;
        if MouseY > 99 then
        if MouseY < 200 then
        while MousePressed do
        begin
          if MouseCode <> 0 then
          begin
            Sat := MouseX-W;
            Ve := MouseY-100;
            if Sat < 0 then Sat := 0;
            if Sat > 100 then Sat := 100;
            if Ve < 0 then Ve := 0;
            if Ve > 100 then Ve := 100;
            var A_ := FirstColor.A;
            FirstColor := HSVtoRGB(HUE,Sat,Ve);
            FirstColor := ARGB(A_,FirstColor.R,FirstColor.G,FirstColor.B);
          end
          else
          begin
            _SetColor;
            ClearWindow(clGray);
            DrawTile;
          end;
          ToolsPanel;
          Redraw;
        end;
        if MouseY > 199 then
        if MouseY < 210 then
        while MousePressed do
        begin
          if MouseCode <> 0 then
          begin
            HUE := ((MouseX - W) * 3.6).Round;
            if MouseX > W+100 then HUE := 359;
            if MouseX < W then HUE := 0;
            var A_ := FirstColor.A;
            FirstColor := HSVtoRGB(HUE,Sat,Ve);
            FirstColor := ARGB(A_,FirstColor.R,FirstColor.G,FirstColor.B);
          end
          else
          begin
            _SetColor;
            ClearWindow(clGray);
            DrawTile;
          end;
          ToolsPanel;
          Redraw;
        end;
        if MouseY > 209 then
        if MouseY < 220 then
        while MousePressed do
        begin
          if MouseCode <> 0 then
          begin
            var MsX := ((MouseX-W)*2.55).Round;
            if MouseX < W then MsX := 0;
            if MouseX > W+100 then MsX := 255;
            FirstColor := ARGB(MsX,FirstColor.R,FirstColor.G,FirstColor.B);
          end
          else
          begin
            _SetColor;
            ClearWindow(clGray);
            DrawTile;
          end;
          ToolsPanel;
          Redraw;
        end;
        if MouseY > 220 then
        if MouseY < 248 then
        begin
          if (MouseX-W) div 33 < 3 then
            Tool := (MouseX-W) div 33 else Tool := 2;
          DrawTile;
        end;
        if MouseY > 260 then
        if MouseY < 356 then
        if MouseX < W+96 then
        begin
          if MouseCode = 1 then
          if (Length(Buffer,0) > 1) and (Length(Buffer,1) > 1) then
          begin
            TileSet[(MouseX-W) div 12,(MouseY-260) div 12] := Picture.Create(Length(Buffer,0),Length(Buffer,1));
            for i: integer := 0 to Length(Buffer,1)-1 do
            for j: integer := 0 to Length(Buffer,0)-1 do
              TileSet[(MouseX-W) div 12,(MouseY-260) div 12].SetPixel(j,i,Buffer[j,i]);
            Pause := true;
          end;
          if MouseCode = 2 then
          if (TileSet[(MouseX-W) div 12,(MouseY-260) div 12].Width > 1) and
             (TileSet[(MouseX-W) div 12,(MouseY-260) div 12].Height > 1) then
          begin
            SetLength(Buffer,TileSet[(MouseX-W) div 12,(MouseY-260) div 12].Width,TileSet[(MouseX-W) div 12,(MouseY-260) div 12].Height);
            for i: integer := 0 to Length(Buffer,1)-1 do
            for j: integer := 0 to Length(Buffer,0)-1 do
              Buffer[j,i] := TileSet[(MouseX-W) div 12,(MouseY-260) div 12].GetPixel(j,i);
            VW := Length(Buffer,0);
            VH := Length(Buffer,1);
          end;
          if MouseCode = 0 then IOTileSet;
          ToolsPanel;
          Redraw;
        end;
      end;
      if Pause then while MousePressed do;
      Pause := false;
    end;
    if KeyPressed then
    begin
      case KeyCode of
        VK_R:
        begin
          for i: integer := 0 to TH-1 do
          for j: integer := 0 to TW-1 do
            if Random(0,3) = 0 then Tile[j,i] := RGB(128+Random(64),128+Random(64),128+Random(64))
            else Tile[j,i] := RGB(64+Random(128),64+Random(128),64+Random(128));
        end;
        VK_A:
        if (VW > 0) and (VH > 0) then
        begin
          var ToSave := Picture.Create(VW,VH);
          for y: integer := VSY to VSY+VH-1 do
          for x: integer := VSX to VSX+VW-1 do
             ToSave.PutPixel(x-VSX,y-VSY,Tile[x,y]);
          var tmp := System.Windows.Forms.SaveFileDialog.Create;
          tmp.Filter := '*.png (картинки)|*.png';
          tmp.InitialDirectory := MainDir;
          tmp.ShowDialog;
          MainDir := DelName(tmp.FileName);
          if tmp.FileName <> '' then
            ToSave.Save(tmp.FileName);
          while KeyPressed do;        
        end;
        VK_SPACE:
        begin
          if ShowMaket then
            ShowMaket := false
          else
            ShowMaket := true;
          Pause := true;
        end;
        VK_RIGHT: ESX -= 2;
        VK_LEFT: ESX += 2;
        VK_DOWN: ESY -= 2;
        VK_UP: ESY += 2;
        VK_ESCAPE:
        begin
          for i: integer := 0 to TH-1 do
          for j: integer := 0 to TW-1 do
            Tile[j,i] := clWhite;
        end;
        VK_N: begin NewTile;Pause := true; end;
        VK_M: StartScreen;
        VK_H: Help;
        VK_S:
        begin
          var ToSave := Picture.Create(TW,TH);
          for y: integer := 0 to TH-1 do
          for x: integer := 0 to TW-1 do
            ToSave.PutPixel(x,y,Tile[x,y]);
          var tmp := System.Windows.Forms.SaveFileDialog.Create;
          tmp.Filter := '*.png (картинки)|*.png';
          tmp.InitialDirectory := MainDir;
          tmp.ShowDialog;
          MainDir := DelName(tmp.FileName);
          if tmp.FileName <> '' then ToSave.Save(tmp.FileName);
          Pause := true;
        end;
        VK_L:
        begin
          //Запрос файла от пользователя
          var tmp := System.Windows.Forms.OpenFileDialog.Create;
          tmp.Filter := '*.png (картинки)|*.png';
          tmp.InitialDirectory := MainDir;
          tmp.ShowDialog;
          MainDir := DelName(tmp.FileName);
          if tmp.FileName <> '' then
          begin
            var ToLoad := Picture.Create(tmp.FileName);
            TW := ToLoad.Width;
            TH := ToLoad.Height;
            SetLength(Tile,TW,TH);
            SetLength(Buffer,TW,TH);
            for i: integer := 0 to TH-1 do
            for j: integer := 0 to TW-1 do
              Tile[j,i] := ToLoad.GetPixel(j,i);
              
            if TW > TH then
              PixelSize := W div TW
            else
              PixelSize := H div TH;
            if PixelSize = 0 then PixelSize := 1;
            if PixelSize < 1 then PixelSize := 1;
            ESX := W div PixelSize div 2 - TW div 2;
            ESY := H div PixelSize div 2 - TH div 2;
            EDX := (TW-ESX)-((TW-ESX)-(W div PixelSize));
            EDY := (TH-ESY)-((TH-ESY)-(H div PixelSize));
          end;
          if ShowMaket then DrawTile;Show;Redraw;
          Pause := true;
        end;
        VK_G: begin if MP = 1 then MP := 0 else MP := 1;Pause := true; end;
      end; 
      if Pause then while KeyPressed do;
      Pause := false;
      if notDraw then if ShowMaket then DrawTile else Show;Redraw;
    end;
end;
procedure FInit;
begin
  Window.Title := 'Tile Maker';
  Window.SetSize(612,512); //Выделяем пиксели под панель инструментов и информации (512:512)->(612,512)
  CenterWindow;
  Window.IsFixedSize := true;
  if not System.IO.Directory.Exists('Картинки\') then System.IO.Directory.CreateDirectory('Картинки\');
  W := 512;
  H := 512;
  GraphABC.Font.Color := ARGB(192,192,192,192);
  GraphABC.Font.Size := 16;
  OnKeyDown := KeyDown;
  OnKeyUp := KeyUp;
  OnMouseDown := MouseDown;
  OnMouseMove := MouseMove;
  OnMouseUp := MouseUp;
  GraphABC.GraphABCControl.MouseWheel += MouseWheel;
  LockDrawing;
  var Config := ReadAllLines('Config.txt');
  if Config[1] = 'да' then StartScreen;
  if Config[3] = 'да' then
  begin
    TW := StrToInt(Config[5]);
    TH := StrToInt(Config[7]);
    Init;
  end
  else NewTile;
  Init;
  for i: integer := 0 to Length(Palitra,1)-1 do
  for j: integer := 0 to Length(Palitra,0)-1 do
    Palitra[j,i] := RGB(Random(0,255),Random(0,255),Random(0,255));
  DrawHUE(RawFHUE,100);
  FHUE := BytesToImage(RawFHUE,100);
  DrawA(RawA,100);
  BA := BytesToImage(RawA,100);
  SetLength(ToolPics,6);
  ToolPics[0] := Picture.Create('_Pen.png');
  ToolPics[1] := Picture.Create('Fill.png');
  ToolPics[2] := Picture.Create('Vd.png');
  ToolPics[3] := Picture.Create('sPen.png');
  ToolPics[4] := Picture.Create('sFill.png');
  ToolPics[5] := Picture.Create('sVD.png');
  SetLength(TileSet,8,8);
  for i: integer := 0 to 7 do
  for j: integer := 0 to 7 do
    TileSet[j,i] := Picture.Create(1,1);//Чтобы не было ошибок при обращении к несозданному тайлу
  
  var ToLoad := Picture.Create('Palitra.png');
  for i: integer := 0 to 7 do
  for j: integer := 0 to 7 do
    Palitra[j,i] := ToLoad.GetPixel(j,i);
  if ShowMaket then DrawTile else Show;Redraw;
end;
begin
  FInit;
  while true do Control;
end.