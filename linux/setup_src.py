#!/usr/bin/env python3
"""Configure the documentation toolchain for a specific source tree."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List


class SetupError(Exception):
    """Raised for expected configuration or runtime problems."""


@dataclass
class Config:
    project_name: str
    author: str
    breathe_project: str
    sphinx: Dict[str, object]
    doxygen: Dict[str, object]


def fail(message: str) -> None:
    """Print an error with a red cross prefix and exit."""
    print(f"\u274c {message}", file=sys.stderr)
    sys.exit(1)


def find_repo_root(start: Path) -> Path:
    """Walk upwards until a directory containing .git is found."""
    for candidate in (start,) + tuple(start.parents):
        if (candidate / ".git").exists():
            return candidate
    raise SetupError("Konnte das Repository-Root nicht bestimmen ('.git' fehlt).")


def load_config(path: Path) -> Config:
    """Load and validate doc_config.json."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SetupError(f"doc_config.json fehlt unter {path}") from exc
    except json.JSONDecodeError as exc:
        raise SetupError(f"doc_config.json konnte nicht gelesen werden: {exc}") from exc

    project_name = data.get("project_name", "Project Documentation")
    author = data.get("author", "Your Team")
    breathe_project = data.get("breathe_project", project_name.replace(" ", ""))
    sphinx_cfg = data.get("sphinx", {})
    doxygen_cfg = data.get("doxygen", {})
    return Config(
        project_name=project_name,
        author=author,
        breathe_project=breathe_project,
        sphinx=sphinx_cfg,
        doxygen=doxygen_cfg,
    )


def ensure_directory(path: Path) -> None:
    """Create a directory (if needed)."""
    path.mkdir(parents=True, exist_ok=True)


def write_conf_py(
    conf_path: Path,
    cfg: Config,
    download_dir: Path,
    target_dir: Path,
    repo_root: Path,
) -> None:
    """Write Sphinx conf.py based on the JSON configuration."""
    sphinx_cfg = cfg.sphinx
    sys_paths: List[str] = sphinx_cfg.get("sys_path", ["../.."])
    extensions: List[str] = sphinx_cfg.get(
        "extensions",
        ["breathe", "sphinxcontrib.plantuml", "sphinxcontrib.mermaid"],
    )
    html_theme = sphinx_cfg.get("html_theme", "sphinx_rtd_theme")
    templates_path = sphinx_cfg.get("templates_path", ["_templates"])
    html_static_path = sphinx_cfg.get("html_static_path", ["_static"])
    index_title = sphinx_cfg.get(
        "index_title", f"{cfg.project_name} Documentation"
    )
    index_caption = sphinx_cfg.get("index_caption", "Contents")
    index_maxdepth = sphinx_cfg.get("index_maxdepth", 2)
    index_intro = sphinx_cfg.get(
        "index_intro",
        "Automatisch erzeugte Projektdokumentation.",
    )

    ensure_directory(conf_path.parent)
    this_dir_var = "this_dir"
    conf_rel_to_download = os.path.relpath(download_dir, conf_path.parent)
    xml_dir = target_dir / cfg.doxygen.get("output_directory", "docs") / cfg.doxygen.get(
        "xml_output_subdir", "xml"
    )
    xml_rel = os.path.relpath(xml_dir, conf_path.parent)
    sys_path_snippets = "\n".join(
        f"sys.path.insert(0, os.path.abspath('{entry}'))" for entry in sys_paths
    )
    extensions_repr = ",\n    ".join(f"'{ext}'" for ext in extensions)
    templates_repr = ", ".join(f"'{item}'" for item in templates_path)
    html_static_repr = ", ".join(f"'{item}'" for item in html_static_path)

    conf_content = f"""import os
import sys
from datetime import datetime

{sys_path_snippets}

project = {cfg.project_name!r}
author = {cfg.author!r}
current_year = datetime.now().year
copyright = f"{{current_year}}, {{author}}"

extensions = [
    {extensions_repr}
]

templates_path = [{templates_repr}]
exclude_patterns = []

html_theme = {html_theme!r}

html_static_path = [{html_static_repr}]

# PlantUML-Konfiguration: erwartet plantuml.jar im download-Verzeichnis
{this_dir_var} = os.path.abspath(os.path.dirname(__file__))
plantuml_jar = os.path.abspath(os.path.join({this_dir_var}, {repr(conf_rel_to_download)}, 'plantuml.jar'))
plantuml = f'java -jar {{plantuml_jar}}'
plantuml_output_format = 'svg'

breathe_projects = {{
    {cfg.breathe_project!r}: os.path.abspath(os.path.join({this_dir_var}, {xml_rel!r}))
}}
breathe_default_project = {cfg.breathe_project!r}
"""

    conf_path.write_text(conf_content, encoding="utf-8")

    index_body = f"""{index_title}
{'=' * len(index_title)}

{index_intro}

.. toctree::
   :maxdepth: {index_maxdepth}
   :caption: {index_caption}


"""
    (conf_path.parent / "index.rst").write_text(index_body, encoding="utf-8")

    makefile_content = """# Minimal Makefile for Sphinx documentation

SPHINXBUILD   = sphinx-build
SOURCEDIR     = source
BUILDDIR      = build

.PHONY: help clean html

help:
\t@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)"

clean:
\trm -rf "$(BUILDDIR)"

html:
\t$(SPHINXBUILD) -M html "$(SOURCEDIR)" "$(BUILDDIR)"
"""
    (conf_path.parent.parent / "Makefile").write_text(makefile_content, encoding="utf-8")


def run(cmd: List[str]) -> None:
    """Execute a command and ensure success."""
    subprocess.run(cmd, check=True)


def format_tag(key: str, value: str) -> str:
    """Return a Doxygen assignment line with aligned key."""
    return f"{key.ljust(23)}= {value}"


def build_file_patterns(patterns: List[str]) -> str:
    """Create a multi-line FILE_PATTERNS value."""
    indent = " " * 25
    lines: List[str] = []
    for idx, pattern in enumerate(patterns):
        suffix = " \\" if idx < len(patterns) - 1 else ""
        prefix = "" if idx == 0 else indent
        lines.append(f"{prefix}{pattern}{suffix}")
    return "\n".join(lines)


def update_doxyfile(
    doxyfile: Path,
    cfg: Config,
    source_input: Path,
    target_dir: Path,
) -> None:
    """Run `doxygen -g` and patch the generated configuration."""
    run(["doxygen", "-g", str(doxyfile)])

    content = doxyfile.read_text(encoding="utf-8")

    output_dir = target_dir / cfg.doxygen.get("output_directory", "docs")

    replacements = {
        "PROJECT_NAME": f'"{cfg.project_name}"',
        "OUTPUT_DIRECTORY": str(output_dir),
        "INPUT": str(source_input),
        "RECURSIVE": "YES" if cfg.doxygen.get("recursive", True) else "NO",
        "HAVE_DOT": "YES" if cfg.doxygen.get("have_dot", True) else "NO",
        "UML_LOOK": "YES" if cfg.doxygen.get("uml_look", True) else "NO",
        "CALL_GRAPH": "YES" if cfg.doxygen.get("call_graph", True) else "NO",
        "CALLER_GRAPH": "YES" if cfg.doxygen.get("caller_graph", True) else "NO",
        "GENERATE_HTML": "YES" if cfg.doxygen.get("generate_html", True) else "NO",
        "GENERATE_XML": "YES" if cfg.doxygen.get("generate_xml", True) else "NO",
        "XML_OUTPUT": cfg.doxygen.get("xml_output_subdir", "xml"),
        "EXTRACT_ALL": "YES" if cfg.doxygen.get("extract_all", False) else "NO",
    }

    file_patterns = cfg.doxygen.get("file_patterns", [])
    if file_patterns:
        replacements["FILE_PATTERNS"] = build_file_patterns(file_patterns)

    for key, value in replacements.items():
        if key == "FILE_PATTERNS":
            pattern = re.compile(rf"^{key}\s*=.*(?:\n[ \t]+\S.*)*", re.MULTILINE)
        else:
            pattern = re.compile(rf"^{key}\s*=.*$", re.MULTILINE)
        formatted = format_tag(key, value)
        content, count = pattern.subn(formatted, content)
        if count == 0:
            content += f"\n{formatted}\n"

    doxyfile.write_text(content, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Konfiguriert Doxygen und Sphinx für einen Quellpfad."
    )
    parser.add_argument(
        "source_relative",
        help="Pfad zu den Quellen relativ zum Repository-Root.",
    )
    parser.add_argument(
        "--target",
        dest="target_dir",
        help="Zielverzeichnis für die Installation (z. B. linux/bin).",
    )
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    try:
        repo_root = find_repo_root(script_dir)
    except SetupError as exc:
        fail(str(exc))

    target_dir_raw = args.target_dir or os.environ.get("DOC_TARGET_DIR")
    if not target_dir_raw:
        fail("Zielverzeichnis fehlt (Parameter --target oder Variable DOC_TARGET_DIR).")

    target_dir = Path(target_dir_raw).resolve()
    source_rel = Path(args.source_relative)
    source_abs = (repo_root / source_rel).resolve()

    if not source_abs.exists():
        fail(f"Der Quellpfad {source_abs} existiert nicht.")

    cfg_path = source_abs / "doc_config.json"
    try:
        cfg = load_config(cfg_path)
    except SetupError as exc:
        fail(str(exc))

    doxygen_input_rel = cfg.doxygen.get(
        "input_relative_to_root", str(source_rel).replace("\\", "/")
    )
    input_abs = (repo_root / doxygen_input_rel).resolve()
    if not input_abs.exists():
        fail(f"Doxygen-INPUT {input_abs} existiert nicht.")

    ensure_directory(target_dir)
    sphinx_dir = target_dir / "sphinx" / "source"
    ensure_directory(sphinx_dir)

    download_dir = script_dir / "download"
    plantuml_jar = download_dir / "plantuml.jar"
    if not plantuml_jar.exists():
        fail(f"plantuml.jar fehlt unter {plantuml_jar}")

    try:
        write_conf_py(
            sphinx_dir / "conf.py",
            cfg=cfg,
            download_dir=download_dir,
            target_dir=target_dir,
            repo_root=repo_root,
        )
        update_doxyfile(
            target_dir / "Doxyfile",
            cfg=cfg,
            source_input=input_abs,
            target_dir=target_dir,
        )
    except subprocess.CalledProcessError as exc:
        fail(f"Befehl fehlgeschlagen: {' '.join(exc.cmd)}")
    except OSError as exc:
        fail(str(exc))


if __name__ == "__main__":
    try:
        main()
    except SetupError as exc:
        fail(str(exc))
    except Exception as exc:  # pragma: no cover - defensive
        fail(f"Unerwarteter Fehler: {exc}")
