# Doku-Toolchain (Doxygen + Sphinx + PlantUML) unter Ubuntu

Dieses Repository richtet eine reproduzierbare Dokumentations-Toolchain unter Ubuntu 24.04+ ein. Die Installation erfolgt skriptbasiert und nutzt einen lokalen Download-Cache, damit Setups ohne Internet funktionieren.

## Komponenten
- **Doxygen** + **Graphviz**
- **Sphinx** + **Breathe** + **sphinx-rtd-theme**
- **PlantUML** + **sphinxcontrib-plantuml**
- **Mermaid** + **sphinxcontrib-mermaid**

## Verzeichnisstruktur
- `tools/doc/linux/requirements.txt` – Python-Abhängigkeiten (versioniert)
- `tools/doc/linux/download/` – Cache für alle heruntergeladenen Artefakte (Wheels, `plantuml.jar`)
- `tools/doc/linux/fetch_artifacts.sh` – Lädt alle Artefakte in den Download-Cache (benötigt Internet)
- `tools/doc/linux/setup.sh` – Installiert Systempakete und richtet die Toolchain offline aus dem Cache ein
- `tools/doc/linux/README.md` – Detailanleitung

## Nutzung
1. **Artefakte abrufen (online):**
   ```bash
   tools/doc/linux/fetch_artifacts.sh
   ```
2. **Toolchain installieren (offline-fähig):**
   ```bash
   tools/doc/linux/setup.sh
   ```

Nach der Installation liegt das Virtualenv unter `tools/doc/linux/.venv` und `plantuml.jar` unter `tools/doc/linux/plantuml.jar`. Aktivierung:
```bash
source tools/doc/linux/.venv/bin/activate
```

Die Skripte installieren nur aus dem Download-Verzeichnis (plus apt-Systempakete) und vermeiden zusätzliche Internetzugriffe während der Einrichtung.
