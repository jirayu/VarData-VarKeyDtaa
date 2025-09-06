# VarData-VarKeyDtaa
VarData and VarKeyData allows you to store a whole bunch of variant (any data type) by encapsulating Tdictionary
# VarKeyData - Hierarchical Data Storage for Delphi

## Overview

`TVarKeyData` is a Delphi component that provides hierarchical key-value data storage with file persistence. It extends the functionality of `TVarDataStorage` by adding a layer of named sections (keys), allowing you to organize related data under different categories or contexts.

## Why This Component Exists

The `TVarKeyData` component was created to solve the following problems:

1. **Organized Data Storage**: Need to store configuration, settings, or application data in logical groups
2. **Multiple Contexts**: Handle different sets of data that share the same structure but belong to different contexts (e.g., user profiles, application modules, different environments)
3. **File Persistence**: Save and load hierarchical data to/from files in a readable format
4. **Type-Safe Storage**: Store various data types (strings, integers, booleans, etc.) without explicit type conversion
5. **Easy Access Pattern**: Provide a simple API for setting a context and then working with data within that context

## Key Features

- **Hierarchical Storage**: Organize data in named sections/keys
- **Variant Support**: Store any variant-compatible data type
- **File Persistence**: Save/load data in a readable INI-like format
- **Context Management**: Set a current key and work within that context
- **Global Instance**: Provides a ready-to-use global `KeyData` instance
- **Exception Safety**: Proper error handling for invalid operations

## Installation

1. Ensure you have the `VarData` unit available (the base class dependency)
2. Add `VarKeyData` to your uses clause
3. The global `KeyData` instance is automatically created and destroyed

```pascal
uses
  VarKeyData;
```

## Basic Usage

### Setting Up Keys and Storing Data

```pascal
// Add or switch to a key (creates if doesn't exist)
KeyData.AddKey('UserSettings');

// Store various types of data
KeyData['Username'] := 'john_doe';
KeyData['MaxConnections'] := 10;
KeyData['EnableLogging'] := True;
KeyData['LastLogin'] := Now;

// Add another key for different context
KeyData.AddKey('DatabaseConfig');
KeyData['Server'] := 'localhost';
KeyData['Port'] := 5432;
KeyData['Database'] := 'myapp';
KeyData['Timeout'] := 30.0;
```

### Retrieving Data

```pascal
// Switch to the desired key
if KeyData.FindKey('UserSettings') then
begin
  ShowMessage('Username: ' + KeyData['Username']);
  ShowMessage('Max Connections: ' + IntToStr(KeyData['MaxConnections']));
  
  if KeyData['EnableLogging'] then
    ShowMessage('Logging is enabled');
end;
```

### Working with Multiple Keys

```pascal
var
  AllKeys: TStringList;
  i: Integer;
begin
  // Get all available keys
  AllKeys := KeyData.GetAllKeys;
  try
    for i := 0 to AllKeys.Count - 1 do
    begin
      WriteLn('Found key: ' + AllKeys[i]);
      
      // Switch to each key and display some data
      KeyData.FindKey(AllKeys[i]);
      // ... work with data in this key
    end;
  finally
    AllKeys.Free;
  end;
end;
```

## File Persistence

### Saving Data

```pascal
// Store data in multiple keys
KeyData.AddKey('Application');
KeyData['Version'] := '1.0.0';
KeyData['BuildDate'] := '2024-01-15';

KeyData.AddKey('Window');
KeyData['Width'] := 800;
KeyData['Height'] := 600;
KeyData['Maximized'] := False;

// Save to file
KeyData.SaveToFile('config.dat');
```

### Loading Data

```pascal
// Load data from file
KeyData.LoadFromFile('config.dat');

// Access loaded data
if KeyData.FindKey('Application') then
  ShowMessage('Version: ' + KeyData['Version']);

if KeyData.FindKey('Window') then
begin
  Form1.Width := KeyData['Width'];
  Form1.Height := KeyData['Height'];
end;
```

### File Format

The saved file uses a simple section-based format:

```ini
[Application]
Version=1.0.0
BuildDate=2024-01-15

[Window]
Width=800
Height=600
Maximized=False

[UserSettings]
Username=john_doe
MaxConnections=10
EnableLogging=True
```

## Advanced Usage Examples

### Configuration Manager Pattern

```pascal
type
  TConfigManager = class
  private
    FData: TVarKeyData;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure LoadUserProfile(const UserName: string);
    procedure SaveUserProfile;
    procedure LoadAppSettings;
    procedure SaveAppSettings;
    
    // Properties for easy access
    function GetUserSetting(const Setting: string): Variant;
    procedure SetUserSetting(const Setting: string; const Value: Variant);
  end;

constructor TConfigManager.Create;
begin
  FData := TVarKeyData.Create;
end;

procedure TConfigManager.LoadUserProfile(const UserName: string);
begin
  FData.LoadFromFile('profiles.dat');
  if not FData.FindKey(UserName) then
    FData.AddKey(UserName);
end;

function TConfigManager.GetUserSetting(const Setting: string): Variant;
begin
  Result := FData[Setting];
end;
```

### Multiple Environment Configuration

```pascal
procedure SetupEnvironments;
begin
  // Development environment
  KeyData.AddKey('Development');
  KeyData['DatabaseServer'] := 'dev-server';
  KeyData['LogLevel'] := 'DEBUG';
  KeyData['CacheEnabled'] := False;
  
  // Production environment
  KeyData.AddKey('Production');
  KeyData['DatabaseServer'] := 'prod-server';
  KeyData['LogLevel'] := 'ERROR';
  KeyData['CacheEnabled'] := True;
  
  // Test environment
  KeyData.AddKey('Testing');
  KeyData['DatabaseServer'] := 'test-server';
  KeyData['LogLevel'] := 'INFO';
  KeyData['CacheEnabled'] := True;
end;

procedure LoadEnvironment(const EnvName: string);
begin
  if KeyData.FindKey(EnvName) then
  begin
    // Configure application based on environment
    DatabaseConfig.Server := KeyData['DatabaseServer'];
    Logger.Level := KeyData['LogLevel'];
    Cache.Enabled := KeyData['CacheEnabled'];
  end
  else
    raise Exception.CreateFmt('Environment "%s" not found', [EnvName]);
end;
```

### Backup and Versioning

```pascal
procedure BackupConfiguration;
var
  BackupFileName: string;
begin
  BackupFileName := Format('config_backup_%s.dat', [FormatDateTime('yyyymmdd_hhnnss', Now)]);
  KeyData.SaveToFile(BackupFileName);
end;

procedure RestoreConfiguration(const BackupFile: string);
begin
  if FileExists(BackupFile) then
    KeyData.LoadFromFile(BackupFile)
  else
    raise Exception.CreateFmt('Backup file "%s" not found', [BackupFile]);
end;
```

## API Reference

### Methods

| Method | Description |
|--------|-------------|
| `AddKey(const AKey: string)` | Adds a new key or switches to existing key |
| `FindKey(const AKey: string): Boolean` | Finds and switches to a key, returns true if found |
| `KeyExists(const AKey: string): Boolean` | Checks if a key exists without switching to it |
| `GetAllKeys: TStringList` | Returns a list of all available keys |
| `SaveToFile(const AFileName: string)` | Saves all data to a file |
| `LoadFromFile(const AFileName: string)` | Loads data from a file |

### Properties

| Property | Description |
|----------|-------------|
| `Value[const ADataKey: string]: Variant` | Default property for getting/setting data values |

### Global Instance

The unit automatically creates a global `KeyData` instance that's ready to use:

```pascal
var
  KeyData: TVarKeyData;  // Automatically created and destroyed
```

## Error Handling

The component provides clear error messages for common mistakes:

```pascal
try
  // This will raise an exception if no current key is set
  KeyData['SomeValue'] := 'test';
except
  on E: Exception do
    ShowMessage(E.Message); // "No current key is set. Call AddKey or FindKey first."
end;

try
  // This will raise an exception if key doesn't exist
  KeyData.FindKey('NonExistentKey');
  KeyData['SomeValue'] := 'test';
except
  on E: Exception do
    ShowMessage(E.Message); // Key "NonExistentKey" does not exist. Call AddKey first.
end;
```

## Best Practices

1. **Always Set a Current Key**: Call `AddKey` or `FindKey` before accessing data
2. **Check Key Existence**: Use `KeyExists` or check `FindKey` return value when needed
3. **Handle Exceptions**: Wrap data access in try-except blocks for robust error handling
4. **Use Meaningful Key Names**: Choose descriptive names for your keys
5. **Regular Backups**: Save important configurations to files regularly
6. **Memory Management**: The global instance is managed automatically, but create your own instances when needed for specific use cases

## Dependencies

- `System.Classes`
- `System.SysUtils` 
- `System.Generics.Collections`
- `System.Variants`
- `VarData` (base class unit)

## Thread Safety

This component is **not thread-safe**. If you need to use it in a multi-threaded environment, implement your own synchronization mechanism or create separate instances per thread.

## License

[Add your license information here]

