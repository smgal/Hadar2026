Unit MystEnd;
{$O+,F+}
INTERFACE

Uses
   Crt, Graph, AdLib, UHanX, MystSub;
Const
   Back_Ground_Color = DarkGray;
   Fade_Top_Color = Cyan;
   Fade_Bottom_Color = Green;
   Main_Scroll_Color = LightCyan;
   Str_X_Pos = 71;
   Str_Y_Pos = 370;
   Max_Line = 8;
   Word_Y_Size = 16;
   Title_Str_Total = 29;
   Title_Str : array[1..Title_Str_Total] of string =
        (' 새로운 로드안이 된 당신에게.',
         '',
         ' 역시 당신은 나의 기대를 저버리지 않았소. 나 알비레오는 그저 로',
         '어세계의 역사에 대해  방관자적인 입장일뿐이었지만  비뚤어져가는',
         '로어세계의 미래를 그냥 보고만 있을 수는 없어서  당신을 선택하게',
         '되었고 당신을 이런 모험에 말려 들게 했던 것이오.  이제 위선자는',
         '사라졌고  로드안의 칭호도 당신에게 돌아갔소.  하지만 당신에게는',
         '아직 2가지의 과제가 더 남아있소.  첫째는 네크로만서가 된 카노푸',
         '스가 이땅에 내려올때 벌어지게 되고  둘째는 멸망당한 네종족의 원',
         '혼이 부활할 때 발생하게 될거요.  이 일들은 약 100년 후에 발생할',
         '것이오. 하지만 당신이라면 충분히 이겨낼 수 있을거라 믿소.',
         '',
         ' 나는  이제 이 세계를 떠날 때가 되었소.  아직도 내가 가보아야할',
         '차원이 수없이 많이있기 때문이오.  로어 세계가 있는 이곳도  그저',
         '내가 스쳐갔던 수 많은 차원들 중의 하나로  기억될지도 모르겠지만',
         '쉽게 잊어 버리기에는 너무 아까운 기억이 많이있소. 그중의 하나는',
         '당신의 존재 때문일거라오.  이제 나는 이곳 역사에 더 이상 신경을',
         '쓰지 않으려고 하오. 앞으로 다시 올 계획도 아직은 없소.  그저 영',
         '원의 차원으로 나의 여행을 계속 할 뿐이라오.',
         '',
         '                                      타임워커 알비레오로 부터.',
         '','','','','','','','');



 Procedure End_Demo(no : byte);


IMPLEMENTATION

Procedure ThunderEffect;
begin
   SetPalette(6,6);
   RGB(6,40,20,0);
   repeat
      if random(1000) = 0 then
      if random(100) = 0 then begin
         RGB(6,10,20,63);
         delay(random(100)+20);
         RGB(6,40,20,0);
      end;
   until keypressed;
   c := readkey;
end;

Procedure All_Fade_Out(plane : byte); assembler;
const
   dest_seg : word = $A000;
   dest_off : word = 0;
asm
   push es

   mov ax, dest_seg
   mov es, ax
   mov di, dest_off
   mov dx, $3C4
   mov al, 2
   mov ah, plane
   out dx, ax
   mov ax, $000
   mov cx, 40 * 480
   rep stosw

   pop es
end;

procedure Scroll_Sub(X_First,X_Length : word; Y_Start,Y_End : integer);
var
   i,j,k : word;
begin
   i := Y_End - Y_Start + 1;
   k := 80 * Y_Start + X_First;
   j := 80 - X_Length;
   asm
      push ds
      push si
      push di

      mov dx, $3CE
      mov al, 5
      mov ah, 1
      out dx, ax
      mov dx, $3C4
      mov ax, $0F02
      out dx, ax

      mov ax, $0a000
      mov es, ax
      mov ds, ax
      mov si, k
      mov di, k
      sub di, 80
      mov cx, i

@JUMP1:
      push cx
      mov cx, X_Length;
      rep movsb
      add si,j;
      add di,j;
      pop cx
      loop @JUMP1;

      pop di
      pop si
      pop ds
   end;
end;

Procedure Print(x,y,str_number : integer);
begin
   if str_number in [1..Title_Str_Total] then
      OutHPrintXY(x,y,Title_Str[str_number],FALSE);
end;

Procedure End_Demo_Sub1;
begin
   for i := 0 to 3 do begin
      All_Fade_Out(1 shl i);
      delay(500);
   end;
end;

Procedure End_Demo_Sub2;
var
   add : integer;
begin
   End_Demo_Sub1;
   j := 0;
   SetPalette(Back_Ground_Color,Back_Ground_Color);
   RGB(Back_Ground_Color,0,0,0);
   SetPalette(Main_Scroll_Color,Main_Scroll_Color);
   RGB(Main_Scroll_Color,63,0,0);
   repeat
      inc(j);
      RGB(Fade_Bottom_Color,0,0,0);
      RGB(Fade_Top_Color,63,0,0);
      for add := 1 to Word_Y_Size do begin
         Scroll_Sub(Str_X_Pos div 8,64,Str_Y_Pos - Word_Y_Size*(Max_Line+1),Str_Y_Pos+20);
         if add = 1 then begin
            SetColor(Fade_Bottom_Color);
            Print(Str_X_Pos,Str_Y_Pos-add,j);
            SetColor(Fade_Top_Color);
            Print(Str_X_Pos,Str_Y_Pos-Word_Y_Size*(Max_Line+1)+(Word_Y_Size-add),j-Max_Line);
         end;
         RGB(Fade_Bottom_Color,round(add*3.9),0,0);
         RGB(Fade_Top_Color,64-round(add*3.9),0,0);
         if KeyPressed then begin
            add := Word_Y_Size;
            j := Title_Str_Total;
         end
         else delay(150);
      end;
      SetColor(Main_Scroll_Color);
      Print(Str_X_Pos,Str_Y_Pos-add,j);
      SetColor(Back_Ground_Color);
      Print(Str_X_Pos,Str_Y_Pos-Word_Y_Size*(Max_Line+1)+(Word_Y_Size-add),j-Max_Line);
   until j >= Title_Str_Total;
end;

Procedure End_Demo_Sub3;
var
   x_pos, y_pos : integer;
begin
   End_Demo_Sub1;
   x_pos := 40;
   y_pos := 60;
   setcolor(14);
   cHPrint(x_pos,y_pos,' 나는 로드안에게 마지막 일격을 가하려 검을 쳐 들었다. 하지만 쉽게'); y_pos := y_pos + 20;
   cHPrint(x_pos,y_pos,'내리칠 수 있을것 같았지만  마음 속에서는 심한 동요가 일고 있었다.'); y_pos := y_pos + 20;
   cHPrint(x_pos,y_pos,'로드안 그는  나에게 돌이킬 수 없는 실수를 저지르게 했지만  이제는'); y_pos := y_pos + 20;
   cHPrint(x_pos,y_pos,'다 끝난 일이었다.  네크로만서나 다크 메이지도 이제는 다 지나간 기'); y_pos := y_pos + 20;
   cHPrint(x_pos,y_pos,'억 속으로 사라져 가고 있으니까 ... ...'); y_pos := y_pos + 20;
   cHPrint(x_pos,y_pos,' 나는 검을 거두고는 뒤돌아섰다. 로드안은 너무나 인간을 사랑했기에'); y_pos := y_pos + 20;
   cHPrint(x_pos,y_pos,'인간을 이롭게 하고자한 죄 밖에는 없다.  나 역시 보잘것없는 한명의'); y_pos := y_pos + 20;
   cHPrint(x_pos,y_pos,'인간로써 과연 그를 심판할 자격이 있을까?'); y_pos := y_pos + 20;
   cHPrint(x_pos,y_pos,''); y_pos := y_pos + 20;
   cHPrint(x_pos,y_pos,''); y_pos := y_pos + 20;
   cHPrint(x_pos,y_pos,' 나는 로어성을 뒤로한채 혼자만의 여행을 떠나고있다.'); y_pos := y_pos + 20;
   cHPrint(x_pos,y_pos,' 여태껏 잊고 지냈던 자신만의 시간을 가지고 싶었기 때문이다.  내가'); y_pos := y_pos + 20;
   cHPrint(x_pos,y_pos,'어릴적에 하나의 꿈이 있었다.  그것은 저 하늘의 새처럼 자유롭게 먼'); y_pos := y_pos + 20;
   cHPrint(x_pos,y_pos,'곳으로 여행을 떠나는 것이었다.'); y_pos := y_pos + 20;
   cHPrint(x_pos,y_pos,' 내 이름이 저들에게 잊혀질때 쯤이면  나는 여지껏 누구도 간적이 없'); y_pos := y_pos + 20;
   cHPrint(x_pos,y_pos,'는 세상의 끝에 도달해 있을것이다. 그리고 거기서 나는 새로운 나 자'); y_pos := y_pos + 20;
   cHPrint(x_pos,y_pos,'신을 찾고 또 다른 삶을 살아가는 나를 발견할 것이다.'); y_pos := y_pos + 20;
   ThunderEffect;
end;

Procedure End_Message;
var
   i, j : integer;
begin

   if AdLibOn then PlayOff;
   UnSound;
   asm
      mov ah,0
      mov al,3
      int $10
      mov ah,1
      mov ch,$20
      int $10
   end;
   dispose(font); dispose(chara);
   dispose(map);
   TextColor(7);
   TextBackGround(0);
   ClrScr;
   TextColor(7);
   Writeln(#13);
   RGB(7,0,0,0);
   SetPalette(15,15);
   RGB(15,0,0,0);
   TextColor(15);
   Writeln(#13);
   Writeln('                             << The End >>');
   Writeln('            " Into the MYSTIC  vol. #3 " is made by OㅏOㅕㄱㅣ');
   Writeln('                                                    ㄴ  O  |');
   TextColor(7);
   Writeln('                       You must be a genius !!!');
   for i := 1 to 63 do begin
      RGB(7,i,i,i);
      SetPalette(15,15);
      RGB(15,i,i,i);
      delay(10);
   end;
   delay(500);
   for i := 62 downto 42 do begin
      RGB(7,i,i,i);
      delay(15);
   end;
   asm
      mov ah,1
      mov ch,$13
      mov cl,$14
      int $10
   end;
   Halt;
end;

Procedure End_Demo(no : byte);
begin
   case no of
      1 : End_Demo_Sub1;
      2 : End_Demo_Sub2;
      3 : End_Demo_Sub3;
   end;
   End_Message;
end;
{
begin
   i := DETECT;
   initgraph(i,j,'');
   end_demo(3);
   closegraph;}
end.