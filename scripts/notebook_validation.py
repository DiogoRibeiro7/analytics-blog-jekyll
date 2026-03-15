#!/usr/bin/env python3
import json
from pathlib import Path

notebook_path = Path(__file__).resolve().parents[1] / "_notebooks" / "sample-analysis.ipynb"
if not notebook_path.exists():
    raise SystemExit("Sample notebook missing")

data = json.loads(notebook_path.read_text())

if "cells" not in data or not data["cells"]:
    raise SystemExit("Notebook has no cells")

code_cells = [cell for cell in data["cells"] if cell.get("cell_type") == "code"]
markdown_cells = [cell for cell in data["cells"] if cell.get("cell_type") == "markdown"]

if not code_cells:
    raise SystemExit("Notebook missing code cells for conversion")

if not markdown_cells:
    raise SystemExit("Notebook missing markdown commentary")

metadata = data.get("metadata", {})
kernelspec = metadata.get("kernelspec")
language_info = metadata.get("language_info")

if not kernelspec or "name" not in kernelspec:
    raise SystemExit("Notebook metadata missing kernelspec")

if not language_info or "name" not in language_info:
    raise SystemExit("Notebook metadata missing language info")

if not any("import" in "".join(cell.get("source", [])) for cell in code_cells):
    raise SystemExit("Notebook lacks executable code samples")

print(
    "Notebook metadata validated for",
    kernelspec.get("name", "unknown kernel"),
    "with",
    len(code_cells),
    "code cells and",
    len(markdown_cells),
    "markdown cells.",
)
