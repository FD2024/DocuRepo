import os
import sys
from datetime import datetime

# Pfad zum Projekt (bei Bedarf anpassen)
sys.path.insert(0, os.path.abspath('../..'))

project = 'Project Documentation'
author = 'Your Team'
current_year = datetime.now().year
copyright = f"{current_year}, {author}"

extensions = [
    'breathe',
    'sphinxcontrib.plantuml',
    'sphinxcontrib.mermaid',
]

templates_path = ['_templates']
exclude_patterns = []

html_theme = 'sphinx_rtd_theme'

# Ausgabeverzeichnis für HTML
html_static_path = ['_static']

# PlantUML-Konfiguration: erwartet plantuml.jar im Verzeichnis
# tools/doc/linux/download/plantuml.jar
this_dir = os.path.abspath(os.path.dirname(__file__))
plantuml_jar = os.path.abspath(os.path.join(this_dir, '..', '..', 'download', 'plantuml.jar'))
plantuml = f'java -jar {plantuml_jar}'
plantuml_output_format = 'svg'
