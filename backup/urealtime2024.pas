unit urealtime2024;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  OpenGLContext, DateUtils, Math, gl, glu, LCLIntf;

type

  TBall = class
    private
        x,y:real; //coords
        r:real;   //radius
        v:real;   //velocity
        vMax:real;
        vx, vy:real; //velocity projections
        kx, ky:real; //axis coeficients
        rfw, rfh:integer; //current field params
        rdt:real; //dt
        trace:array of TPoint;
        angle:integer; //flight angle
        colour:TColor;  //ball colour
        hadCollision:boolean;
        procedure AddTracePoint(px:real; py:real);
    public
        property br:real read r write r;
        property bx:real read x write x;
        property by:real read y write y;
        property bv:real read v write v;
        property bkx:real read kx write kx;
        property bky:real read ky write ky;
        property bColour:TColor read colour write colour;

        procedure randomizeBall;
        procedure MoveBall; virtual;
        procedure UpdateFieldState(fWidth:integer;fHeight:integer);
        procedure UpdateDeltaTime(cdt:real);
        procedure SetVelocity(newV:real);
        function traceLength:integer;
        function getTraceEl(id:integer):TPoint;
        procedure drawMeself(var bMap:TBitmap); virtual;
        constructor Create(dw:integer; dh:integer);

  end;

  TSpeedBall = class(TBall)
    public
       procedure MoveBall; override;
       procedure drawMeself(var bMap:TBitmap); override;
       constructor Create(dw:integer; dh:integer);
  end;

  TRotateBall = class(TBall)
    public
       procedure MoveBall; override;
       procedure drawMeself(var bMap:TBitmap); override;
       constructor Create(dw:integer; dh:integer);
  end;

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    btnSwapRenders: TButton;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    OpenGLControl1: TOpenGLControl;
    Panel1: TPanel;
    procedure btnSwapRendersClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;

  work:boolean;//execute main loop
  fw,fh:integer; //field size
  dt:real;  //time

  CTime:TDateTime;
  LTime:TDateTime;

  timer:real=0;

  balls:Array of TBall;

  useGLRender:boolean;

implementation

{$R *.lfm}

{Ball}

procedure TBall.randomizeBall;
begin
  r:=random(20)+10;
  v:=random(100)+20;
  x:=random(round(rfw-r*2))+round(r);
  y:=random(round(rfh-r*2))+round(r);
  colour:=RGBToColor(random(256),random(256),random(256));
end;

procedure TBall.AddTracePoint(px:real; py:real);
begin
  SetLength(trace,Length(trace)+1);
  trace[High(trace)].x:=round(px);
  trace[High(trace)].y:=round(py);
end;

procedure TBall.MoveBall;
begin

  hadCollision:=false;

  vx:=v*Sin(DegToRad(angle));
  vy:=v*Cos(DegToRad(angle));

  x:=x + kx*vx*rdt;
  y:=y + ky*vy*rdt;

  if ((x<r) or (x>(rfw-r))) then
  begin
    kx:=kx*-1;
    if (x<r) then x:=r;
    if (x>(rfw-r)) then x:=rfw-r;
    AddTracePoint(x,y);
    hadCollision:=true;
  end;

  if ((y<r) or (y>(rfh-r))) then
  begin
    ky:=ky*-1;
    if (y<r) then y:=r;
    if (y>(rfh-r)) then y:=rfh-r;
    AddTracePoint(x,y);
    hadCollision:=true;
  end;
end;

procedure TBall.UpdateFieldState(fWidth:integer;fHeight:integer);
begin
  rfw:=fWidth;
  rfh:=fHeight;
end;

procedure TBall.UpdateDeltaTime(cdt:real);
begin
  rdt:=cdt;
end;

procedure TBall.SetVelocity(newV:real);
begin
  v:=newV;
  if (v>vMax) then v:=vMax;
end;

function TBall.traceLength:integer;
begin
  result:=Length(trace);
end;

function TBall.getTraceEl(id:integer):TPoint;
var tp:TPoint;
begin
  if (id<=traceLength-1) then
  begin
    tp.x:=trace[id].x;
    tp.y:=trace[id].y;
  end
  else
  begin
    tp.x:=0; tp.y:=0;
  end;
  result:=tp;
end;

procedure TBall.drawMeself(var bMap:TBitmap);
var xi,yi,ri,i:integer;
begin
  if (not useGLRender) then
  begin
    xi:=round(x);
    yi:=round(y);
    ri:=round(r);
    with bMap.Canvas do
    begin
      Pen.Color:=clBlack;
      Brush.Color:=colour;
      Ellipse(xi-ri,yi-ri,xi+ri,yi+ri);
    end;
  end
  else
  begin
    glBegin(GL_TRIANGLE_FAN);

    glColor3f(GetRValue(ColorToRGB(colour))/256,GetGValue(ColorToRGB(colour))/256,GetBValue(ColorToRGB(colour))/256);

    glVertex2f(x,y);

    for i:=0 to 16 do
    begin
      glVertex2f(x+r*sin((i*(360/16)*Pi)/180),y+r*cos((i*(360/16)*PI)/180));
    end;

    glEnd;
  end;
end;

constructor TBall.Create(dw:integer; dh:integer);
begin
  r:=20;
  v:=200;
  x:=dw/2;
  y:=dh/2;
  kx:=-1;
  ky:=-1;
  colour:=clGreen;
  angle:=45;
  vMax:=1000;
  UpdateFieldState(dw,dh);
end;

{SpeedBall}

procedure TSpeedBall.MoveBall;
begin
  inherited MoveBall;
  if (hadCollision) then
  begin
    SetVelocity(v*1.1);
  end;
end;

procedure TSpeedBall.drawMeself(var bMap:TBitmap);
var xi,yi,ri:integer;
begin
  if (not useGLRender) then
  begin
    xi:=round(x);
    yi:=round(y);
    ri:=round(r);
    with bMap.Canvas do
    begin
      Pen.Color:=clBlack;
      Brush.Color:=colour;
      Rectangle(xi-ri,yi-ri,xi+ri,yi+ri);
    end;
  end
  else
  begin
    glBegin(GL_TRIANGLE_STRIP);

    glColor3f(GetRValue(ColorToRGB(colour))/256,GetGValue(ColorToRGB(colour))/256,GetBValue(ColorToRGB(colour))/256);

    glVertex2f(x-r,y-r);
    glVertex2f(x+r,y-r);
    glVertex2f(x-r,y+r);
    glVertex2f(x+r,y+r);

    glEnd;
  end;
end;

constructor TSpeedBall.Create(dw:integer; dh:integer);
begin
  inherited Create(dw,dh);
end;

{RotateBall}

procedure TRotateBall.MoveBall;
begin
  inherited MoveBall;
  if (hadCollision) then
  begin
    angle:=angle+15;
  end;
end;

procedure TRotateBall.drawMeself(var bMap:TBitmap);
var xi,yi,ri:integer;
    pts:array [0..2] of TPoint;
begin

  if (not useGLRender) then
  begin

    xi:=round(x);
    yi:=round(y);
    ri:=round(r);
    pts[0].x:=xi;
    pts[0].y:=yi+ri;
    pts[1].x:=xi-ri;
    pts[1].y:=yi-ri;
    pts[2].x:=xi+ri;
    pts[2].y:=yi-ri;
    with bMap.Canvas do
    begin
      Pen.Color:=clBlack;
      Brush.Color:=colour;
      Polygon(pts);
    end;
  end
  else
  begin
    glBegin(GL_TRIANGLE_STRIP);

    glColor3f(GetRValue(ColorToRGB(colour))/256,GetGValue(ColorToRGB(colour))/256,GetBValue(ColorToRGB(colour))/256);

    glVertex2f(x-r,y-r);
    glVertex2f(x+r,y-r);
    glVertex2f(x,y+r);

    glEnd;

  end;
end;

constructor TRotateBall.Create(dw:integer; dh:integer);
begin
  inherited Create(dw,dh);
end;

{ TForm1 }

procedure TForm1.Button1Click(Sender: TObject);
var xi,yi,ri:integer;
    bmp:TBitmap;
    fieldRect:TRect;
    i,j:integer;
begin

  if (work) then work:=false else work:=true;

  if (work) then
  begin
    CTime:=Now;
    LTime:=Now;
  end;

  while (work) do
  begin
    //update time
    CTime:=Now;
    dt:=MilliSecondsBetween(CTime,LTime)/1000;
    LTime:=CTime;

    timer:=timer+dt;
    Label1.Caption:='timer='+floattostr(timer);

    if (not useGLRender) then
    begin
      fw:=Image1.Width;
      fh:=Image1.Height;
    end
    else
    begin
      fw:=OpenGLControl1.Width;
      fh:=OpenGLControl1.Height;
    end;

    //operate ball
    if (Length(balls)>0) then
    for j:=0 to Length(balls)-1 do
    begin
      balls[j].UpdateFieldState(fw,fh);
      balls[j].UpdateDeltaTime(dt);
      balls[j].MoveBall;
    end;

    //make sure needed objects are visible
    if (useGLRender) then
    begin
      if (Image1.Visible) then Image1.Visible:=false;
      if (OpenGLControl1.Visible = false) then OpenGLControl1.Visible:=true;
    end
    else
    begin
      if (Image1.Visible = false) then Image1.Visible:=true;
      if (OpenGLControl1.Visible) then OpenGLControl1.Visible:=false;
    end;

    //Render image
    if (not useGLRender) then
    begin
      Image1.Picture.Bitmap.Width:=fw;
      Image1.Picture.Bitmap.Height:=fh;

      bmp:=TBitmap.Create;

      bmp.Width:=fw;
      bmp.Height:=fh;

      //background
      with bmp.Canvas do
      begin
        Pen.Color:=clBlack;
        Brush.Color:=clWhite;
        Rectangle(0,0,fw,fh);
      end;

      //cycle through rendering all the traces
      for j:=0 to Length(balls)-1 do
      begin
        //trace
        xi:=round(balls[j].bx);
        yi:=round(balls[j].by);
        ri:=round(balls[j].br);

        if (balls[j].traceLength>0) then
        for i:=0 to balls[j].traceLength-1 do
        with bmp.Canvas do
        begin
          MoveTo(balls[j].getTraceEl(i).x,balls[j].getTraceEl(i).y);
          if (i=balls[j].traceLength-1) then
          begin
            LineTo(xi,yi);
          end
          else
          begin
            LineTo(balls[j].getTraceEl(i+1).x,balls[j].getTraceEl(i+1).y);
          end;
        end;
      end;

      //cycle through rendering all the balls
      for j:=0 to Length(balls)-1 do
      begin
        //ball
        balls[j].drawMeself(bmp);
      end;

      fieldRect:=Rect(0,0,fw,fh);
      Image1.Canvas.CopyRect(fieldRect,bmp.Canvas,fieldRect);

      FreeAndNil(bmp);
    end;

    if (useGLRender) then
    begin
      glViewport(0,0,fw,fh);

      glClearColor(1,1,1,1);

      glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

      glMatrixMode(GL_PROJECTION);
      glLoadIdentity;

      gluOrtho2D(0,fw,fh,0);

      glMatrixMode(GL_MODELVIEW);
      glLoadIdentity;


      for j:=0 to Length(balls)-1 do
      begin
        if (balls[j].traceLength>0) then
        for i:=0 to balls[j].traceLength-1 do
        begin
          glBegin(GL_LINE_STRIP);
            glVertex3f(balls[j].getTraceEl(i).x,balls[j].getTraceEl(i).y,0.5);
            if (i=balls[j].traceLength-1) then
            begin
              glVertex3f(balls[j].x,balls[j].y,0.5);
            end
            else
            begin
              glVertex3f(balls[j].getTraceEl(i+1).x,balls[j].getTraceEl(i+1).y,0.5);
            end;
          glEnd;
        end;
      end;


      for j:=0 to Length(balls)-1 do
      begin
        //ball
        balls[j].drawMeself(bmp);
      end;

      OpenGLControl1.SwapBuffers;

    end;
    //process messages
    Application.ProcessMessages;
  end;

end;

procedure TForm1.btnSwapRendersClick(Sender: TObject);
begin
  if (useGLRender) then
  begin
    useGLRender:=false;
  end
  else
  begin
    useGLRender:=true;
  end;
end;

procedure TForm1.Button2Click(Sender: TObject);
var rVal:integer;
begin
  setlength(balls,Length(balls)+1);
  rVal:=random(100);
  if (rVal<33) then
  begin
    balls[High(balls)]:=TBall.Create(Image1.Width,Image1.Height);
    Label2.Caption:='Added Ball';
  end;
  if (rVal>=33) and (rVal<66) then
  begin
    balls[High(balls)]:=TSpeedBall.Create(Image1.Width,Image1.Height);
    Label2.Caption:='Added Speedball';
  end;
  if (rVal>=66) and (rVal<100) then
  begin
    balls[High(balls)]:=TRotateBall.Create(Image1.Width,Image1.Height);
    Label2.Caption:='Added Rotateball';
  end;

  balls[High(balls)].randomizeBall;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Randomize;
  glClearColor(1,1,1,1);
  glEnable(GL_DEPTH_TEST);
end;

end.

