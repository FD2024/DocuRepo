# Dokumentations-Toolchain unter Ubuntu

Dieses Verzeichnis enthält Skripte, um eine reproduzierbare Dokumentations-Umgebung mit Doxygen, Graphviz, Sphinx, Breathe, PlantUML und Mermaid einzurichten. Die Installation erfolgt aus einem lokalen Download-Cache, damit auch Offline-Setups möglich sind.

## Inhalt
- `requirements.txt` – Versionierte Python-Abhängigkeiten.
- `download/` – Cache für Wheels und `plantuml.jar`.
- `fetch_artifacts.sh` – Lädt alle Artefakte ins Download-Verzeichnis (benötigt Internet; lädt nur Wheels für Offline-Installat
ion).
- `setup.sh` – Installiert Systempakete, richtet ein Virtualenv ein und nutzt nur Artefakte aus `download/` (ohne weitere Downlo
ads oder `pip`-Upgrades).

## Vorbereitung der Downloads (online)
```bash
# optional: gewünschte PlantUML-Version setzen
export PLANTUML_VERSION=1.2024.7

tools/doc/linux/fetch_artifacts.sh
```
Die Wheels und `plantuml.jar` landen anschließend unter `tools/doc/linux/download/`.

## Installation (offline-fähig)
```bash
# falls Systempakete bereits vorhanden sind, kann --skip-apt genutzt werden
tools/doc/linux/setup.sh
```
- Systempakete: `doxygen`, `graphviz`, `python3-venv`, `python3-pip`, `openjdk-21-jre-headless`
- Python-Umgebung: `tools/doc/linux/.venv`
- PlantUML: `tools/doc/linux/plantuml.jar`

## Nutzung
```bash
source tools/doc/linux/.venv/bin/activate
```
Sphinx, Breathe sowie die PlantUML- und Mermaid-Erweiterungen stehen danach bereit. `plantuml.jar` kann mit `PLANTUML_JAR` oder der Pfadangabe `tools/doc/linux/plantuml.jar` in Sphinx-Konfigurationen referenziert werden.
