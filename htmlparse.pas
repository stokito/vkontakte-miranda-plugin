unit htmlparse;

interface

uses
  SysUtils,
  Classes,
  vk_global;

function TextBetweenInc(WholeText: string; BeforeText: string; AfterText: string): string;
function TextBetween(WholeText: string; BeforeText: string; AfterText: string): string;
function FindLine(Pattern: string; List: TStringList; StartAt: integer): integer;
function FindFullLine(Line: string; List: TStringList; StartAt: integer): integer;
function LastPos(ASearch: string; AText: string): integer;
function URLEncode(const AStr: string): string;
function URLDecode(const AStr: string): string;
function HTMLRemoveTags(const Value: WideString): WideString;
function HTMLDecode(const Value: string): string;
function TextBetweenTagsInc(WholeText, Tag: string): string;
function TextBetweenTagsAttrInc(WholeText, Tag, AttrName, AttrValue: WideString): WideString;
function ReplaceLink(WholeText: WideString): WideString;
function RemoveDuplicates(WholeText: WideString): WideString;
function PosEx(const SubStr, S: string; Offset: cardinal = 1): integer;
function HTMLDecodeW(const Value: WideString): WideString;
function Replace(Str, X, Y: string): string;
function StringReplaceW(const S, OldPattern, NewPattern: WideString; Flags: TReplaceFlags): WideString;

var
  RemainingText: string;

implementation

 // ****************************************************************************
 // String functions
 // ****************************************************************************

{    Returns the text between BeforeText and AfterText (including these two strings),
     It takes the first AfterText occurence found after the position of BeforeText  }
function TextBetweenInc(WholeText: string; BeforeText: string; AfterText: string): string;
var
  FoundPos: integer;
  WorkText: string;
begin
  RemainingText := WholeText;
  Result := '';
  FoundPos := Pos(BeforeText, WholeText);
  if FoundPos = 0 then
    Exit;
  WorkText := Copy(WholeText, FoundPos, Length(WholeText));
  FoundPos := Pos(AfterText, WorkText);
  if FoundPos = 0 then
    Exit;
  Result := Copy(WorkText, 1, FoundPos - 1 + Length(AfterText));
  RemainingText := Copy(WorkText, FoundPos + Length(AfterText), Length(WorkText));
end;


{    Returns the text between BeforeText and AfterText (without these two strings),
     It takes the first AfterText occurence found after the position of BeforeText
     Function created by Antoine Potten}
function TextBetween(WholeText: string; BeforeText: string; AfterText: string): string;
var
  FoundPos: integer;
  WorkText: string;
begin
  RemainingText := WholeText;
  Result := '';
  FoundPos := Pos(BeforeText, WholeText);
  if FoundPos = 0 then
    Exit;
  WorkText := Copy(WholeText, FoundPos + Length(BeforeText), Length(WholeText));
  FoundPos := Pos(AfterText, WorkText);
  if FoundPos = 0 then
    Exit;
  Result := Copy(WorkText, 1, FoundPos - 1);
  RemainingText := Copy(WorkText, FoundPos + Length(AfterText), Length(WorkText));
end;


{    Searches for a starting from defined position
     Function taken from StrUtils module   }
function PosEx(const SubStr, S: string; Offset: cardinal = 1): integer;
var
  I, X:           integer;
  Len, LenSubStr: integer;
begin
  if Offset = 1 then
    Result := Pos(SubStr, S)
  else
  begin
    I := Offset;
    LenSubStr := Length(SubStr);
    Len := Length(S) - LenSubStr + 1;
    while I <= Len do
    begin
      if S[I] = SubStr[1] then
      begin
        X := 1;
        while (X < LenSubStr) and (S[I + X] = SubStr[X + 1]) do
          Inc(X);
        if (X = LenSubStr) then
        begin
          Result := I;
          Exit;
        end;
      end;
      Inc(I);
    end;
    Result := 0;
  end;
end;


function TextBetweenTagsInc(WholeText, Tag: string): string;
var
  WorkText:                       string;
  BlockStart, BlockEnd, TagStart: integer;
begin
  Result := '';
  Tag := LowerCase(Tag);
  BlockStart := Pos('<' + Tag, LowerCase(WholeText));
  if BlockStart > 0 then
  begin
    BlockEnd := PosEx('</' + Tag, LowerCase(WholeText), BlockStart);
    if BlockEnd > 0 then
    begin
      TagStart := 1;
      while TagStart > 0 do
      begin
        WorkText := Copy(WholeText, BlockStart, BlockEnd - BlockStart + Length('</' + Tag) + 1);
        TagStart := PosEx('<' + Tag, LowerCase(WorkText), TagStart + 1);
        BlockEnd := PosEx('</' + Tag, LowerCase(WholeText), BlockEnd + 1);
      end;
      Result := WorkText;
    end;
  end;
end;

function TextBetweenTagsAttrInc(WholeText, Tag, AttrName, AttrValue: WideString): WideString;
var
  WorkText:                               WideString;
  BlockStart, BlockEnd, TagStart, TagEnd: integer;
begin
  Result := '';
  Tag := LowerCase(Tag);
  AttrName := LowerCase(AttrName);
  AttrValue := LowerCase(AttrValue);
  BlockStart := Pos('<' + Tag, LowerCase(WholeText));
  while BlockStart > 0 do
  begin
    TagEnd := PosEx('>', WholeText, BlockStart);
    WorkText := Copy(WholeText, BlockStart, TagEnd - BlockStart + 1);
    if (Pos(AttrName + '=' + AttrValue, LowerCase(WorkText)) > 0) or
      (Pos(AttrName + '="' + AttrValue + '"', LowerCase(WorkText)) > 0) or
      (Pos(AttrName + '=''' + AttrValue + '''', LowerCase(WorkText)) > 0) then
      break;
    BlockStart := PosEx('<' + Tag, LowerCase(WholeText), BlockStart + 1);
  end;

  if BlockStart > 0 then
  begin
    BlockEnd := PosEx('</' + Tag, LowerCase(WholeText), BlockStart);
    if BlockEnd > 0 then
    begin
      TagStart := 1;
      while TagStart > 0 do
      begin
        WorkText := Copy(WholeText, BlockStart, BlockEnd - BlockStart + Length('</' + Tag) + 1);
        TagStart := PosEx('<' + Tag, LowerCase(WorkText), TagStart + 1);
        BlockEnd := PosEx('</' + Tag, LowerCase(WholeText), BlockEnd + 1);
      end;
      Result := WorkText;
    end;
  end;
end;

function RemoveDuplicates(WholeText: WideString): WideString;
var
  DupBegin, DupEnd: integer;
  DupText:          WideString;
begin
  DupBegin := Pos('(', WholeText);
  while DupBegin > 0 do
  begin
    DupEnd := PosEx(')', WholeText, DupBegin);
    if DupEnd > 0 then
    begin
      DupText := Copy(WholeText, DupBegin, DupEnd - DupBegin + 1);
      if PosEx(DupText, WholeText, DupEnd) > 0 then
        Delete(WholeText, DupBegin, DupEnd - DupBegin + 2);
      DupBegin := PosEx('(', WholeText, DupBegin + 1);
    end
    else
      break;
  end;
  Result := WholeText;
end;

function ReplaceLink(WholeText: WideString): WideString;
var
  OpenTagStart, OpenTagEnd, CloseTagStart, LinkStart, LinkEnd: integer;
  LinkText: WideString;
begin
  OpenTagStart := Pos('<a', WholeText);
  while OpenTagStart > 0 do
  begin
    OpenTagEnd := PosEx('>', WholeText, OpenTagStart);
    CloseTagStart := PosEx('</a>', WholeText, OpenTagEnd);
    if (OpenTagEnd > 0) and (CloseTagStart > 0) then
    begin
      LinkText := Copy(WholeText, OpenTagStart, OpenTagEnd - OpenTagStart + 1);
      LinkStart := Pos('href=', LinkText) + 5;
      LinkEnd := LinkStart + 1;
      while ((LinkText[LinkEnd] <> ' ') or (LinkText[LinkEnd] <> '''') or (LinkText[LinkEnd] <> '"') or
          (LinkText[LinkEnd] <> '>')) and (LinkEnd <= Length(LinkText)) do
        Inc(LinkEnd);
      LinkText := Copy(LinkText, LinkStart, LinkEnd - LinkStart - 1);
      if (LinkText[1] = '"') or (LinkText[1] = '''') then
        LinkText := Copy(LinkText, 2, Length(LinkText) - 2);
      // fix id - remove leading backslash
      if (LinkText[1] = '/') then
        LinkText := Copy(LinkText, 2, Length(LinkText) - 1);
      Insert(' (' + PAnsiChar(vk_url) + '/' + LinkText + ')', WholeText, CloseTagStart + 4);
      Delete(WholeText, CloseTagStart, 4);
      Delete(WholeText, OpenTagStart, OpenTagEnd - OpenTagStart + 1);
    end
    else
      break;
    OpenTagStart := Pos('<a', WholeText);
  end;
  Result := Trim(WholeText);
end;

{    Searches for a partial text of one of the items of a TStringList
     Returns -1 if not found
     Function created by Antoine Potten   }
function FindLine(Pattern: string; List: TStringList; StartAt: integer): integer;
var
  i: integer;
begin
  Result := -1;
  if StartAt < 0 then
    StartAt := 0;
  for i := StartAt to List.Count - 1 do
    if Pos(Pattern, List.Strings[i]) <> 0 then
    begin
      Result := i;
      Break;
    end;
end;


{    Searches for a full text of one of the items of a TStringList
     Returns -1 if not found
     Function created by Antoine Potten  }
function FindFullLine(Line: string; List: TStringList; StartAt: integer): integer;
var
  i: integer;
begin
  Result := -1;
  if StartAt < 0 then
    StartAt := 0;
  for i := StartAt to List.Count - 1 do
    if Line = List.Strings[i] then
    begin
      Result := i;
      Break;
    end;
end;

{       Like the Pos function, but returns the last occurence instead of the first one
        Function created by Antoine Potten
}
function LastPos(ASearch: string; AText: string): integer;
var
  CurPos, PrevPos: integer;
begin
  PrevPos := 0;
  CurPos := Pos(ASearch, AText);
  while CurPos > 0 do
  begin
    if PrevPos = 0 then
      PrevPos := CurPos
    else
      PrevPos := PrevPos + CurPos + Length(ASearch) - 1;
    Delete(AText, 1, CurPos + Length(ASearch) - 1);
    CurPos := Pos(ASearch, AText);
  end;
  Result := PrevPos;
end;

function HTMLRemoveTags(const Value: WideString): WideString;
var
  i, Max: integer;
begin
  Result := '';
  Max := Length(Value);
  i := 1;
  while i <= Max do
  begin
    if Value[i] = '<' then
    begin
      repeat
        Inc(i);
      until (i > Max) or (Value[i - 1] = '>');
    end
    else
    begin
      Result := Result + Value[i];
      Inc(i);
    end;
  end;
end;

function HTMLDecode(const Value: string): string;
const
  Symbols: array [32..255] of string = (
    'nbsp', '', 'quot', '', '', '', 'amp', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    'lt', '', 'gt', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', 'iexcl', 'cent', 'pound', 'curren', 'yen', 'brvbar', 'sect', 'uml', 'copy',
    'ordf', 'laquo', 'not', 'shy', 'reg', 'macr', 'deg', 'plusmn', 'sup2', 'sup3',
    'acute', 'micro', 'para', 'middot', 'cedil', 'sup1', 'ordm', 'raquo', 'frac14', 'frac12',
    'frac34', 'iquest', 'Agrave', 'Aacute', 'Acirc', 'Atilde', 'Auml', 'Aring', 'AElig', 'Ccedil',
    'Egrave', 'Eacute', 'Ecirc', 'Euml', 'Igrave', 'Iacute', 'Icirc', 'Iuml', 'ETH', 'Ntilde',
    'Ograve', 'Oacute', 'Ocirc', 'Otilde', 'Ouml', 'times', 'Oslash', 'Ugrave', 'Uacute', 'Ucirc',
    'Uuml', 'Yacute', 'THORN', 'szlig', 'agrave', 'aacute', 'acirc', 'atilde', 'auml', 'aring',
    'aelig', 'ccedil', 'egrave', 'eacute', 'ecirc', 'euml', 'igrave', 'iacute', 'icirc', 'iuml',
    'eth', 'ntilde', 'ograve', 'oacute', 'ocirc', 'otilde', 'ouml', 'divide', 'oslash', 'ugrave',
    'uacute', 'ucirc', 'uuml', 'yacute', 'thorn', 'yuml'
    );
var
  i, Max, p1, p2: integer;
  Symbol:         string;
  SymbolLength:   integer;

  function IndexStr(const AText: string; const AValues: array of string): integer;
  var
    i: integer;
  begin
    Result := -1;
    for i := Low(AValues) to High(AValues) do
      if AText = AValues[i] then
      begin
        Result := i;
        Break;
      end;
  end;

begin
  Result := '';
  Max := Length(Value);
  i := 1;
  while i <= Max do
  begin
    if (Value[i] = '&') and (i + 1 < Max) then
    begin
      Symbol := copy(Value, i + 1, Max);
      p1 := Pos(' ', Symbol);
      p2 := Pos(';', Symbol);
      if (p2 > 0) and ((p2 < p1) xor (p1 = 0)) then
      begin
        Symbol := Copy(Symbol, 1, pos(';', Symbol) - 1);
        SymbolLength := Length(Symbol) + 1;
        if Symbol[1] <> '#' then
        begin
          Symbol := IntToStr(IndexStr(Symbol, Symbols) + 32);
        end
        else
          Delete(Symbol, 1, 1);
        Symbol := char(StrToIntDef(Symbol, 0));
        Result := Result + Symbol;
        Inc(i, SymbolLength);
      end
      else
        Result := Result + Value[i];
    end
    else
      Result := Result + Value[i];
    Inc(i);
  end;
end;


// GAP: doesn't work correctly?
function HTMLDecodeW(const Value: WideString): WideString;
const
  Symbols: array [32..255] of string = (
    'nbsp', '', 'quot', '', '', '', 'amp', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    'lt', '', 'gt', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', '', '', '', '', '', '', '', '', '',
    '', 'iexcl', 'cent', 'pound', 'curren', 'yen', 'brvbar', 'sect', 'uml', 'copy',
    'ordf', 'laquo', 'not', 'shy', 'reg', 'macr', 'deg', 'plusmn', 'sup2', 'sup3',
    'acute', 'micro', 'para', 'middot', 'cedil', 'sup1', 'ordm', 'raquo', 'frac14', 'frac12',
    'frac34', 'iquest', 'Agrave', 'Aacute', 'Acirc', 'Atilde', 'Auml', 'Aring', 'AElig', 'Ccedil',
    'Egrave', 'Eacute', 'Ecirc', 'Euml', 'Igrave', 'Iacute', 'Icirc', 'Iuml', 'ETH', 'Ntilde',
    'Ograve', 'Oacute', 'Ocirc', 'Otilde', 'Ouml', 'times', 'Oslash', 'Ugrave', 'Uacute', 'Ucirc',
    'Uuml', 'Yacute', 'THORN', 'szlig', 'agrave', 'aacute', 'acirc', 'atilde', 'auml', 'aring',
    'aelig', 'ccedil', 'egrave', 'eacute', 'ecirc', 'euml', 'igrave', 'iacute', 'icirc', 'iuml',
    'eth', 'ntilde', 'ograve', 'oacute', 'ocirc', 'otilde', 'ouml', 'divide', 'oslash', 'ugrave',
    'uacute', 'ucirc', 'uuml', 'yacute', 'thorn', 'yuml'
    );
var
  i, Max, p1, p2: integer;
  Symbol:         WideString;
  SymbolLength:   integer;

  function IndexStr(const AText: string; const AValues: array of string): integer;
  var
    i: integer;
  begin
    Result := -1;
    for i := Low(AValues) to High(AValues) do
      if AText = AValues[i] then
      begin
        Result := i;
        Break;
      end;
  end;

begin
  Result := '';
  Max := Length(Value);
  i := 1;
  while i <= Max do
  begin
    if (Value[i] = '&') and (i + 1 < Max) then
    begin
      Symbol := Copy(Value, i + 1, Max);
      p1 := Pos(' ', Symbol);
      p2 := Pos(';', Symbol);
      if (p2 > 0) and ((p2 < p1) xor (p1 = 0)) then
      begin
        Symbol := Copy(Symbol, 1, pos(';', Symbol) - 1);
        SymbolLength := Length(Symbol) + 1;
        if Symbol[1] <> '#' then
        begin
          Symbol := IntToStr(IndexStr(Symbol, Symbols) + 32);
        end
        else
          Delete(Symbol, 1, 1);
        Symbol := widechar(StrToIntDef(Symbol, 0));
        Result := Result + Symbol;
        Inc(i, SymbolLength);
      end
      else
        Result := Result + Value[i];
    end
    else
      Result := Result + Value[i];
    Inc(i);
  end;
end;

 // ****************************************************************************
 // URL encode function
 // ****************************************************************************
function URLEncode(const AStr: string): string;
const
  NoConversion = ['0'..'9', 'A'..'Z', 'a'..'z'];
var
  Sp, Rp: PChar;
begin
  SetLength(Result, Length(AStr) * 3);
  Sp := PChar(AStr);
  Rp := PChar(Result);
  while Sp^ <> #0 do
  begin
    if Sp^ in NoConversion then
      Rp^ := Sp^
    else
    begin
      FormatBuf(Rp^, 3, '%%%.2x', 6, [Ord(Sp^)]);
      Inc(Rp, 2);
    end;

    Inc(Rp);
    Inc(Sp);
  end;
  SetLength(Result, Rp - PChar(Result));
end;

 // ****************************************************************************
 // URL decode function
 // ****************************************************************************
function URLDecode(const AStr: string): string;
const
  HexChar = '0123456789ABCDEF';
var
  I, J: integer;
begin
  SetLength(Result, Length(AStr));
  I := 1;
  J := 1;
  while (I <= Length(AStr)) do
  begin
    if (AStr[I] = '%') and (I + 2 < Length(AStr)) then
    begin
      Result[J] := chr(((pred(Pos(AStr[I + 1], HexChar))) shl 4) or (pred(Pos(AStr[I + 2], HexChar))));
      Inc(I, 2);
    end
    else
      Result[J] := AStr[I];
    Inc(I);
    Inc(J);
  end;
  SetLength(Result, pred(J));
end;

{ **** UBPFD *********** by delphibase.endimus.com ****
>> ������� ������ � ������ ���� ��������� ����� ��������� �� ������
�����������: Windows, SysUtils
�����:       �������� ������, seregam@ua.fm, ICQ:162733776, ��������������
Copyright:   Sergey_M
����:        26 ��� 2003 �.
***************************************************** }

function Replace(Str, X, Y: string): string;
{Str - ������, � ������� ����� ������������� ������.
 X - ���������, ������� ������ ���� ��������.
 Y - ���������, �� ������� ����� ����������� ��������}
var
  buf1, buf2, buffer: string;
begin
  buf1 := '';
  buf2 := Str;
  Buffer := Str;

  while Pos(X, buf2) > 0 do
  begin
    buf2 := Copy(buf2, Pos(X, buf2), (Length(buf2) - Pos(X, buf2)) + 1);
    buf1 := Copy(Buffer, 1, Length(Buffer) - Length(buf2)) + Y;
    Delete(buf2, Pos(X, buf2), Length(X));
    Buffer := buf1 + buf2;
  end;

  Result := Buffer;
end;


function StringReplaceW(const S, OldPattern, NewPattern: WideString; Flags: TReplaceFlags): WideString;
var
  Srch, OldP, RemS: WideString; // Srch and Oldp can contain uppercase versions of S,OldPattern
  P:                integer;
begin
  Srch := S;
  OldP := OldPattern;
  if rfIgnoreCase in Flags then
  begin
    Srch := WideUpperCase(Srch);
    OldP := WideUpperCase(OldP);
  end;
  RemS := S;
  Result := '';
  while (Length(Srch) <> 0) do
  begin
    P := Pos(OldP, Srch);
    if P = 0 then
    begin
      Result := Result + RemS;
      Srch := '';
    end
    else
    begin
      Result := Result + Copy(RemS, 1, P - 1) + NewPattern;
      P := P + Length(OldP);
      RemS := Copy(RemS, P, Length(RemS) - P + 1);
      if not (rfReplaceAll in Flags) then
      begin
        Result := Result + RemS;
        Srch := '';
      end
      else
        Srch := Copy(Srch, P, Length(Srch) - P + 1);
    end;
  end;
end;


end.
