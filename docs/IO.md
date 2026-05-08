Source: https://openplanet.dev/docs/api/IO

# IO namespace

## Storage path helper

```
string IO::FromStorageFolder(const string&in filename)
```
Gets the absolute path for a file in your plugin's storage folder. The per-plugin storage folder is auto-created on first call, so explicit `FolderExists` / `CreateFolder` checks are not required before using the returned path.

## Existence checks

```
bool IO::FileExists(const string&in filename)
```
Checks if the given path exists. Used to gate `Json::FromFile` so first-run loads don't error.

```
bool IO::FolderExists(const string&in path)
```
Checks if the given path exists. (Not currently used by Telestrator — `FromStorageFolder` makes it unnecessary — but included here for completeness.)

## Folder creation

```
void IO::CreateFolder(const string&in path, bool recursive = true)
```
Creates a folder at the given location. (Not currently used by Telestrator. Listed for completeness.)
