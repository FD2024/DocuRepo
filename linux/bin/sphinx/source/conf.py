import os
import sys
from datetime import datetime

sys.path.insert(0, os.path.abspath('../..'))

project = 'DocuRepo Time Series'
author = 'DocuRepo Team'
current_year = datetime.now().year
copyright = f"{current_year}, {author}"

extensions = [
    'breathe',
    'sphinxcontrib.plantuml',
    'sphinxcontrib.mermaid'
]

templates_path = ['_templates']
exclude_patterns = []

html_theme = 'sphinx_rtd_theme'

html_static_path = ['_static']

# PlantUML-Konfiguration: erwartet plantuml.jar im download-Verzeichnis
this_dir = os.path.abspath(os.path.dirname(__file__))
plantuml_jar = os.path.abspath(os.path.join(this_dir, '../../../download', 'plantuml.jar'))
plantuml = f'java -jar {plantuml_jar}'
plantuml_output_format = 'svg'

breathe_projects = {
    'DocuRepoTimeSeries': os.path.abspath(os.path.join(this_dir, '../../docs/xml'))
}
breathe_default_project = 'DocuRepoTimeSeries'
