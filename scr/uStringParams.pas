unit uStringParams;

interface

uses
  SysUtils;

const
  DefaultParamsSeparator=';';
  DefaultValuesSeparator=',';
  DefaultParamDelim='"';

Function FindParam(const KeyWord, StrParam: String): String;
Function SortParams(const ParamsSet: String; ParamNo: Word; SeparateChar: String=DefaultValuesSeparator;
  ParamDelim: String=DefaultParamDelim): String;
Function ParamPos(const ParamsSet: String; ParamNo: Word; SeparateChar: String=DefaultValuesSeparator;
  ParamDelim: String=DefaultParamDelim): Word;
Function ParamsCount(const ParamsSet: String; SeparateChar: String=DefaultValuesSeparator;
  ParamDelim: String=DefaultParamDelim): Word;
Function GetClearParam(const Param: String; ParamDelim: String=DefaultParamDelim): String;
Function PosEx(const SubStr, S: String): Cardinal;
Function InitCap(const S: String): String;
Function TrimSymbols(S: String; TrimS: String): String;

implementation

Function TrimSymbols(S: String; TrimS: String): String;
var
  i: Cardinal;
begin
  for i:=Length(S) downto 1 do
    if Pos(S[i], TrimS)<>0 then
      Delete(S, i, 1);

  Result:=S;
end;

Function FindParam(const KeyWord, StrParam: String): String;
var
  Start, EndStr, lp: Word;
  vStrParam: String;
begin
  Result:='';
  vStrParam:=StrParam+DefaultParamsSeparator;
  Start:=PosEx(KeyWord, vStrParam);
  if Start<>0 then
  begin
    Result:='';
    lp:=Length(vStrParam);
    EndStr:=Start+Length(KeyWord);
    While vStrParam[EndStr]<>DefaultParamsSeparator do
    begin
      if EndStr-1=lp then
        break;
      Result:=Result+vStrParam[EndStr];
      Inc(EndStr);
    end;
  end;
end;

Function ParamsCount(const ParamsSet: String; SeparateChar: String=DefaultValuesSeparator;
  ParamDelim: String=DefaultParamDelim): Word;
var
  ParamCount, ParamLen, pv1: Word;
  StopSeparate: Boolean;
  DelimLeft, DelimRight, CurrDelim: Char;
begin
  if ParamDelim='' then
    ParamDelim:=DefaultParamDelim;

  if Length(ParamDelim)=2 then
  begin
    DelimLeft:=ParamDelim[1];
    DelimRight:=ParamDelim[2];
  end
  Else
  begin
    DelimLeft:=ParamDelim[1];
    DelimRight:=ParamDelim[1];
  end;

  if SeparateChar='' then
    SeparateChar:=DefaultValuesSeparator;
  ParamCount:=1;
  pv1:=1;
  ParamLen:=Length(ParamsSet);
  StopSeparate:=False;

  CurrDelim:=DelimLeft;
  While ParamLen>=pv1 do
  begin
    if (Pos(ParamsSet[pv1], SeparateChar)<>0)and not StopSeparate then
      Inc(ParamCount);
    if ParamsSet[pv1]=CurrDelim then
    begin
      StopSeparate:=not StopSeparate;
      if CurrDelim=DelimLeft then
        CurrDelim:=DelimRight
      Else if CurrDelim=DelimRight then
        CurrDelim:=DelimLeft;
    end;
    Inc(pv1);
  end;
  Result:=ParamCount;
end;

Function GetClearParam(const Param: String; ParamDelim: String=DefaultParamDelim): String;
var
  DelimLeft, DelimRight: Char;
begin
  if Length(ParamDelim)=2 then
  begin
    DelimLeft:=ParamDelim[1];
    DelimRight:=ParamDelim[2];
  end
  Else
  begin
    DelimLeft:=ParamDelim[1];
    DelimRight:=ParamDelim[1];
  end;
  Result:=Param;
  if Length(Param)>=2 then
    if (Param[1]=DelimLeft)and(Param[Length(Param)]=DelimRight) then
      Result:=Copy(Param, 2, Length(Param)-2)
    Else
      Result:=Param;
end;

Function SortParams(const ParamsSet: String; ParamNo: Word; SeparateChar: String=DefaultValuesSeparator;
  ParamDelim: String=DefaultParamDelim): String;
var
  ParamCount, ParamLen, pv1, pv2: Word;
  StopSeparate: Boolean;
  DelimLeft, DelimRight, CurrDelim: Char;
  S:string;
begin
  If ParamNo=0 then
  Begin
    Result:='';
    Exit;
  End;

  if ParamDelim='' then
    ParamDelim:=DefaultParamDelim;

  if Length(ParamDelim)=2 then
  begin
    DelimLeft:=ParamDelim[1];
    DelimRight:=ParamDelim[2];
  end
  Else
  begin
    DelimLeft:=ParamDelim[1];
    DelimRight:=ParamDelim[1];
  end;

  if SeparateChar='' then
    SeparateChar:=DefaultValuesSeparator;
  Dec(ParamNo);
  ParamCount:=0;
  pv1:=1;
  StopSeparate:=False;
  ParamLen:=Length(ParamsSet);
  if ParamLen<>0 then
  begin
    CurrDelim:=DelimLeft;
    While (ParamCount<>ParamNo)and(ParamLen+1<>pv1) do
    begin
      if (Pos(ParamsSet[pv1], SeparateChar)<>0)and not StopSeparate then
        Inc(ParamCount);
      if ParamsSet[pv1]=CurrDelim then
      begin
        StopSeparate:=not StopSeparate;
        if CurrDelim=DelimLeft then
          CurrDelim:=DelimRight
        Else if CurrDelim=DelimRight then
          CurrDelim:=DelimLeft;
      end;
      Inc(pv1);
    end;

    pv2:=pv1;
    While (ParamLen>=pv2)and(ParamCount=ParamNo) do
    begin
      if (Pos(ParamsSet[pv2], SeparateChar)<>0)and not StopSeparate then
        Inc(ParamCount);
      if ParamsSet[pv2]=CurrDelim then
      begin
        StopSeparate:=not StopSeparate;
        if CurrDelim=DelimLeft then
          CurrDelim:=DelimRight
        Else if CurrDelim=DelimRight then
          CurrDelim:=DelimLeft;
      end;
      Inc(pv2);
    end;
    if (pv2-1=ParamLen)and(ParamCount=ParamNo) then
      Inc(pv2);
      
    S:=Trim(Copy(ParamsSet, pv1, pv2-pv1-1));
    Result:=S;
  end
  Else
    Result:='';
end;

Function ParamPos(const ParamsSet: String; ParamNo: Word; SeparateChar: String=DefaultValuesSeparator;
  ParamDelim: String=DefaultParamDelim): Word;
var
  ParamCount, ParamLen, pv1: Word;
  StopSeparate: Boolean;
  DelimLeft, DelimRight, CurrDelim: Char;
  S:string;
begin
  If ParamNo=0 then
  Begin
    Result:=1;
    Exit;
  End;

  if ParamDelim='' then
    ParamDelim:=DefaultParamDelim;

  if Length(ParamDelim)=2 then
  begin
    DelimLeft:=ParamDelim[1];
    DelimRight:=ParamDelim[2];
  end
  Else
  begin
    DelimLeft:=ParamDelim[1];
    DelimRight:=ParamDelim[1];
  end;

  if SeparateChar='' then
    SeparateChar:=DefaultValuesSeparator;
  Dec(ParamNo);
  ParamCount:=0;
  pv1:=1;
  StopSeparate:=False;
  ParamLen:=Length(ParamsSet);
  if ParamLen<>0 then
  begin
    CurrDelim:=DelimLeft;
    While (ParamCount<>ParamNo)and(ParamLen+1<>pv1) do
    begin
      if (Pos(ParamsSet[pv1], SeparateChar)<>0)and not StopSeparate then
        Inc(ParamCount);
      if ParamsSet[pv1]=CurrDelim then
      begin
        StopSeparate:=not StopSeparate;
        if CurrDelim=DelimLeft then
          CurrDelim:=DelimRight
        Else if CurrDelim=DelimRight then
          CurrDelim:=DelimLeft;
      end;
      Inc(pv1);
    end;

    Result:=pv1;
  end
  Else
    Result:=1;
end;

Function PosEx(const SubStr, S: String): Cardinal;
begin
  Result:=Pos(AnsiLowerCase(SubStr), AnsiLowerCase(S));
end;

Function InitCap(const S: String): String;
begin
  if S<>'' then
    Result:=AnsiUpperCase(S[1])+Copy(S, 2, Length(S)-1)
  Else
    Result:='';
end;

end.
