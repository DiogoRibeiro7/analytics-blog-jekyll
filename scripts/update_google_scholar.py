#!/usr/bin/env python3
"""Synchronize Google Scholar citation metrics into _data/academic.yml."""
from __future__ import annotations

import datetime as _dt
import sys
from pathlib import Path
from typing import Any, Dict

try:
    import yaml  # type: ignore
except ImportError as exc:  # pragma: no cover - handled in workflow
    sys.stderr.write(f"Missing dependency: {exc}\n")
    sys.exit(1)

ACADEMIC_YML = Path(__file__).resolve().parent.parent / "_data" / "academic.yml"
PLACEHOLDER_IDS = {"example", "your_google_scholar_id", ""}


def load_yaml(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def save_yaml(path: Path, payload: Dict[str, Any]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        yaml.safe_dump(payload, handle, allow_unicode=True, sort_keys=False)


def slugify_year(year: Any) -> str:
    return str(year)


def update_metrics(data: Dict[str, Any], author: Dict[str, Any]) -> bool:
    citations = data.setdefault("citations", {})
    metrics = citations.setdefault("metrics", {})
    updated = False

    def assign(target: Dict[str, Any], key: str, value: Any) -> None:
        nonlocal updated
        if value is None:
            return
        if target.get(key) != value:
            target[key] = value
            updated = True

    assign(metrics, "total", author.get("citedby"))
    assign(metrics, "h_index", author.get("hindex"))
    assign(metrics, "i10_index", author.get("i10index"))

    since = metrics.setdefault("since_2019", {})
    assign(since, "total", author.get("citedby5y"))
    assign(since, "h_index", author.get("hindex5y"))
    assign(since, "i10_index", author.get("i10index5y"))

    yearly_totals = citations.setdefault("yearly_totals", {})
    cites_per_year = author.get("cites_per_year", {}) or {}
    for year, value in sorted(cites_per_year.items()):
        key = slugify_year(year)
        if yearly_totals.get(key) != value:
            yearly_totals[key] = value
            updated = True

    return updated


def run() -> int:
    if not ACADEMIC_YML.exists():
        sys.stderr.write(f"Cannot find academic data file at {ACADEMIC_YML}\n")
        return 1

    data = load_yaml(ACADEMIC_YML)
    profiles = data.get("profiles", {})
    scholar = profiles.get("google_scholar", {})
    user_id = str(scholar.get("user_id", "")).strip().lower()

    if user_id in PLACEHOLDER_IDS:
        print("Google Scholar user id is a placeholder; skipping update.")
        return 0

    try:
        from scholarly import scholarly  # type: ignore
    except ImportError as exc:
        sys.stderr.write(f"Install scholarly to update citations: {exc}\n")
        return 1

    try:
        author = scholarly.search_author_id(user_id)
        if not author:
            sys.stderr.write(f"Could not locate author with id '{user_id}'.\n")
            return 1
        author = scholarly.fill(author, sections=["basics", "indices", "counts"])
    except Exception as exc:  # pragma: no cover - network failures
        sys.stderr.write(f"Failed to fetch Google Scholar profile: {exc}\n")
        return 1

    updated = update_metrics(data, author)

    today = _dt.date.today().isoformat()
    if scholar.get("last_synced") != today:
        scholar["last_synced"] = today
        updated = True
    else:
        scholar["last_synced"] = today

    save_yaml(ACADEMIC_YML, data)
    if updated:
        print("Academic metrics updated from Google Scholar.")
    else:
        print("Google Scholar metrics already up to date.")
    return 0


if __name__ == "__main__":
    sys.exit(run())
