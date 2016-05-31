unit uVariablesParser;

interface

uses
  SysUtils, DateUtils, uStringParams;

Function PosEx(Const SubStr, S: String): Cardinal;
Function GetMonthByNum(Num: Integer): String;
Function StrToIntEx(St:String):LongInt;
Procedure RePlaceVariables(var VariablesSet: String);
Function DeclareOneVariable(Const VariableName: String): Integer;
Procedure DeclareVariable(Const VariableNameSet: String);
Procedure DisposeVariable(Const VariableName: String);
Procedure SetVariable(Const VariableName, VarValue: String);
Function VariableExists(Const VariableName: String): Boolean;
Function VariableByName(Const VariableName: String): String;
Procedure TranslateProc(var CallProc: String; var Factor:Word);

implementation

Type
  TVariable=Record
    Name: String[50];
    Value: String;
  End;

Const
  MaxVariables=50;
  MonthsNames: Array [0..12] of String=(' ', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь');

  VariablePrefix='$';
  ProcPrefix='!!';

  DateFormat='dd.mm.yyyy';
  TimeFormat='hh:mm:ss';

var
  VariablesCount: Word;
  Variables: Array [1..MaxVariables] of TVariable;


Function StrToIntEx(St:String):LongInt;
Var
  iI, L:Integer;
  tmpS:String;
Begin
  L:=Length(St);
  tmpS:='';
  For iI:=1 To L Do
  Begin
    If (St[iI]>='0')And(St[iI]<='9')Or(St[iI]='-') Then
      tmpS:=tmpS+St[iI];
  End;
  If tmpS='' Then
    tmpS:='0';
  Try
    Result:=StrToInt(tmpS);
  Except
    Result:=0;
  End;
End;

Function PosEx(Const SubStr, S: String): Cardinal;
Begin
  Result:=Pos(AnsiLowerCase(SubStr), AnsiLowerCase(S));
End;

Function GetMonthByNum(Num: Integer): String;
Begin
  Result:=MonthsNames[Num];
End;

function PosInSet(SimbolsSet, SourceStr:String):Cardinal;
Var
  i:Cardinal;
begin
  Result:=0;
  For i:=1 to Length(SourceStr) do
  Begin
    If PosEx(SourceStr[i], SimbolsSet)<>0 then
    Begin
      Result:=i;
      Break;
    End;
  End;
end;

Function DateToStr_(Date: TDateTime): String;
Begin
  DateTimeToString(Result, DateFormat, Now);
End;

Function TimeToStr_(Time: TDateTime): String;
Begin
  DateTimeToString(Result, TimeFormat, Now);
End;

Function TimeStampToStr(Date: TDateTime): String;
Begin
  Result:=DateToStr_(Date)+' '+TimeToStr_(Date);
End;

Function VariableExists(Const VariableName: String): Boolean;
var
  VarNum: Word;
Begin
  Result:=False;

  For VarNum:=1 to VariablesCount do
    If UpperCase(Trim(VariableName))=UpperCase(Variables[VarNum].Name) then
    Begin
      Result:=True;
      Break;
    End;
End;

Function VariableNumByName(Const VariableName:String):Integer;
Var
  VarNum:Integer;
Begin
  Result:=-1;
  If VariableName<>'' Then
  Begin
    For VarNum:=1 to MaxVariables do
      If LowerCase(Variables[VarNum].Name)=LowerCase(Trim(VariableName)) Then
      Begin
        Result:=VarNum;
        Break;
      End;
  End;
End;

Function VariableByNum(Const VarNum: Integer): String;
Begin
  If VarNum<> - 1 then
    Result:=Variables[VarNum].Value
  Else
    Result:='';
End;

Function VariableByName(Const VariableName: String): String;
var
  vv1: Integer;
Begin
  Result:='';
  vv1:=VariableNumByName(VariableName);
  If vv1>0 then
    Result:=Variables[vv1].Value;
End;

Procedure SetVariable(Const VariableName, VarValue: String);
var
  vv1: Integer;
Begin
  vv1:=VariableNumByName(VariableName);
  If vv1>0 then
    Variables[vv1].Value:=VarValue;
End;

Procedure SetVariableByNum(Const VariableNum: Integer; VarValue: String);
Begin
  If VariableNum>0 then
    Variables[VariableNum].Value:=VarValue;
End;

function FindEmptyVariableSlot:Integer;
Var
  i:Word;
Begin
  Result:=-1;
  For i:=1 to MaxVariables do
  begin
    If Variables[i].Name='' then
    Begin
      Result:=i;
      Break;
    End;
  end;
End;

Function DeclareOneVariable(Const VariableName: String): Integer;
var
  RetVarNum: Integer;
Begin
  If VariableName='' then
    Exit;
  RetVarNum:=VariableNumByName(VariableName);
  If RetVarNum= - 1 then
  Begin
    If VariablesCount+1>MaxVariables then
    Begin
      Result:= - 1;
      Exit;
    End
    Else
    Begin
      Inc(VariablesCount);
      RetVarNum:=FindEmptyVariableSlot;
      If RetVarNum<>-1 then
      Begin
        Variables[RetVarNum].Name:=Trim(VariableName);
        Variables[RetVarNum].Value:='';
      End;
      Result:=RetVarNum;
    End;
  End
  Else
  Begin
    Variables[RetVarNum].Value:='';
    Result:=RetVarNum;
  End;
End;

Procedure DeclareVariable(Const VariableNameSet: String);
var
  tmpStr, tmpStr2, tmpStr3: String;
  v1, v2, v3: Integer;
Begin
  tmpStr:=Trim(VariableNameSet);
  RePlaceVariables(tmpStr);
  For v2:=1 to ParamsCount(tmpStr, ';') do
  Begin
    tmpStr2:=SortParams(tmpStr, v2, ';');
    v1:=PosEx('=', tmpStr2);
    If v1=0 then
      v3:=DeclareOneVariable(tmpStr2)
    Else
      v3:=DeclareOneVariable(Trim(Copy(tmpStr2, 1, v1-1)));

    If v1<>0 then
    Begin
      tmpStr3:=Copy(tmpStr2, v1+1, Length(tmpStr2)-v1);
      Variables[v3].Value:=tmpStr3;
    End;
  End;
End;

Procedure DisposeVariable(Const VariableName: String);
var
  VarNum, Count: Integer;
Begin
  If VariableName<>'' then
  Begin
    VarNum:=VariableNumByName(VariableName);
    If VarNum>0 then
    Begin
      If VarNum<VariablesCount then
        For Count:=VarNum to VariablesCount-1 do
          Variables[Count]:=Variables[Count+1];
      Variables[VariablesCount].Name:='';
      Variables[VariablesCount].Value:='';
      Dec(VariablesCount);
    End;
  End;
End;

Procedure RePlaceVariables(var VariablesSet: String);
Const
  MaxSysVars=8;
  SysVarsSet: Array [1..MaxSysVars] of String=('_TIME_', '_TIMES_', '_DATE_', '_DATETIME_', // 4
    '_APPPATH_', '_YEAR_', '_MONTH_', '_DAY_'); // 8
var
  ReplaseVar, tmpStr, S: String;
  StartSel, ParamLen, StartSearch, pv1, pv2, pv3, FindVarNum, VarNameLength, lv1, i, j,
    MaxMatch: Word;
  VarExists, SysVar, FindVar: Boolean;
Begin
  StartSearch:=Pos(VariablePrefix, VariablesSet);
  while Pos(VariablePrefix, Copy(VariablesSet, StartSearch, Length(VariablesSet)))<>0 do
  Begin
    StartSearch:=StartSearch+Pos(VariablePrefix, Copy(VariablesSet, StartSearch,
        Length(VariablesSet)))-1;
    StartSel:=StartSearch+Length(VariablePrefix)-1;
    ParamLen:=Length(VariablesSet);
    SysVar:=False;
    If ParamLen<>0 then
    Begin
      pv3:=1;
      FindVarNum:=0;
      MaxMatch:=0;

      while (VariablesCount>=pv3) do
      Begin
        FindVar:=True;
        pv2:=1;
        pv1:=StartSel+1;
        while (FindVar)and(pv1<=ParamLen)and(pv2<=Length(Variables[pv3].Name)) do
        Begin
          FindVar:=False;
          If Length(Variables[pv3].Name)>=pv2 then
          Begin
            If UpperCase(VariablesSet[pv1])=UpperCase(Variables[pv3].Name[pv2]) then
            Begin
              FindVar:=True;
              If MaxMatch<pv1 then
              Begin
                MaxMatch:=pv1;
                FindVarNum:=pv3;
                SysVar:=False;
              End;
            End;
          End;
          Inc(pv1);
          Inc(pv2);
        End;
        Inc(pv3);
      End;

      If FindVarNum=0 then
      Begin
        pv3:=1;
        while (MaxSysVars>=pv3) do
        Begin
          FindVar:=True;
          pv2:=1;
          pv1:=StartSel+1;
          while (FindVar)and(pv1<=ParamLen)and(pv2<=Length(SysVarsSet[pv3])) do
          Begin
            FindVar:=False;
            If Length(SysVarsSet[pv3])>=pv2 then
            Begin
              If UpperCase(VariablesSet[pv1])=UpperCase(SysVarsSet[pv3][pv2]) then
              Begin
                FindVar:=True;
                If MaxMatch<pv1 then
                Begin
                  MaxMatch:=pv1;
                  FindVarNum:=pv3;
                  SysVar:=True;
                End;
              End;
            End;
            Inc(pv1);
            Inc(pv2);
          End;
          Inc(pv3);
        End;
      End;

      If FindVarNum<>0 then
      Begin
        VarNameLength:=MaxMatch-StartSel;
        ReplaseVar:=Copy(VariablesSet, StartSel+1, VarNameLength);
      End
      Else
      Begin
        VarNameLength:=0;
        ReplaseVar:='';
      End;

      If SysVar and(FindVarNum<>0) then
      Begin
        Case FindVarNum of
        1:
        Begin
          tmpStr:=TimeToStr(SysUtils.Time);
          If (tmpStr[5]=':') then
            SetLength(tmpStr, 4);
          If (tmpStr[6]=':') then
            SetLength(tmpStr, 5);
        End;
        2:
        Begin
          tmpStr:=TimeToStr(SysUtils.Time);
        End;
        3:
        Begin
          tmpStr:=DateToStr(Date);
        End;
        4:
        Begin
          tmpStr:=TimeStampToStr(Date);
        End;
        5:
        Begin
          tmpStr:=ExtractFilePath(ParamStr(0));
        End;
        6:
        Begin
          tmpStr:=IntToStr(YearOf(Now));
        End;
        7:
        Begin
          tmpStr:=IntToStr(MonthOf(Now));
        End;
        8:
        Begin
          tmpStr:=IntToStr(DayOf(Now));
        End;
        End;
      End;

      VarExists:=VariableExists(ReplaseVar);
      If SysVar then
        VarExists:=True;

      If VarExists then
      Begin
        Delete(VariablesSet, StartSel, VarNameLength+Length(VariablePrefix));
        If not SysVar then
          tmpStr:=VariableByName(ReplaseVar);
        Insert(tmpStr, VariablesSet, StartSel);
        Inc(StartSearch, Length(tmpStr)+Length(VariablePrefix));
        tmpStr:='';
      End
      Else
        Inc(StartSearch, 1+Length(VariablePrefix));
    End;
  End;
End;


Procedure TranslateProc(var CallProc: String; var Factor:Word);
Const
  ProcCount=9;
  ProcNames: Array [1..ProcCount] of String=('ToFloat', 'ByIndex',  //2
    'Count', 'IndexOf', 'NVL', 'iif', 'GetMonthName', 'DaysInAMonth', //8
    'LeadingZero'); // 9
var
  ReplaseProc, Param, tmpStr, tmpStr2, TmpStr3, Sign: String;
  StartSel, ParamLen, StartSearch, pv1, pv2, pv3, pv4, FindProcNum, Skobki, VarNameLength,
    MaxMatch: Word;
  FindVar: Boolean;
  FunctionParams: Array of String;
  FunctionParamsCount: Byte;
Begin
  Inc(Factor);
  StartSearch:=Pos(ProcPrefix, CallProc);
  while Pos(ProcPrefix, Copy(CallProc, StartSearch, Length(CallProc)))<>0 do
  Begin
    StartSearch:=StartSearch+Pos(ProcPrefix, Copy(CallProc, StartSearch, Length(CallProc)))-1;
    StartSel:=StartSearch+Length(ProcPrefix);

    ParamLen:=Length(CallProc);
    If ParamLen<>0 then
    Begin
      pv3:=1;
      FindProcNum:=0;
      MaxMatch:=0;

      while (ProcCount>=pv3) do
      Begin
        FindVar:=True;
        pv2:=1;
        pv1:=StartSel;
        while (FindVar)and(pv1<=ParamLen)and(pv2<=Length(ProcNames[pv3])) do
        Begin
          FindVar:=False;
          If Length(ProcNames[pv3])>=pv2 then
          Begin
            If UpperCase(CallProc[pv1])=UpperCase(ProcNames[pv3][pv2]) then
            Begin
              FindVar:=True;
              If MaxMatch<pv1 then
              Begin
                MaxMatch:=pv1;
                FindProcNum:=pv3;
              End;
            End;
          End;
          Inc(pv1);
          Inc(pv2);
        End;
        Inc(pv3);
      End;

      If FindProcNum<>0 then
      Begin
        VarNameLength:=MaxMatch-StartSel+1;
        ReplaseProc:=Copy(CallProc, StartSel, VarNameLength);
        pv2:=1;
        FindVar:=False;
        while (pv2<=ProcCount)and(FindVar=False) do
        Begin
          If UpperCase(ReplaseProc)=UpperCase(ProcNames[pv2]) then
          Begin
            FindVar:=True;
            FindProcNum:=pv2;
          End;
          Inc(pv2);
        End;
        If FindVar then
        Begin
          Dec(StartSel, Length(ProcPrefix));
          Delete(CallProc, StartSel, Length(ProcPrefix));
          Dec(MaxMatch, Length(ProcPrefix));
        End;

      End
      Else
      Begin
        VarNameLength:=0;
        ReplaseProc:='';
      End;

      pv1:=MaxMatch;

      Skobki:=0;
      Repeat
        If CallProc[pv1]='(' then
          Skobki:=1;
        Inc(pv1);
      Until (CallProc[pv1]<>'(')and(ParamLen+1>=pv1);
      pv2:=pv1;

      while (Skobki<>0)and(pv1<=ParamLen) do
      Begin
        If CallProc[pv1]=')' then
          Dec(Skobki)
        Else If CallProc[pv1]='(' then
          Inc(Skobki);

        Inc(pv1);
      End;
      MaxMatch:=pv1;

      Param:=Copy(CallProc, pv2, pv1-pv2-1);

      If Pos(ProcPrefix, Param)<>0 then
        TranslateProc(Param, Factor);

      FunctionParamsCount:=ParamsCount(Param, ',');
      SetLength(FunctionParams, FunctionParamsCount+1);
      FunctionParams[0]:=ProcNames[FindProcNum];
      For pv1:=1 to FunctionParamsCount do
      Begin
        FunctionParams[pv1]:=SortParams(Param, pv1, ',', '"');
        RePlaceVariables(FunctionParams[pv1]);
      End;

      If Skobki=0 then
        Case FindProcNum of
        // ToFloat
        1:
        Begin
          Trim(FunctionParams[1]);
          If Pos('.', FunctionParams[1])=0 then
            tmpStr:=FunctionParams[1]+'.00'
          Else
          Begin
            tmpStr:=Copy(FunctionParams[1], Pos('.', FunctionParams[1])+1, Length(FunctionParams[1])-Pos('.', FunctionParams[1])+1);
            If Length(tmpStr)=1 then
              tmpStr:=tmpStr+'0'
            Else
              tmpStr:=FunctionParams[1];
          End;
        End;

        // ByIndex
        2:
        Begin
          tmpStr2:='';
          For pv3:=2 to FunctionParamsCount do
          Begin
            tmpStr2:=tmpStr2+FunctionParams[pv3]+',';
          End;
          tmpStr:=SortParams(tmpStr2, StrToIntEx(FunctionParams[1]), ',');
        End;

        // Count
        3:
        Begin
          RePlaceVariables(FunctionParams[1]);
          tmpStr:=IntToStr(ParamsCount(FunctionParams[1], ','));
        End;

        // IndexOf
        4:
        Begin
          tmpStr:='';
          pv4:=0;
          For pv3:=2 to FunctionParamsCount do
          Begin
            pv2:=ParamsCount(FunctionParams[pv3], ',');
            For pv1:=1 to pv2 do
            Begin
              If AnsiLowerCase(FunctionParams[1])
                =AnsiLowerCase(SortParams(FunctionParams[pv3], pv1, ',')) then
              Begin
                tmpStr:=IntToStr(pv1+pv4);
                Break;
              End;
            End;
            Inc(pv4, pv2);
          End;
        End;

        5: // NVL
        Begin
          If FunctionParams[1]='' then
            tmpStr:=FunctionParams[2]
          Else
            tmpStr:=FunctionParams[1];
        End;

        6: // iif
        Begin
          If FunctionParamsCount=3 Then
          Begin
          pv1:=PosInSet('<>=', FunctionParams[1]);
          If pv1<>0 then
          Begin
            pv2:=pv1+1;
            If FunctionParams[1][pv2] in ['>', '<', '='] then Inc(pv2);
            Sign:=Copy(FunctionParams[1], pv1, pv2-pv1);

            TmpStr2:=Copy(FunctionParams[1], 1, pv1-1);
            TmpStr3:=Copy(FunctionParams[1], pv2, Length(FunctionParams[1]));
            TmpStr2:=Trim(AnsiLowerCase(TmpStr2));
            TmpStr3:=Trim(AnsiLowerCase(TmpStr3));

            If Sign='=' then
            Begin
              If TmpStr2=TmpStr3 then
                TmpStr:=FunctionParams[2]
              Else
                TmpStr:=FunctionParams[3];
            End
            Else
            If Sign='>' then
            Begin
              If TmpStr2>TmpStr3 then
                TmpStr:=FunctionParams[2]
              Else
                TmpStr:=FunctionParams[3];
            End
            Else
            If Sign='<' then
            Begin
              If TmpStr2<TmpStr3 then
                TmpStr:=FunctionParams[2]
              Else
                TmpStr:=FunctionParams[3];
            End
            Else
            If Sign='<>' then
            Begin
              If TmpStr2<>TmpStr3 then
                TmpStr:=FunctionParams[2]
              Else
                TmpStr:=FunctionParams[3];
            End
            Else
            If Sign='<=' then
            Begin
              If TmpStr2<=TmpStr3 then
                TmpStr:=FunctionParams[2]
              Else
                TmpStr:=FunctionParams[3];
            End
            Else
            If Sign='>=' then
            Begin
              If TmpStr2>=TmpStr3 then
                TmpStr:=FunctionParams[2]
              Else
                TmpStr:=FunctionParams[3];
            End;
          End;
          End;
        End;

        7: // DaysInAMonth
        Begin
          tmpStr:=IntToStr(DaysInAMonth(StrToIntEx(FunctionParams[1]), StrToInt(FunctionParams[2])));
        End;

        8:  // LeadingZero
        Begin
          tmpStr:=FunctionParams[1];
          If StrToInt(FunctionParams[2])>0 then
          Begin
            If Length(tmpStr)<StrToIntEx(FunctionParams[2]) then
              For pv1:=Length(tmpStr) to StrToInt(FunctionParams[2])-1 do
                tmpStr:='0'+tmpStr;
          End;
        End;

        End;

      Delete(CallProc, StartSel, MaxMatch-StartSel);
      If Factor=1 then
        Insert(GetClearParam(tmpStr, DefaultParamDelim), CallProc, StartSel)
      Else
        Insert(tmpStr, CallProc, StartSel);

      Inc(StartSearch, Length(tmpStr)+1);
    End;
  End;
  Dec(Factor);
End;

initialization
  VariablesCount:=0;


End.
