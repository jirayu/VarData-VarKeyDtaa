unit VarData;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  System.Variants, System.SyncObjs, System.Rtti, System.TypInfo, DB,
  DBIsamTb, Streamer, Converse;

type
  TEachItem = procedure(const AKey: string; const AValue: Variant) of object;

  TVarDataStorage = class
  private
    FData: TDictionary<string, Variant>;
    FCriticalSection: TCriticalSection;
    function GetVarData(const AKey: string): Variant;
    procedure SetVarData(const AKey: string; const AValue: Variant);
    function GetDataString: String;
    procedure SetDataString(const ValueStr: String);
    function GetRawString: String;
    procedure SetRawString(const Value: String);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Each(AProc: TEachItem);
    function  InsertSQL(TableName: String): String;
    function  ToStringList:TStringList;
    procedure FromString(const AString: string);
    procedure ExecParam(Params: TDBIsamParams);
    procedure UpdateTo(Field: TMemoField);
    procedure LoadFrom(Field: TMemoField);
    procedure Keep(Dataset: TDataset);
    procedure SaveToStream(AStream: TStream);
    procedure LoadFromStream(AStream: TStream);
    property  Items[const AKey: string]: Variant read GetVarData write SetVarData; default;
    property  DataString: String read GetDataString write SetDataString;
    property  RawString: String read GetRawString write SetRawString;
  end;

var
  Data: TVarDataStorage;

implementation

{ TVarDataStorage }

constructor TVarDataStorage.Create;
begin
  inherited Create;
  FData := TDictionary<string, Variant>.Create;
  FCriticalSection := TCriticalSection.Create;
end;

destructor TVarDataStorage.Destroy;
begin
  FCriticalSection.Enter;
  try
    FData.Free;
    FCriticalSection.Free;
  finally
    FCriticalSection.Leave;
  end;
  inherited;
end;

procedure TVarDataStorage.Clear;
begin
  FCriticalSection.Enter;
  try
    FData.Clear;
  finally
    FCriticalSection.Leave;
  end;
end;

function TVarDataStorage.GetVarData(const AKey: string): Variant;
begin
  FCriticalSection.Enter;
  try
    if FData.ContainsKey(AKey) then
      Result := FData[AKey]
    else
      Result := Null;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TVarDataStorage.SetVarData(const AKey: string; const AValue: Variant);
begin
  FCriticalSection.Enter;
  try
    FData.AddOrSetValue(AKey, AValue);
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TVarDataStorage.Each(AProc: TEachItem);
var
  Key: string;
begin
  FCriticalSection.Enter;
  try
    for Key in FData.Keys do
    begin
      AProc(Key, FData[Key]);
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

function TVarDataStorage.GetDataString: String;
var
  Key: string;
  LStr: TStringBuilder;
begin
  LStr := TStringBuilder.Create;
  try
    FCriticalSection.Enter;
    try
      for Key in FData.Keys do
      begin
        LStr.AppendFormat('%s|%s'#149, [Key, VarToStr(FData[Key])]);
      end;
      Result := LStr.ToString;
    finally
      FCriticalSection.Leave;
    end;
  finally
    LStr.Free;
  end;
end;

procedure TVarDataStorage.SetDataString(const ValueStr: String);
var
  TokenPair, Key, ValueStrTemp: String;
  Value: Variant;
begin
  FCriticalSection.Enter;
  try
    FData.Clear;
    ValueStrTemp := ValueStr;
    repeat
      TokenPair := cvert.GetStr(ValueStrTemp, #149);
      if Trim(TokenPair) <> '' then
      begin
        Key := cvert.Before('|', TokenPair);
        Value := cvert.After('|', TokenPair);
        if (Trim(Key) <> '') then
          SetVarData(Key, Value);
      end;
    until TokenPair = '';
  finally
    FCriticalSection.Leave;
  end;
end;

function TVarDataStorage.InsertSQL(TableName: String): String;
var
  Fields, Params: TStringList;
  Key: string;
begin
  Fields := TStringList.Create;
  Params := TStringList.Create;
  try
    FCriticalSection.Enter;
    try
      for Key in FData.Keys do
      begin
        Fields.Add(Key);
        Params.Add(':' + Key);
      end;
      Result := Format('INSERT INTO %s (%s) VALUES (%s)', [TableName, Fields.CommaText, Params.CommaText]);
    finally
      FCriticalSection.Leave;
    end;
  finally
    Fields.Free;
    Params.Free;
  end;
end;

procedure TVarDataStorage.ExecParam(Params: TDBIsamParams);
var
  Key: string;
  Value: Variant;
begin
  FCriticalSection.Enter;
  try
    for Key in FData.Keys do
    begin
      Value := GetVarData(Key);
      if Params.FindParam(Key) <> nil then
        Params.ParamByName(Key).Value := Value;
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TVarDataStorage.UpdateTo(Field: TMemoField);
begin
  Field.AsString := DataString;
end;

procedure TVarDataStorage.LoadFrom(Field: TMemoField);
begin
  DataString := Field.AsString;
end;

procedure TVarDataStorage.Keep(Dataset: TDataset);
var
  F: TField;
  BlobData: TBytes;
begin
  FCriticalSection.Enter;
  try
    for F in Dataset.Fields do
    begin
      if not F.IsNull then
      begin
        case F.DataType of
          ftString, ftWideString, ftMemo, ftWideMemo:
            Items[F.FieldName] := F.AsString;

          ftDate, ftDatetime:
            Items[F.FieldName] := F.AsDateTime;

          ftFloat, ftCurrency:
            Items[F.FieldName] := F.AsFloat;

          ftInteger, ftSmallint, ftLargeint:
            Items[F.FieldName] := F.AsInteger;

          ftBoolean:
            Items[F.FieldName] := F.AsBoolean;

          ftBlob, ftGraphic, ftTypedBinary:
            begin
              BlobData := TBlobField(F).AsBytes;
              Items[F.FieldName] := BlobData;
            end;

          else
            Items[F.FieldName] := F.Value;  // Fallback to variant handling
        end;
      end
      else
      begin
        case F.DataType of
          ftString, ftWideString, ftMemo, ftWideMemo:
            Items[F.FieldName] := '';

          ftDate, ftDatetime:
            Items[F.FieldName] := 0; // Default date value

          ftFloat, ftCurrency:
            Items[F.FieldName] := 0.0;

          ftInteger, ftSmallint, ftLargeint:
            Items[F.FieldName] := 0;

          ftBoolean:
            Items[F.FieldName] := False;

          ftBlob, ftGraphic, ftTypedBinary:
            Items[F.FieldName] := Null; // Handle null blobs as empty

        end;
      end;
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TVarDataStorage.SaveToStream(AStream: TStream);
var
  Key: string;
  KeyLen: Integer;
  ValueStr: string;
begin
  FCriticalSection.Enter;
  try
    for Key in FData.Keys do
    begin
      ValueStr := VarToStr(FData[Key]);

      KeyLen := Length(Key);
      AStream.WriteBuffer(KeyLen, SizeOf(KeyLen));
      AStream.WriteBuffer(PChar(Key)^, KeyLen * SizeOf(Char));

      AStream.WriteBuffer(PChar(ValueStr)^, Length(ValueStr) * SizeOf(Char));
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TVarDataStorage.LoadFromStream(AStream: TStream);
var
  Key: string;
  Value: string;
  KeyLen: Integer;
begin
  FCriticalSection.Enter;
  try
    FData.Clear;
    while AStream.Position < AStream.Size do
    begin
      AStream.ReadBuffer(KeyLen, SizeOf(KeyLen));
      SetLength(Key, KeyLen);
      AStream.ReadBuffer(PChar(Key)^, KeyLen * SizeOf(Char));

      SetLength(Value, AStream.Size - AStream.Position);
      AStream.ReadBuffer(PChar(Value)^, Length(Value) * SizeOf(Char));

      SetVarData(Key, Value);
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

function TVarDataStorage.GetRawString: String;
var
  Mem: TMemoryStream;
begin
  Mem := TMemoryStream.Create;
  try
    SaveToStream(Mem);
    Mem.Position := 0;
    Result := Stmr.StreamToString(Mem);
  finally
    Mem.Free;
  end;
end;

procedure TVarDataStorage.SetRawString(const Value: String);
var
  Mem: TMemoryStream;
begin
  Mem := TMemoryStream.Create;
  try
    Stmr.StringToStream(Value, Mem);
    Mem.Position := 0;
    LoadFromStream(Mem);
  finally
    Mem.Free;
  end;
end;

function TVarDataStorage.ToStringList: TStringList;
var
  StringList: TStringList;
  DataKey: string;
begin
  StringList := TStringList.Create;
  try
    for DataKey in FData.Keys do
      StringList.Add(DataKey + '=' + VarToStr(FData[DataKey]));  // Convert each key-value pair to string
  except
    StringList.Free;
    raise;
  end;
  Result := StringList;
end;

procedure TVarDataStorage.FromString(const AString: string);
var
  SplitPos: Integer;
  DataKey, Value: string;
begin
  SplitPos := Pos('=', AString);
  if SplitPos > 0 then
  begin
    DataKey := Copy(AString, 1, SplitPos - 1);
    Value := Copy(AString, SplitPos + 1, Length(AString));
    FData.AddOrSetValue(DataKey, Value);  // Store the key-value pair in the dictionary
  end;
end;

initialization
  Data := TVarDataStorage.Create;

finalization
  Data.Free;

end.

