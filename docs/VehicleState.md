Source: https://openplanet.dev/docs/reference/vehiclestate

# VehicleState dependency plugin

Provided by `openplanet-nl/vehiclestate` (https://github.com/openplanet-nl/vehiclestate).
`essential = true`, ships with Openplanet — declare:

```
[script]
dependencies = [ "VehicleState" ]
```

Telestrator uses this to sample the controlled car's altitude at click time, so world
anchors land on the ground plane the car is currently on.

## Functions used

```
CSceneVehicleVisState@ ViewingPlayerState()
```
Returns the vis state of whichever vehicle is currently being viewed (drives, replays,
spectator). Null when no vehicle is viewable. Telestrator only reads `.Position` (vec3).

Source: https://raw.githubusercontent.com/openplanet-nl/vehiclestate/master/Export.as

## CSceneVehicleVisState (engine type, TM2020)

Reference: https://next.openplanet.dev/Scene/CSceneVehicleVisState

Fields used by Telestrator:

```
vec3 Position;
```

The reference page also exposes `Left`, `Up`, `Dir` (basis vectors), `WorldVel`,
`Location` (iso4) and many more — none currently used here.
