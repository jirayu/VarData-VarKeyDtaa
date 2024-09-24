unit VarKeyData;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections, System.Variants, VarData;

type
  TVarKeyData = class(TVarDataStorage)
  private
    FKeyData: TDictionary<string, TVarDataStorage>;
    FCurrentKey: string;
    function GetValue(const ADataKey: string): Variant;
    procedure SetValue(const ADataKey: string; const ADataValue: Variant);
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddKey(const AKey: string);
    function  FindKey(const AKey: string): Boolean;
    procedure SaveToFile(const AFileName: string);
    procedure LoadFromFile(const AFileName: string);
    function  KeyExists(const AKey: string): Boolean;
    function  GetAllKeys: TStringList;
    property  Value[const ADataKey: string]: Variant read GetValue write SetValue; default;
  end;

var
  KeyData:TVarKeyData;

implementation

constructor TVarKeyData.Create;
begin
  inherited Create;
  FKeyData := TDictionary<string, TVarDataStorage>.Create;
  FCurrentKey := '';
end;

destructor TVarKeyData.Destroy;
var
  DataStorage: TVarDataStorage;
begin
  for DataStorage in FKeyData.Values do
    DataStorage.Free;
  FKeyData.Free;
  inherited Destroy;
end;

procedure TVarKeyData.AddKey(const AKey: string);
begin
  if not FKeyData.ContainsKey(AKey) then
    FKeyData.Add(AKey, TVarDataStorage.Create);
  FCurrentKey := AKey;
end;

function TVarKeyData.FindKey(const AKey: string): Boolean;
begin
  Result := FKeyData.ContainsKey(AKey);
  if Result then
    FCurrentKey := AKey;
end;

function TVarKeyData.GetValue(const ADataKey: string): Variant;
var
  DataStorage: TVarDataStorage;
begin
  if FCurrentKey = '' then
    raise Exception.Create('No current key is set. Call AddKey or FindKey first.');
  if not FKeyData.TryGetValue(FCurrentKey, DataStorage) then
    raise Exception.CreateFmt('Key "%s" does not exist. Call AddKey first.', [FCurrentKey]);
  Result := DataStorage[ADataKey];
end;

procedure TVarKeyData.SetValue(const ADataKey: string; const ADataValue: Variant);
var
  DataStorage: TVarDataStorage;
begin
  if FCurrentKey = '' then
    raise Exception.Create('No current key is set. Call AddKey or FindKey first.');
  if not FKeyData.TryGetValue(FCurrentKey, DataStorage) then
    raise Exception.CreateFmt('Key "%s" does not exist. Call AddKey first.', [FCurrentKey]);

  DataStorage[ADataKey] := ADataValue;
end;

function TVarKeyData.KeyExists(const AKey: string): Boolean;
begin
  Result := FKeyData.ContainsKey(AKey);
end;

procedure TVarKeyData.SaveToFile(const AFileName: string);
var
  StringList: TStringList;
  Key: string;
  DataStorage: TVarDataStorage;
begin
  StringList := TStringList.Create;
  try
    for Key in FKeyData.Keys do
    begin
      StringList.Add('[' + Key + ']');
      if FKeyData.TryGetValue(Key, DataStorage) then
      begin
        StringList.AddStrings(DataStorage.ToStringList);  // Now, ToStringList is defined
      end;
      StringList.Add('');
    end;
    StringList.SaveToFile(AFileName);
  finally
    StringList.Free;
  end;
end;


procedure TVarKeyData.LoadFromFile(const AFileName: string);
var
  StringList: TStringList;
  Line, Key: string;
  DataStorage: TVarDataStorage;
  i: Integer;
begin
  StringList := TStringList.Create;
  try
    StringList.LoadFromFile(AFileName);
    DataStorage := nil;
    for i := 0 to StringList.Count - 1 do
    begin
      Line := Trim(StringList[i]);
      if (Line <> '') and (Line[1] = '[') and (Line[Length(Line)] = ']') then
      begin
        Key := Copy(Line, 2, Length(Line) - 2);
        AddKey(Key);
        DataStorage := FKeyData[Key];
      end
      else if DataStorage <> nil then
      begin
        DataStorage.FromString(Line);
      end;
    end;
  finally
    StringList.Free;
  end;
end;

function TVarKeyData.GetAllKeys: TStringList;
var
  Key: string;
  KeyList: TStringList;
begin
  KeyList := TStringList.Create;
  try
    for Key in FKeyData.Keys do
    begin
      KeyList.Add(Key);
    end;
    Result := KeyList;
  except
    KeyList.Free;
    raise;
  end;
end;

initialization
  KeyData := TVarKeyData.Create;

finalization
  KeyData.Free;

end.

