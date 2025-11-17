# Codex Cloud KI-Agent – Setup der Doku-Toolchain unter `linux`

## Ziel

Dieses Repository soll eine reproduzierbare Dokumentations-Toolchain für **Linux** (Ubuntu ≥ 24.3)
bereitstellen, die unter `linux` installiert wird.

Die Toolchain umfasst:

- Doxygen + Graphviz (automatische API-/UML-Diagramme)
- Python Virtualenv mit:
  - Sphinx
  - Breathe
  - sphinx-rtd-theme
  - sphinxcontrib-plantuml
  - sphinxcontrib-mermaid
- PlantUML (`plantuml.jar` für UML-Diagramme)
- Eine saubere Installationslogik mit:
  - `bin/`   → endgültige Installation
  - `temp/`  → Probeinstallation
  - `download/` → alle benötigten Downloads (Wheels, `plantuml.jar`)
- Einen Python-Update-Check über `check-python-updates.sh`

Alle Pfade sind **relativ zum Repository-Root**:

```text
linux/
  setup.sh                 # Setup-Skript (Linux)
  check-python-updates.sh  # Info-Skript für Python-Updates
  requirements.txt         # Python-Dependencies
  bin/                     # endgültige Installation (vom Skript verwaltet)
  temp/                    # Probeinstallation (vom Skript verwaltet)
  download/                # Downloads (vom Skript verwaltet)
```

Der Agent soll sicherstellen, dass diese Struktur und das Setup-Skript korrekt existieren und gepflegt werden.


## Logik von `linux/setup.sh`

Das Skript richtet die Toolchain anhand folgender Zustandslogik ein:

- `BIN_DIR = linux/bin`
- `TEMP_DIR = linux/temp`
- `DOWNLOAD_DIR = linux/download`
- `REQ_FILE = linux/requirements.txt`

### 1. Downloads prüfen (`downloads_ok`)

Die Funktion `downloads_ok` prüft:

- existiert `download/`?
- existiert `requirements.txt`?
- existiert `download/.req_checksum`?
- stimmt der gespeicherte SHA256 von `requirements.txt` mit der aktuellen Datei überein?

Wenn **nein**, sind die Downloads **nicht ok**.


### 2. Fall A – Downloads fehlen / sind veraltet **oder** `temp` existiert

In diesem Fall:

1. `bin/` wird gelöscht.
2. `ensure_system_packages` wird aufgerufen, um Systempakete zu installieren/aktualisieren.
3. `perform_downloads` befüllt `download/` neu.

#### 2.1 `ensure_system_packages` (interaktive apt-Updates)

Diese Funktion:

- führt `sudo apt-get update` aus,
- definiert die relevanten Pakete:

  - `python3`
  - `python3-venv`
  - `python3-pip`
  - `graphviz`
  - `doxygen`
  - `default-jre`

- ermittelt mit `apt list --upgradable`, ob für eines dieser Pakete ein Update vorliegt,
- wenn Updates gefunden werden:
  - listet sie **in Rot** auf,
  - stellt die Frage:

    ```text
    Updates installieren [Y,n]?
    ```

  - Antwort `n` oder `N`:
    - meldet, dass Updates übersprungen werden,
    - führt `sudo apt-get install -y` aus, um nur die *Installation* sicherzustellen,
      aber keine zusätzlichen Upgrades zu erzwingen.
  - Antwort `Y` oder Enter:
    - führt `sudo apt-get install -y` aus und installiert/aktualisiert die Pakete.

- Wenn keine Updates verfügbar sind, wird nur `sudo apt-get install -y` ausgeführt,
  um sicherzustellen, dass die Pakete installiert sind.

**Wichtig:**  
`ensure_system_packages` ist also interaktiv und zwingt keine Upgrades auf, ohne
den Anwender vorher zu fragen.


#### 2.2 `perform_downloads`

Diese Funktion:

- löscht `download/` und legt es neu an,
- prüft, dass `requirements.txt` vorhanden ist,
- lädt alle Python-Pakete gemäß `requirements.txt` mit:

  ```bash
  python3 -m pip download -r requirements.txt -d download/
  ```

- lädt `plantuml.jar` von GitHub in `download/plantuml.jar`,
- speichert den SHA256 von `requirements.txt` in `download/.req_checksum`.

Damit wird sichergestellt, dass alle benötigten Wheels und JARs für eine spätere
Offline-Installation bereitstehen.


### 3. Fall B – Downloads ok, aber `bin` existiert nicht

Wenn die Downloads aktuell sind und `bin/` noch nicht existiert:

1. `temp/` wird gelöscht und neu angelegt.
2. `install_to_target temp/` wird aufgerufen (Probeinstallation):

   - legt ein Virtualenv unter `temp/venv` an,
   - installiert alle Python-Pakete aus `download/` via

     ```bash
     pip install --no-index --find-links=download -r requirements.txt
     ```

   - erzeugt ein minimales Sphinx-Projekt unter `temp/sphinx` mit:
     - `source/conf.py` (inkl. PlantUML-/Mermaid-Konfiguration),
     - `source/index.rst`,
     - `Makefile`,
   - erzeugt ein `Doxyfile` mit sinnvollen Defaults für Doxygen.

3. Wenn `install_to_target temp/` fehlschlägt:
   - bleibt `temp/` zur Analyse erhalten,
   - das Skript beendet sich mit Fehlercode.

4. Wenn die Probeinstallation erfolgreich durchläuft:
   - `temp/` wird gelöscht,
   - `install_to_target bin/` wird aufgerufen (gleicher Ablauf wie bei `temp/`),
   - das Skript meldet „Installation in BIN_DIR erfolgreich abgeschlossen.“,
   - ruft am Ende `check-python-updates.sh` (falls ausführbar) über `run_python_update_check` auf,
   - beendet sich erfolgreich.


### 4. Fall C – Downloads ok, `bin` existiert, `temp` existiert nicht

In diesem „grünen“ Zustand:

- meldet das Skript: „Alles ist bereits installiert. Nichts zu tun.“,
- ruft `check-python-updates.sh` (falls ausführbar) über `run_python_update_check` auf,
- beendet sich erfolgreich.


## `check-python-updates.sh`

Dieses Skript dient **nur zur Information**, es verändert nichts.

Verhalten:

1. Sucht das Virtualenv unter `linux/bin/venv`.
2. Wenn vorhanden:
   - aktiviert es,
   - führt `pip list --outdated` aus,
   - zeigt alle im venv installierten Pakete an, für die es neuere Versionen auf PyPI gibt,
   - gibt am Ende einen Hinweisblock aus, z. B.:

     - dass dies nur eine Informationsausgabe ist,
     - dass Updates über Anpassungen in `requirements.txt` erfolgen sollten,
     - dass anschließend `linux/setup.sh` erneut auszuführen ist.

3. Wenn kein Virtualenv existiert:
   - gibt eine kurze Meldung aus und beendet sich ohne Fehler.

`setup.sh` ruft dieses Skript am Ende automatisch auf, wenn es ausführbar ist.


## Aufgaben des Codex Cloud KI-Agenten

Der Agent soll:

1. **Basisstruktur sicherstellen**
   - `linux/setup.sh` (ausführbar),
   - `linux/check-python-updates.sh` (ausführbar),
   - `linux/requirements.txt`,
   - Verzeichnisse `bin`, `temp`, `download` werden vom Skript verwaltet und müssen
     nicht im Repo versioniert werden.

2. **Setup-Skript konsistent halten**
   - Bei Änderungen an der Toolchain (z. B. neue Python-Module) `requirements.txt` anpassen.
   - Sicherstellen, dass `setup.sh` weiterhin:
     - die beschriebene Zustandslogik (Downloads, temp/bin) verwendet,
     - `ensure_system_packages` mit interaktivem apt-Prompt implementiert,
     - `run_python_update_check` am Ende im Erfolgsfall aufruft.

3. **Python-Update-Check respektieren**
   - `check-python-updates.sh` ist rein informativ.
   - Der Agent soll **keine** automatischen `pip install`-Updates anstoßen,
     sondern Updates über Anpassungen in `requirements.txt` + erneuten `./setup.sh`-Lauf modellieren.

4. **Fehlerfälle unterstützen**
   - Wenn eine Probeinstallation (`temp/`) scheitert und das Skript mit Fehler endet,
     sollte der Agent die Struktur in `linux/temp/` analysieren, Logs lesen,
     die Ursache finden (z. B. inkompatible Versionen in `requirements.txt`) und passende
     Korrekturen vorschlagen oder direkt vornehmen.

5. **Nicht automatisch committen oder pushen**
   - Der Agent soll keine Git-Commits oder Pushes durchführen, sofern das nicht
     explizit über andere Prozesse (z. B. CI/CD) definiert ist.


## Definition „fertig“

Die Aufgabe des Agenten gilt als erfüllt, wenn:

1. `linux/setup.sh` und `linux/check-python-updates.sh`
   im Repository vorhanden und ausführbar sind.
2. `linux/requirements.txt` die Python-Abhängigkeiten der Doku-Toolchain beschreibt.
3. `./linux/setup.sh` auf einer Ubuntu-Installation (≥ 24.3) mit Internetzugang:

   - bei veralteten Downloads `download/` neu befüllt,
   - bei fehlendem `bin/` eine Probeinstallation nach `temp/` und anschließend eine finale Installation nach `bin/` durchführt,
   - im „grünen“ Zustand (Downloads ok, `bin` vorhanden, kein `temp`) meldet:
     „Alles ist bereits installiert. Nichts zu tun.“ und den Python-Update-Check ausführt.

4. `check-python-updates.sh` im Erfolgsfall eine sinnvolle Liste veralteter Python-Pakete
   anzeigt (falls vorhanden) und mit einem Hinweistext endet, ohne Pakete zu installieren.
