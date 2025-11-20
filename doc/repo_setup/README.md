# Doku-Toolchain für Linux (Doxygen + Sphinx + PlantUML)

Dieses Repository stellt eine reproduzierbare Dokumentations-Toolchain
für **Linux** (Ubuntu ≥ 24.3) bereit. Die Toolchain lebt unter:

```text
linux/
```

und umfasst:

- **Doxygen** + **Graphviz** (automatische API-/UML-Diagramme)
- **Sphinx** + **Breathe** + **sphinx-rtd-theme**
- **PlantUML** + **sphinxcontrib-plantuml**
- **Mermaid** + **sphinxcontrib-mermaid**
- Eine Python-Umgebung (Virtualenv) für alle Doku-Werkzeuge

Die Installation und Konfiguration erfolgt über:

```bash
linux/setup.sh
```

Zusätzlich gibt es ein Info-Skript:

```bash
linux/check-python-updates.sh
```

das verfügbare Python-Updates anzeigt, **ohne** Pakete automatisch zu installieren.


## 1. Verzeichnisstruktur

Im Repository (aus Sicht des Projekt-Roots) gilt:

```text
linux/
  setup.sh                 # Setup-Skript (Linux)
  check-python-updates.sh  # Info-Skript für Python-Updates
  requirements.txt         # Python-Dependencies
  bin/                     # endgültige Installation (vom Skript verwaltet)
  temp/                    # Probeinstallation (vom Skript verwaltet)
  download/                # Downloads (vom Skript verwaltet)
```

Typischerweise werden versioniert:

- `linux/setup.sh`
- `linux/check-python-updates.sh`
- `linux/requirements.txt`

Die Verzeichnisse `bin`, `temp` und `download` werden vom Skript selbst erzeugt
und sollten in der Regel **nicht** im Repository eingecheckt werden.


## 2. Repository vorbereiten

### 2.1 Repo anlegen & klonen

1. Auf GitHub ein Repository anlegen.
2. Lokal klonen:

   ```bash
   git clone git@github.com:<ORG_ODER_USER>/<REPO_NAME>.git
   cd <REPO_NAME>
   ```

### 2.2 AGENTS und README hinzufügen

- `README.md` (diese Datei) und `AGENTS.md` ins Repo-Root legen.
- Commit & Push:

  ```bash
  git add README.md AGENTS.md
  git commit -m "Add documentation toolchain instructions"
  git push
  ```

### 2.3 Struktur für Linux-Toolchain anlegen

Falls noch nicht geschehen:

```bash
mkdir -p linux
```

Die Dateien:

- `linux/setup.sh`
- `linux/check-python-updates.sh`
- `linux/requirements.txt`

dorthin kopieren und ausführbar machen:

```bash
cd linux
chmod +x setup.sh check-python-updates.sh
cd ../../..
git add linux
git commit -m "Add Linux documentation toolchain setup"
git push
```


## 3. Installationslogik von `linux/setup.sh`

Das Skript arbeitet mit drei Verzeichnissen (relativ zu `linux`):

- `bin/`   → endgültige Installation der Toolchain
- `temp/`  → Probeinstallation zum Testen
- `download/` → Cache für alle benötigten Downloads (Python-Wheels, `plantuml.jar`)

Zusätzlich wird `requirements.txt` für alle Python-Abhängigkeiten genutzt.

### 3.1 Downloads prüfen (`downloads_ok`)

Das Skript betrachtet die Downloads als „ok“, wenn:

- `download/` existiert,
- `requirements.txt` existiert,
- `download/.req_checksum` existiert,
- SHA256 von `requirements.txt` mit dem gespeicherten Wert in `.req_checksum` übereinstimmt.

Wenn das nicht der Fall ist, oder wenn `temp/` existiert, gelten die Downloads als veraltet
und werden neu aufgebaut.


### 3.2 Systempakete mit interaktiven Updates (`ensure_system_packages`)

Bevor Downloads oder Installationen durchgeführt werden, ruft das Script
`ensure_system_packages` auf. Diese Funktion:

1. ruft `sudo apt-get update` auf,
2. prüft mit `apt list --upgradable`, ob für folgende Pakete Updates vorhanden sind:
   - `python3`
   - `python3-venv`
   - `python3-pip`
   - `graphviz`
   - `doxygen`
   - `default-jre`
3. falls Updates existieren, werden diese in Rot angezeigt und der Benutzer wird gefragt:

   ```text
   Updates installieren [Y,n]?
   ```

   - Antwort `n` oder `N`: Updates werden übersprungen, aber die genannten Pakete
     werden bei Bedarf installiert (ohne erzwungenes Upgrade).
   - Antwort `Y` oder Enter: `sudo apt-get install -y` installiert/aktualisiert die Pakete.

Damit kannst du bewusst entscheiden, ob du Systempakete aktualisieren möchtest oder nicht.


### 3.3 Fall A – Downloads fehlen / sind veraltet **oder** `temp` existiert

Wenn `downloads_ok` false liefert oder `temp/` existiert:

- `bin/` wird gelöscht.
- `ensure_system_packages` wird ausgeführt.
- `perform_downloads` erstellt `download/` neu:
  - lädt alle benötigten Wheels gemäß `requirements.txt`,
  - lädt `plantuml.jar`,
  - schreibt `download/.req_checksum`.


### 3.4 Fall B – Downloads ok, `bin` existiert nicht

In diesem Fall:

1. `temp/` wird gelöscht und neu angelegt.
2. `install_to_target temp/`:
   - legt ein Virtualenv unter `temp/venv` an,
   - installiert alle Python-Pakete aus `download/` mittels:

     ```bash
     pip install --no-index --find-links=download -r requirements.txt
     ```

   - legt ein minimales Sphinx-Projekt unter `temp/sphinx` an (inkl. `conf.py`, `index.rst`, `Makefile`),
   - erzeugt ein `Doxyfile` mit sinnvollen Defaults.

3. Falls die Probeinstallation fehlschlägt:
   - bleibt `temp/` zur Analyse stehen,
   - das Skript beendet sich mit einem Fehler.

4. Falls die Probeinstallation erfolgreich war:
   - `temp/` wird gelöscht,
   - `install_to_target bin/` wird ausgeführt (gleicher Ablauf wie für `temp/`),
   - das Skript ruft anschließend `check-python-updates.sh` auf (falls ausführbar)
     und beendet sich erfolgreich.


### 3.5 Fall C – Downloads ok, `bin` existiert, `temp` existiert nicht

Wenn die Downloads aktuell sind und `bin/` bereits existiert, aber `temp/` nicht:

- meldet das Skript: „Alles ist bereits installiert. Nichts zu tun.“,
- ruft `check-python-updates.sh` auf (falls ausführbar),
- beendet sich erfolgreich.


## 4. `check-python-updates.sh` – Python-Updates anzeigen

Das Skript:

1. sucht das Virtualenv unter `linux/bin/venv`,
2. aktiviert es (falls vorhanden),
3. führt `pip list --outdated` aus und zeigt alle Pakete an, für die es neuere
   Versionen auf PyPI gibt,
4. gibt einen Hinweisblock aus, wie Python-Pakete **sicher** aktualisiert werden können:

   - `requirements.txt` anpassen (Versionen erhöhen),
   - `linux/setup.sh` erneut ausführen, damit:
     - neue Wheels heruntergeladen werden,
     - eine Probeinstallation erfolgt,
     - und bei Erfolg `bin/` neu aufgebaut wird.

**Wichtig:**  
`check-python-updates.sh` nimmt **keine** Änderungen an installierten Paketen vor, sondern
liefert nur Informationen.


## 5. Setup unter Ubuntu ausführen

Voraussetzungen:

- Ubuntu **≥ 24.3** (64-bit),
- Nutzer mit `sudo`-Rechten (für `apt-get`),
- Internetzugang für:
  - Systempakete (`apt-get`),
  - Python-Wheels (PyPI),
  - `plantuml.jar` (GitHub).

Erstinstallation:

```bash
# Im Repo-Root
cd linux
chmod +x setup.sh check-python-updates.sh   # falls noch nicht geschehen
./setup.sh
```

- Downloads werden erstellt (Wheels + `plantuml.jar`),
- eine Probeinstallation nach `temp/` wird durchgeführt,
- dann erfolgt die finale Installation nach `bin/`,
- am Ende wird `check-python-updates.sh` aufgerufen und zeigt ggf. veraltete Python-Pakete an.


## 6. Verwendung der installierten Toolchain

Nach erfolgreichem Setup liegt die Toolchain unter:

```text
linux/bin/
```

### 6.1 Sphinx-Dokumentation bauen

```bash
cd linux/bin
source venv/bin/activate

cd sphinx
make html
```

Die HTML-Dokumentation liegt anschließend unter:

```text
linux/bin/sphinx/build/html/
```


### 6.2 Doxygen ausführen

```bash
cd linux/bin
doxygen Doxyfile
```

Die Ausgabe (z. B. HTML) liegt dann unter dem im `Doxyfile` gesetzten `OUTPUT_DIRECTORY`
(z. B. `docs/`).


## 7. Anpassung der Toolchain

- **`requirements.txt`**:
  - Hier werden die Python-Pakete und Versionen gepflegt.
  - Änderungen an Versionen erfordern einen neuen Lauf von `./setup.sh`,
    der neue Wheels herunterlädt und die Toolchain neu aufbaut.

- **`setup.sh`**:
  - Kann erweitert werden (z. B. zusätzliche Sphinx-Extensions, angepasste Doxygen-Einstellungen).

- **`check-python-updates.sh`**:
  - Kann bei Bedarf zusätzliche Checks ergänzen (z. B. bestimmte Pakete hervorheben).


Später kann analog eine Windows-spezifische Variante unter `tools/doc/win/` ergänzt werden,
ohne das Linux-Setup zu beeinträchtigen.
