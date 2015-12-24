program ucron;

{$IFDEF FPC}
{$H+}
{$MODE DELPHI}
{$ENDIF}
{$IFDEF CONS}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  {$IFDEF UNIX}
  unix, process,
  {$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}
  {$ENDIF}
  {$IFDEF FPC}
  Interfaces,
  {$ENDIF}
  {$IFDEF MSWINDOWS}Windows, ActiveX, ShellAPI,{$ENDIF}
  SysUtils,
  uVariablesParser in 'uVariablesParser.pas',
  uStringParams in 'uStringParams.pas';
{
* * * * * выполняемая команда
- - - - -
| | | | |
| | | | ----- День недели (ПН=1..ВС=7)
| | | ------- Месяц (1 - 12)
| | --------- День (1 - 31)
| ----------- Час (0 - 23)
------------- Минута (0 - 59)}

type
  TCronGroups=(crMin, crHour, crDay, crMonth, crDoW);

  TTimeSubElement=record
    Lo, Hi, Step:Integer;
  end;

  TTimeElement=Record
    ValuesSet:Array of TTimeSubElement;
  End;

  TCronJob=Record
    CronTime:array[TCronGroups] of TTimeElement;
    CommandStr:String;
  End;

  TRealTime=Array[TCronGroups] of Integer;

  TDateTimeStructure=Record
    Hour, Min, Sec, mSec, Year, Month, Day,
    Dow:Word;
  End;

  { TCron }
  TCron=class
  private
    AppPath:String;
    Jobs:Array of TCronJob;
    CronTab:array of String;

    procedure LoadFromFile(FileName:string);
  public
    constructor Create;
    function Exec:Byte;

    procedure UpdateTab;
  End;

const
  TabFileName='crontab';

var
  vCron:TCron;
  cMin:Byte;

function ParseSection(Section:string):TTimeElement;
var
  ElementS, s1:string;
  TM:TTimeSubElement;
  i, c:Byte;
  p:Word;
begin
  c:=ParamsCount(Section);
  SetLength(Result.ValuesSet, 0);
  for i:=1 to c do
  begin
    ElementS:=SortParams(Section, i);

    TM.Lo:=-1;
    TM.Hi:=-1;
    TM.Step:=1;
    If Pos('-', ElementS)<>0 then
    begin
      p:=Pos('-', ElementS);
      s1:=Copy(ElementS, 1, p-1);
      TM.Lo:=StrToIntEx(s1);
      Delete(ElementS, 1, p);
      p:=Pos('/', ElementS);
      If p<>0 then
      begin
        s1:=Copy(ElementS, 1, p-1);
        Delete(ElementS, 1, p-1);
        TM.Hi:=StrToIntEx(s1);
      end
      else
      begin
        s1:=Copy(ElementS, 1, Length(ElementS));
        Delete(ElementS, 1, Length(ElementS));
        TM.Hi:=StrToIntEx(s1);
      end;
    end;
    If Pos('/', ElementS)<>0 then
    begin
      p:=Pos('/', ElementS);
      s1:=Copy(ElementS, p+1, Length(ElementS));
      TM.Step:=StrToIntEx(s1);
      Delete(ElementS, p, Length(ElementS));
    end;
    If ElementS<>'' then
    begin
      If ElementS='*' then
        ElementS:='-1';
      TM.Lo:=StrToIntEx(ElementS);
      TM.Hi:=TM.Lo;
    end;

    SetLength(Result.ValuesSet, i);
    Result.ValuesSet[i-1]:=TM;
  end;
end;

function ParseCronTab(CronTab:String):TCronJob;
Var
  Sect:string;
  i:TCronGroups;
  p:Word;
Begin
  for i:=TCronGroups(Low(TCronGroups)) to TCronGroups(High(TCronGroups)) do
  begin
    Sect:=SortParams(CronTab, Ord(i)+1, ' ');
    Result.CronTime[i]:=ParseSection(Sect);
  end;

  p:=ParamPos(CronTab, Ord(High(TCronGroups))+2, ' ');
  Result.CommandStr:=Copy(CronTab, p, Length(CronTab));
End;

function IsTask(S:string):Boolean;
begin
  Result:=((Pos('=', S)>Pos(' ', S)) or (Pos('=', S)=0)) and (Pos('#', S)<>1) and
    (Length(S)>11) and (Pos(' ', S)<>0);
end;

function IsVariable(S:String):Boolean;
begin
  Result:=((Pos('=', S)<Pos(' ', S)) or (Pos(' ', S)=0)) and (Pos('=', S)<>0) and (Pos('#', S)<>1);
end;

function TestTimeElement(CronTime: TTimeSubElement; RealTime:Integer):Boolean;
begin
  Result:=(((CronTime.Lo=-1) and (CronTime.Hi=-1)) or ((CronTime.Lo<=RealTime) and
    (CronTime.Hi>=RealTime))) and ((RealTime mod CronTime.Step)=0);
end;

function TestTime(CronTime:TTimeElement; RealTime:Integer):Boolean;
var
  i:Word;
begin
  Result:=False;
  for i:=0 to Length(CronTime.ValuesSet)-1 do
  begin
    Result:=TestTimeElement(CronTime.ValuesSet[i], RealTime);
    If Result then
      Break;
  end;
end;

function TestJob(Job:TCronJob; RealTime:TRealTime):Boolean;
var
  k:TCronGroups;
begin
  for k:=TCronGroups(Low(TCronGroups)) to TCronGroups(High(TCronGroups)) do
  begin
    Result:=TestTime(Job.CronTime[k], RealTime[k]);
    If not Result then
      Break;
  end;
end;

procedure ShellExecuteSimply(const AWnd: HWND; const AOperation, AFileName: String; const AParameters: String = ''; const ADirectory: String = ''; const AShowCmd: Integer = SW_SHOWNORMAL);
var
  ExecInfo: TShellExecuteInfo;
  NeedUninitialize: Boolean;
begin
  Assert(AFileName <> '');
 
  NeedUninitialize := SUCCEEDED(CoInitializeEx(nil, COINIT_APARTMENTTHREADED or COINIT_DISABLE_OLE1DDE));
  try
    FillChar(ExecInfo, SizeOf(ExecInfo), 0);
    ExecInfo.cbSize := SizeOf(ExecInfo);
 
    ExecInfo.Wnd := AWnd;
    ExecInfo.lpVerb := Pointer(AOperation);
    ExecInfo.lpFile := PChar(AFileName);
    ExecInfo.lpParameters := Pointer(AParameters);
    ExecInfo.lpDirectory := Pointer(ADirectory);
    ExecInfo.nShow := AShowCmd;
    ExecInfo.fMask := {$IFDEF NEWDELPHI}SEE_MASK_NOASYNC{$ELSE}SEE_MASK_FLAG_DDEWAIT{$ENDIF}
                   or SEE_MASK_FLAG_NO_UI;
    {$IFDEF UNICODE}
    // Необязательно, см. http://www.transl-gunsmoker.ru/2015/01/what-does-SEEMASKUNICODE-flag-in-ShellExecuteEx-actually-do.html
    ExecInfo.fMask := ExecInfo.fMask or SEE_MASK_UNICODE;
    {$ENDIF}
 
    {$WARN SYMBOL_PLATFORM OFF}
    Win32Check({$IFDEF FPC}{$ifdef UNICODE}ShellExecuteExW{$ELSE}ShellExecuteExA{$ENDIF}{$ELSE}ShellExecuteEx{$ENDIF}(@ExecInfo));
    {$WARN SYMBOL_PLATFORM ON}
  finally
    if NeedUninitialize then
      CoUninitialize;
  end;
end;

function TrimSymbols(const TrimChars, S:String):String;
var
  i, p:Word;
  V:string;
begin
  V:=S;
  For i:=1 to Length(TrimChars) do
  Begin
    p:=Pos(TrimChars[i], V);
    while p<>0 do
    begin
      Delete(V, p, 1);
      p:=Pos(TrimChars[i], V);
    end;
  End;
  Result:=V;
end;

procedure ExecApp(const App:String);
var
  s, dir, filename:string;
{$IFDEF UNIX}
  AProcess:TProcess;
  i, c:Byte;
{$ENDIF}
begin
  filename:=TrimSymbols('"', SortParams(App, 1, ' ', '"'));
  dir:=ExtractFilePath(filename);
  SetCurrentDir(dir);
  s:=App;
  Delete(s, 1, Length(filename));
  s:=Trim(s);
  filename:=ExtractFileName(filename);
{$IFDEF MSWINDOWS}
  ShellExecuteSimply(0, '', filename, s, dir, 1);
{$ENDIF}
{$IFDEF UNIX}
  Try
    AProcess:=TProcess.Create(nil);
    AProcess.Executable:=filename;
    AProcess.CurrentDirectory:=dir;
    c:=ParamsCount(App, ' ', '"');
    For i:=2 to c do
      AProcess.Parameters.Append(Trim(SortParams(App, i, ' ', '"')));
    AProcess.Execute;
    AProcess.Free;
  Except
    //
  end;
{$ENDIF}
end;

function DayOfTheWeek(const AValue: TDateTime): Word;
begin
  Result := (DateTimeToTimeStamp(AValue).Date - 1) mod 7+1;
end;

function GetTimeStruct:TDateTimeStructure;
begin
  DecodeDate(Now, Result.Year, Result.Month,
    Result.Day);
  Result.Dow:=DayOfTheWeek(Now);

  DecodeTime(Now, Result.Hour, Result.Min, Result.Sec, Result.mSec);
end;

constructor TCron.Create;
begin
  SetLength(CronTab, 1);
  CronTab[0]:='###';
  AppPath:=ExtractFilePath(ParamStr(0));
  UpdateTab;
end;

function TCron.Exec:Byte;
var
  NowTimeStruct:TDateTimeStructure;
  i, j:Word;
  RealTime:TRealTime;
  JobStr:string;
begin
  NowTimeStruct:=GetTimeStruct;
  
  RealTime[crMonth]:=NowTimeStruct.Month;
  RealTime[crDay]:=NowTimeStruct.Day;
  RealTime[crDoW]:=NowTimeStruct.Dow;
  RealTime[crMin]:=NowTimeStruct.Min;
  RealTime[crHour]:=NowTimeStruct.Hour;

  j:=0;
  For i:=0 to Length(CronTab)-1 do
  Begin
    If IsTask(CronTab[i]) then
    Begin
      JobStr:=CronTab[i];
      RePlaceVariables(JobStr);
      Jobs[j]:=ParseCronTab(JobStr);
{$IFDEF CONS}
      Writeln('['+TimeToStr(Now)+'] Job #'+IntToStr(j)+' prepearing. Command:'+Jobs[j].CommandStr);
{$ENDIF}
      If TestJob(Jobs[j], RealTime) then
      Begin
{$IFDEF CONS}
        Writeln('['+TimeToStr(Now)+'] Job #'+IntToStr(j)+' running. Command:'+Jobs[j].CommandStr);
{$ENDIF}
        ExecApp(Jobs[j].CommandStr);
      End;
      Inc(j);
    End;
    if IsVariable(CronTab[i]) then
      DeclareVariable(CronTab[i]);
  End;
  Result:=NowTimeStruct.Min;
end;

procedure TCron.LoadFromFile(FileName:string);
var
  T:TextFile;
  i, l:Word;
  S:string;
begin
  AssignFile(T, FileName);
  Reset(T);
  l:=Length(CronTab);
  i:=0;
  while not Eof(T) do
  begin
    Inc(i);
    If i>l then
      SetLength(CronTab, i);
    Readln(T, S);
    CronTab[i-1]:=S;
  end;
  CloseFile(T);
  SetLength(CronTab, i);
end;

procedure TCron.UpdateTab;
begin
  If FileExists(AppPath+TabFileName) then
    LoadFromFile(AppPath+TabFileName);
  SetLength(Jobs, Length(CronTab));
end;

begin
  cMin:=90;
  vCron:=TCron.Create;
  while 1=1 do
  Begin
    Sleep(3000);
    If GetTimeStruct.Min<>cMin then
    begin
      cMin:=vCron.Exec;
      Sleep(30);
      vCron.UpdateTab;
    end;
  end;
end.

