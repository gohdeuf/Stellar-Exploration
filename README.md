## 📦 Git LFS Availability / Verfügbarkeit

This repository uses a self-hosted Git LFS server for 3D models and large assets. To save energy, the LFS storage server automatically shuts down during the night. 

If your `git clone` or `git lfs pull` fails with a connection error, please try again during the active operating hours.

| Day / Tag | Operating Hours / Online-Zeiten (CEST/CET) | Status |
| :--- | :--- | :--- |
| **Sunday – Friday** / Sonntag – Freitag | 07:00 – 23:00 | Online |
| **Saturday** / Samstag | 07:00 – 01:00 (Next day) | Online |
| **Nightly** / Jede Nacht | *Off-hours* | Offline (Power Saving) |

*Note: The source code on GitHub is always available 24/7. Only the download of large LFS files depends on these hours.*

# Star Trek Sandbox – Godot-Rewrite (v0.2.0)

Engine-Version: Godot **4.3+** (GDScript).

## Projekt oeffnen

1. Godot 4.3 oder neuer starten.
2. "Import" -> Ordner `StarTrekSandbox` (mit `project.godot`) auswaehlen.
3. Play druecken (F5) -> startet `scenes/Main.tscn`.

## Neue Features (v0.2.0)

### Waffensystem (F / T / X)
- **F (halten):** Partikel-Strahl-Emitter (PSE) – kontinuierlicher Energiestrahl, trifft NPCs in 250 Einheiten
- **T:** Torpedo abfeuern (Kaskaden- oder Antimaterie-Torpedo, je nach aktiver Waffe)
- **X:** Waffe wechseln: PSE → Kaskaden-Torpedo → Antimaterie-Torpedo
- Antimaterie-Torpedos kosten 50 Antimaterie-Einheiten (Startbestand: 50)
- NPC-Schiffe haben 200 HP und explodieren bei 0

### Alcubierre-Metrik-Antrieb (J)
- **J:** Warpantrieb ein-/ausschalten
- Aktivierung kostet 100 Deuterium, laufender Verbrauch 20/Sek
- 100× Schiffsgeschwindigkeit (15.000 Einheiten/Sek), kein Manövrieren möglich
- Visueller Effekt: animierter Torus-Ringtunnel
- Bei leerem Deuterium automatische Notabschaltung

### Stations-Docking (K)
- **K** in Stationsnähe (< 20 Einheiten): Tween richtet Schiff butterweich aus
- Andockzustand persistent in `world_meta.json`
- Erneut **K** drücken zum Ablegen

### Crew-System & Notfall-KI (N)
- **N:** Notfall-KI manuell ein-/ausschalten (zum Testen)
- Bei aktiver KI: Schiff flieht automatisch vom nächsten NPC-Schiff
- Bridge-Zustand (Normal/Beschädigt/Zerstört) beeinflusst Schiffsgeschwindigkeit
- Wird beim echten Kampfschaden automatisch ausgelöst

### Boost (Shift)
- Shift beim Fliegen: 3× Schiffsgeschwindigkeit (funktioniert nun auch beim Spielerschiff)

## Steuerung (vollständig)

| Taste | Funktion |
|-------|----------|
| W/A/S/D | Bewegen |
| Pfeiltasten | Pitch/Yaw |
| Q/E | Roll |
| Leertaste/Strg | Hoch/Runter |
| Shift | Boost (3×) |
| F (halten) | PSE-Strahl |
| T | Torpedo |
| X | Waffe wechseln |
| J | Alcubierre-Antrieb |
| K | Andocken/Ablegen |
| N | Notfall-KI |
| B | Station bauen |
| M (halten) | Ressourcen abbauen |
| Tab | Galaxiekarte |
| F10 | Freie Kamera |
| Shift+L | Sprache wechseln |
| Esc | Beenden (speichert) |


## Lua-Schnittstellen fuer Schiffs-Systeme

Die System-API ist als oeffentliche GDScript-Schnittstelle am `Ship` vorhanden
und kann aus Lua ueber eine Referenz auf den Spieler-Node aufgerufen werden.
Das Projekt legt aktuell keine globale Lua-Variable namens `ship` an. Ein Lua-
Controller muss diese Referenz beim Start erhalten oder selbst aus dem Szenen-
Baum beziehen.

Lua verwendet fuer Godot-Methoden den ueblichen Doppelpunkt-Aufruf:

```lua
ship:set_engine_power(0.75)
local status = ship:get_engine_status()
```

### Impulsantrieb

```lua
ship:set_engine_enabled(true)
ship:set_engine_power(1.0) -- Werte von 0.0 bis 1.0

local engine = ship:get_engine_status()
-- engine.enabled, engine.power, engine.speed
```

`set_engine_power(0.0)` stoppt den normalen Impulsflug. Warp wird separat
gesteuert. Der normale Ressourcenverbrauch des Spiels bleibt aktiv.

### Warp-Antrieb

```lua
local warp_active = ship:set_warp_enabled(true)
ship:set_warp_enabled(false)
ship:toggle_warp()

local warp = ship:get_warp_status()
-- warp.active
```

Das Aktivieren verwendet weiterhin die vorhandenen Deuterium- und
Antimaterie-Kosten. Bei fehlenden Ressourcen wird Warp nicht aktiviert.

### Waffen

```lua
-- 0 = PSE, 1 = Kaskaden-Torpedo, 2 = Antimaterie-Torpedo
ship:select_weapon(0)
ship:cycle_weapon(1)
ship:fire_weapon() -- Torpedo als Einzelaktion; PSE startet einen Schusszyklus

local weapons = ship:get_node("WeaponSystem")
weapons:set_primary_fire(true)  -- PSE-Dauerfeuer an
weapons:set_primary_fire(false) -- PSE-Dauerfeuer aus

local weapon = ship:get_weapon_status()
-- weapon.weapon: 0, 1 oder 2
```

Antimaterie-Torpedos verbrauchen weiterhin die bestehende Menge von 50
Antimaterie pro Schuss. Die Torpedo-Abklingzeit wird ebenfalls eingehalten.

### Schilde und Huelle

```lua
ship:set_shield_enabled(true)
ship:set_shield_enabled(false)

local shields = ship:get_shield_status()
-- shields.active, shields.integrity, shields.max_integrity

local hull = ship:get_hull_status()
-- hull.health, hull.max_health
```

### Beispiel: einfacher KI-Zyklus

```lua
function control_ship(ship)
  local warp = ship:get_warp_status()
  local engine = ship:get_engine_status()
  local shields = ship:get_shield_status()

  if engine.speed < 50.0 then
    ship:set_engine_power(1.0)
  end

  if not shields.active or shields.integrity < 25.0 then
    ship:set_shield_enabled(true)
  end

  if not warp.active then
    ship:set_warp_enabled(true)
  end
end
```

## Projektstruktur

```
project.godot
data/locale/          de.json, en.json
scripts/
  autoload/           Locale, GameDatabase, SectorUtils, StarNames,
                      PlanetClassDB, SectorGenerator, InputSetup
  camera/             CameraRig
  entities/           Ship, Star, Planet, Moon, Station, NPCShip, Torpedo
  main/               Main, PlayerActions
  systems/            WeaponSystem, WarpDrive, DockingSystem, CrewSystem  [NEU]
  ui/                 GalaxyMap, HelpOverlay, InventoryHUD, SOINotification,
                      BridgeDirectionIndicator, TouchControls, TouchJoystick,
                      WorldSeedDialog
  world/              WorldManager, SOITracker
  station/            station_connecter_1
scenes/               Minimal-Szenen (.tscn Stubs)
```
## Lizenz

Dieses Projekt ist unter der **GNU General Public License Version 3 (GPLv3)** lizenziert. 

Alle Quelltexte sowie alle im Projekt enthaltenen Medien (Bilder, Grafiken, Töne und Animationen) wurden selbst erstellt und unterliegen ebenfalls den Bedingungen dieser Lizenz. Weitere Details findest du in der Datei [LICENSE](LICENSE).
