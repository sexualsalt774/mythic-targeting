# ox_target → mythic-targeting Bridge

Drop-in compatibility shim that lets resources written for **ox_target** work
directly with **mythic-targeting** without any code changes.

---

## Installation (drag and drop)

## Manual Installation (For Edited mythic-targeting Versions)
If you are running a custom/modified version of mythic-targeting and do not want to replace it entirely:
1. Copy `client/compat/ox_target.lua` into your `mythic-targeting` resource at
   the path `client/compat/ox_target.lua`.

2. Replace your existing `fxmanifest.lua` with the one provided here
   (or manually apply the two changes below).

### Manual fxmanifest changes

Add the compat file to `client_scripts`:

```lua
client_scripts {
    -- ... existing entries ...
    'client/compat/ox_target.lua',  -- ox_target bridge
}
```

Add the `provide` directive below the script block:

```lua
provide 'ox_target'
```

The `provide` line is what makes FiveM resolve any resource that declares
`dependency 'ox_target'` to your mythic-targeting instance automatically.

---

## What is bridged

| ox_target export         | mythic-targeting equivalent                    |
|--------------------------|------------------------------------------------|
| `addBoxZone`             | `TARGETING.Zones:AddBox`                       |
| `addSphereZone`          | `TARGETING.Zones:AddCircle`                    |
| `addPolyZone`            | `TARGETING.Zones:AddPoly`                      |
| `removeZone`             | `TARGETING.Zones:RemoveZone`                   |
| `zoneExists`             | `InteractionZones[name] ~= nil`                |
| `addModel`               | `TARGETING:AddObject`                          |
| `removeModel`            | `TARGETING:RemoveObject`                       |
| `addEntity`              | `TARGETING:AddEntity` (via network id)         |
| `removeEntity`           | `TARGETING:RemoveEntity`                       |
| `addLocalEntity`         | `TARGETING:AddEntity` (local entity handle)    |
| `removeLocalEntity`      | `TARGETING:RemoveEntity`                       |
| `addGlobalPed`           | `TARGETING:AddGlobalPed`                       |
| `addGlobalVehicle`       | Appends to `Config.VehicleMenu`                |
| `removeGlobalVehicle`    | Removes from `Config.VehicleMenu` by label     |
| `addGlobalPlayer`        | Appends to `Config.PlayerMenu`                 |
| `removeGlobalPlayer`     | Removes from `Config.PlayerMenu` by label      |
| `disableTargeting`       | Toggles `IS_SPAWNED`                           |
| `isActive`               | Returns `InTargetingMenu`                      |

### Option field mapping

| ox_target field  | mythic-targeting field     |
|------------------|----------------------------|
| `label`          | `text`                     |
| `icon`           | `icon`                     |
| `distance`       | `minDist`                  |
| `onSelect`       | Bridged through an event   |
| `event`          | `event`                    |
| `serverEvent`    | Wrapped as a server trigger|
| `command`        | Wrapped as ExecuteCommand  |
| `groups`         | `jobPerms`                 |
| `items` (string) | `item`                     |
| `items` (table)  | `items`                    |
| `canInteract`    | `isEnabled`                |

---

## Known limitations

- **`addGlobalObject`** — mythic-targeting has no global-object intercept.
  Register specific model hashes with `addModel` / `exports.ox_target:addModel`
  instead.
- **Bone targeting** (`bones` field on options) is not supported by
  mythic-targeting and is silently ignored.
- **`removeGlobalPed`** without an index is a no-op. Track the return value of
  `addGlobalPed` if you need precise removal.
- The `provide 'ox_target'` directive only resolves *dependency* declarations.
  Resources that check for the ox_target resource *by name* at runtime may
  still need minor adjustments.
