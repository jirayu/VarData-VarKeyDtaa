unit VarKeyData;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections, System.Variants, VarData;

type
  TVarKeyData = class(TVarDataStorage)
  private
    FKeyData: TDictionary<string, TVarDataStorage>;
    function GetValue(const AOuterKey, AInnerKey: string): Variant;
    procedure SetValue(const AOuterKey, AInnerKey: string; const ADataValue: Variant);
    function GetOrAddDataStorage(const AOuterKey: string): TVarDataStorage;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddKey(const AKey: string);
    function  FindKey(const AKey: string): Boolean;
    procedure SaveToFile(const AFileName: string);
    procedure LoadFromFile(const AFileName: string);
    function  SaveToString: string;
    procedure LoadFromString(const ADataString: string);
    function  KeyExists(const AKey: string): Boolean;
    function  GetAllKeys: TStringList;
    procedure DeleteKey(const AKey: string);
    // Two-level indexer:
    property Value[const OuterKey, InnerKey: string]: Variant read GetValue write SetValue; default;
  end;

var
  KeyData: TVarKeyData;

implementation

{ TVarKeyData }

constructor TVarKeyData.Create;
begin
  inherited Create;
  FKeyData := TDictionary<string, TVarDataStorage>.Create;
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
end;

procedure TVarKeyData.DeleteKey(const AKey: string);
var
  DataStorage: TVarDataStorage;
begin
  if FKeyData.TryGetValue(AKey, DataStorage) then
  begin
    FKeyData.Remove(AKey);
    DataStorage.Free;
  end;
end;

function TVarKeyData.FindKey(const AKey: string): Boolean;
begin
  Result := FKeyData.ContainsKey(AKey);
end;

function TVarKeyData.GetOrAddDataStorage(const AOuterKey: string): TVarDataStorage;
begin
  if not FKeyData.TryGetValue(AOuterKey, Result) then
  begin
    Result := TVarDataStorage.Create;
    FKeyData.Add(AOuterKey, Result);
  end;
end;

// Main two-level indexer (getter)
function TVarKeyData.GetValue(const AOuterKey, AInnerKey: string): Variant;
var
  DataStorage: TVarDataStorage;
begin
  if not FKeyData.TryGetValue(AOuterKey, DataStorage) then
    raise Exception.CreateFmt('Key "%s" does not exist.', [AOuterKey]);
  Result := DataStorage[AInnerKey];
end;

// Main two-level indexer (setter)
procedure TVarKeyData.SetValue(const AOuterKey, AInnerKey: string; const ADataValue: Variant);
var
  DataStorage: TVarDataStorage;
begin
  DataStorage := GetOrAddDataStorage(AOuterKey);
  DataStorage[AInnerKey] := ADataValue;
end;

function TVarKeyData.KeyExists(const AKey: string): Boolean;
begin
  Result := FKeyData.ContainsKey(AKey);
end;

function TVarKeyData.GetAllKeys: TStringList;
var
  Key: string;
  KeyList: TStringList;
begin
  KeyList := TStringList.Create;
  for Key in FKeyData.Keys do
    KeyList.Add(Key);
  Result := KeyList;
end;

// --- Serialization ---

procedure TVarKeyData.LoadFromString(const ADataString: string);
var
  Parts: TArray<string>;
  i: Integer;
  CurrentKey: string;
  DataStorage: TVarDataStorage;
begin
  for DataStorage in FKeyData.Values do
    DataStorage.Free;
  FKeyData.Clear;

  Parts := ADataString.Split(['|'], TStringSplitOptions.None);
  i := 0;
  CurrentKey := '';

  while i < Length(Parts) do
  begin
    if (Parts[i] <> '') and not FKeyData.ContainsKey(Parts[i]) then
    begin
      // New key
      CurrentKey := Parts[i];
      AddKey(CurrentKey);
      DataStorage := FKeyData[CurrentKey];
      Inc(i);
    end
    else if (CurrentKey <> '') and (i < Length(Parts)) then
    begin
      // Data line for current key
      DataStorage := FKeyData[CurrentKey];
      DataStorage.FromString(Parts[i]);
      Inc(i);
    end
    else
      Inc(i);
  end;
end;

function TVarKeyData.SaveToString: string;
var
  Parts: TStringList;
  PartsArray: TArray<string>;
  Key: string;
  DataStorage: TVarDataStorage;
  DataLines: TStringList;
  i: Integer;
begin
  Parts := TStringList.Create;
  try
    for Key in FKeyData.Keys do
    begin
      Parts.Add(Key);  // Add key marker
      if FKeyData.TryGetValue(Key, DataStorage) then
      begin
        DataLines := DataStorage.ToStringList;
        try
          Parts.AddStrings(DataLines);  // Add key's data pairs
        finally
          DataLines.Free;
        end;
      end;
    end;

    // Convert TStringList to TArray<string>
    SetLength(PartsArray, Parts.Count);
    for i := 0 to Parts.Count - 1 do
      PartsArray[i] := Parts[i];

    Result := String.Join('|', PartsArray);  // Now works with array
  finally
    Parts.Free;
  end;
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
        StringList.AddStrings(DataStorage.ToStringList);
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
  for DataStorage in FKeyData.Values do
    DataStorage.Free;
  FKeyData.Clear;

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

initialization
  KeyData := TVarKeyData.Create;

finalization
  KeyData.Free;

end.
