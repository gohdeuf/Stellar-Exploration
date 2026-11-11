# Design-Dokument: Spielmechaniken & Systemarchitektur

## 1. Schild- & Plasma-Physik

### Schild-Belastung & Tesla-Grenzen
* **Maximale Feldstärke:** Ein Schildgenerator ist auf eine feste maximale Flussdichte (z. B. **10 Tesla**) ausgelegt, um das Plasma stabil einzuzäunen.
* **Traktorstrahl-Überwindung:** Übersteigt ein externer Traktorstrahl oder ein feindliches Magnetfeld diese Schwelle (> 10 Tesla), bricht die Stabilität des Schildes zusammen. Das eingeschlossene Plasma wird direkt gegen die eigene Schiffshülle gedrückt und beschädigt das Schiff.
* **Energie- & Upgrade-Dilemma:** Höhere Tesla-Kapazitäten erfordern stärkere Generatoren und verbrauchen signifikant mehr Fusionsenergie.

### Schussfenster & Sektor-Abschaltung (Firing Windows)
* **Reziprozität von Schilden:** Energieschilde blockieren ausgehende Strahlung und Objekte genauso wie eingehende.
* **Richtungsgebundene Abschaltung:** Beim Abfeuern von Strahlenwaffen (Laser, Plasma, Mikrowellen) oder Torpedos muss der Schild im entsprechenden Sektor für wenige Millisekunden moduliert oder deaktiviert werden.
* **Gefahrenfenster:** Während des Schussvorgangs ist der jeweilige Sektor ungeschützt gegen feindlichen Konterbeschuss.

### Torpedo-Spezifikationen
* **Flächenbedarf:** Torpedos benötigen im Gegensatz zu schmalen Lasern die Abschaltung einer großen Plasmaregion.
* **Fehlzündung (Friendly Fire):** Waffenauslösung bei unvollständig geöffnetem Schild führt zur Detonation des Torpedos im eigenen Torpedoschacht.

---

## 2. Automatisierung & Subsystem-Ausfälle

### Leitcomputer-Steuerung
* **Normalbetrieb:** Der Prozess-Leitcomputer steuert das schusssynchrone Öffnen und Schließen der Schilde milisekunden genaue.
* **Systemausfall:** Bei Beschuss, EMP oder Sabotage fällt der Leitcomputer aus.
* **Konsequenzen:**
  * Automatische Schussfenster entfallen.
  * Blindes Feuern führt zur Selbstzerstörung durch Schild-Kollision.
  * Notbetrieb erfordert manuelle Steuerung oder redundante Backupsysteme.

### Technische Umsetzung (GDScript vs. LuaJIT)
* **GDScript (Core-Systeme):** Verarbeitung performancekritischer Systemzustände, Schadensberechnungen und direkter Godot-Node-Logik.
* **LuaJIT (Missions- & Event-Skripte):** Dynamische Triggerung von Systemausfällen, Sabotage-Szenarien und KI-Verhalten.

---

## 3. Tarntechnik & Detektion

### Emissions-Maskierung & Bomben-Tarnung
* **Funktionsweise:** Fortgeschrittene Tarnfelder leiten Strahlung und Licht um Objekte herum, um Emissionen einzukapseln.
* **Einfache Stufe:** Hohe Signatur, über Entfernungen von bis zu 1 Parsec von Long-Range-Sensoren lesbar.
* **Fortgeschrittene Stufe:** Reduzierung des Detektionsradius auf **1 km**.

### Grenz-Sensorstationen
* **Sicherheitszonen:**
  * **Kernwelten:** Fokus auf Handel und Forschung; Sensoren auf Nahbereich optimiert.
  * **Grenzstationen:** Spezialisierte Überwachungsplattformen mit extrem hohem Energieverbrauch.
* **Detektions-Mechanik:**
  * 25-fach erhöhte Erkennungsleistung gegenüber Standard-Sensoren.
  * **25% Wahrscheinlichkeit**, getarnte Objekte im Toleranzbereich von $\pm 1\text{ km}$ entlang des Sensorgitters zu identifizieren.
  * Hohe Betriebskosten erzwingen taktische Lücken im Überwachungsnetz.

---

## 4. Maßstab, begehbare Innenräume & Beamen (Planung v0.4.0)

### Spielgröße & Speicherbedarf
* **Zielgröße:** Ca. **1 GB**.
* **Begründung:** Bietet Platz für detaillierte, vollständig begehbare Innenräume für jedes Schiff und jede Station.
* **Planeten-Generierung:** Prozedural aus dem Universums-Seed, wodurch das Spiel trotz nahtloser Planetenlandungen kompakt bleibt.

### Nahtlose Übergänge (v0.4.0)
* Kontinuierlicher Flug vom Weltraum/Orbit bis auf die Planetenoberfläche ohne Ladebildschirme.

### Beamer-Mechanik (Teleportation)
* **Voraussetzung:** Schilde müssen für die Dauer des Beam-Vorgangs **vollständig offline** sein.
* **Physikalische Ursache:** Der Partikel-/Energiestrom des Beamers wird durch das 10+ Tesla Plasmafeld zerstört oder reflektiert.
* **Taktisches Risiko:** Maximale Verwundbarkeit des Schiffs während des Beamens von Personal oder Fracht.

---

## 5. Prozedurales Seed-System (FNV-1a)

### Seed-Berechnung für Planeten
Um aus dem globalen Universums-Seed blitzschnell und deterministisch individuelle Planeten-Seeds zu erzeugen, wird der **64-Bit FNV-1a (Fowler–Noll–Vo)** Hash-Algorithmus genutzt.

### Eigenschaften von FNV-1a
* **Geschwindigkeit:** Extrem schnell, perfekt für Echtzeit-Generierung während des Flugs.
* **Unabhängigkeit:** Keine externen Bibliotheken notwendig, sehr leicht in C++, GDScript und Lua implementierbar.

### Code-Beispiele

#### GDScript (Godot Engine Core)
```gdscript
func generate_planet_seed(universe_seed: int, pos_x: int, pos_y: int, pos_z: int, planet_index: int) -> int:
	var hash_val: int = -3750763034362895579 # FNV 64-bit offset basis
	var prime: int = 1099511628211           # FNV 64-bit prime
	
	var inputs = [universe_seed, pos_x, pos_y, pos_z, planet_index]
	for val in inputs:
		for i in range(8):
			var byte_val = (val >> (i * 8)) & 0xFF
			hash_val = hash_val ^ byte_val
			hash_val = hash_val * prime
			
	return hash_val & 0x7FFFFFFFFFFFFFFF # Positiver 64-Bit Integer
