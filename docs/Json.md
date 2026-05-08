Source: https://openplanet.dev/docs/api/Json

# Json namespace

## Top-level functions

```
Value@ Json::Object()
```
Create a new Json object value.

```
Value@ Json::Array()
```
Create a new Json array value.

```
Value@ Json::FromFile(const string&in filename)
```
Deserialize file contents (from disk or plugin hierarchy) into a Json value tree.

```
void Json::ToFile(const string&in filename, const Value@ value, bool pretty = false)
```
Serialize a Json value tree to a file.

## Json::Value

Source: https://openplanet.dev/docs/api/Json/Value

Constructors (verified out-of-band; not currently shown on the public docs page):

```
Json::Value()
Json::Value(const ?&in)
```
The templated constructor accepts any primitive (`int`, `float`, `double`, `bool`, `string`) and wraps it as a leaf value.

Methods, properties, and operators:

```
bool HasKey(const string&in key) const
```
Returns true if this object contains the given key. Only meaningful for `Json::Type::Object`.

```
Json::Type GetType() const
```
Returns the variant type of this value. See `Json::Type` below.

```
void Add(Json::Value@)
```
Appends a value to an array. Only meaningful for `Json::Type::Array`.

```
uint get_Length() const
```
Property exposed as `.Length` — element count for arrays/objects.

```
Json::Value@ opIndex(const string&in)
Json::Value@ opIndex(int)
```
Subscript operator. Use the string overload for objects (`obj["key"]`) and the int overload for arrays (`arr[i]`).

```
string opImplConv() const
int opImplConv() const
float opImplConv() const
double opImplConv() const
bool opImplConv() const
```
Implicit conversions from a `Json::Value` leaf to a primitive. Cast explicitly when AngelScript needs a hint, e.g. `string(obj["text"])`, `float(obj["thickness"])`.

```
Json::Value@ opAssign(const Json::Value&in)
```
Assignment operator. Used implicitly in expressions like `obj["key"] = someValue`.

## Json::Type

Source: https://openplanet.dev/docs/api/Json/Type

Members used by Telestrator:

| Member | Value |
| --- | --- |
| `Json::Type::Object` | 3 |
| `Json::Type::Array` | 4 |

(The full enum has additional variants for `Null`, `Boolean`, `Number`, `String`, but Telestrator only branches on Object/Array.)
