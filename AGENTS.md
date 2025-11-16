# Codex Cloud KI-Agent – Setup der Doku-Toolchain unter `tools/doc/linux`

## Ziel

Richte in diesem Repository eine vollständig skriptbasierte Dokumentations-Toolchain ein, die unter **Ubuntu ≥ 24.3** läuft und folgende Komponenten bereitstellt:

- Doxygen + Graphviz (automatische Code-/UML-Diagramme)
- Python Virtualenv mit:
  - Sphinx
  - Breathe
  - sphinx-rtd-theme (oder vergleichbares Theme)
  - sphinxcontrib-plantuml
  - sphinxcontrib-mermaid
- PlantUML (als `plantuml.jar`)
- Reproduzierbare Installation über ein Skript: `tools/doc/linux/setup.sh`

**Wichtige Nebenbedingung:**

- Alle **heruntergeladenen Artefakte** (Python-Wheels, JARs, ggf. zusätzliche Tools) müssen im Verzeichnis  
  `tools/doc/linux/download/` abgelegt werden.
- Das Skript `setup.sh` soll die komplette Installation und Konfiguration ausschließlich aus diesem Download-Verzeichnis (plus Systempakete über `apt`) vornehmen, ohne weitere Downloads aus dem Internet.

( ... full content from previous response ... )
