#!/usr/bin/env python3
"""Build an offline JMdict SQLite database for Tsuki.

The generated database contains:
  - entries(id, japanese, reading, english, origin)

JMdict readings may be restricted to specific kanji forms. This ETL respects
those restrictions when expanding an entry into searchable rows.
"""

from __future__ import annotations

import argparse
import gzip
import io
import json
import re
import sqlite3
import sys
import time
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import BinaryIO, Dict, Iterable, Iterator, List, Optional, Sequence, Set, Tuple


DEFAULT_URL = "http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz"
XML_LANG = "{http://www.w3.org/XML/1998/namespace}lang"
STANDARD_XML_ENTITIES = {b"amp", b"lt", b"gt", b"apos", b"quot"}
UNKNOWN_ENTITY_RE = re.compile(br"&([A-Za-z][A-Za-z0-9_.:-]*);")
JAPANESE_NOISE_RE = re.compile(r"[\u3040-\u30ff\u3400-\u9fff]")
SPACE_RE = re.compile(r"\s+")
KATAKANA_ONLY_RE = re.compile(r"^[\u30a0-\u30ff\u31f0-\u31ff\uff66-\uff9f]+$")
PARENTHETICAL_RE = re.compile(r"\s*\([^)]*\)")


class UnknownEntityFilter(io.RawIOBase):
    """Binary stream wrapper that removes non-standard XML entity references.

    JMdict has historically used DTD entities for metadata such as parts of
    speech. The ETL does not read those fields, but the XML parser still sees
    them. Removing unknown entities keeps parsing local and DTD-independent.
    """

    def __init__(self, source: BinaryIO) -> None:
        self.source = source
        self.tail = b""

    def readable(self) -> bool:
        return True

    def read(self, size: int = -1) -> bytes:
        chunk = self.source.read(size)
        if not chunk:
            data = self.tail
            self.tail = b""
            return self._replace_unknown_entities(data)

        data = self.tail + chunk
        self.tail = b""

        last_amp = data.rfind(b"&")
        if last_amp != -1 and b";" not in data[last_amp:]:
            self.tail = data[last_amp:]
            data = data[:last_amp]

        return self._replace_unknown_entities(data)

    def readinto(self, buffer: bytearray) -> int:
        data = self.read(len(buffer))
        length = len(data)
        buffer[:length] = data
        return length

    @staticmethod
    def _replace_unknown_entities(data: bytes) -> bytes:
        def replace(match: re.Match[bytes]) -> bytes:
            name = match.group(1)
            if name in STANDARD_XML_ENTITIES:
                return match.group(0)
            return b""

        return UNKNOWN_ENTITY_RE.sub(replace, data)


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1] if "}" in tag else tag


def clean_text(value: Optional[str]) -> str:
    if not value:
        return ""
    return SPACE_RE.sub(" ", value).strip()


def is_english_gloss(gloss_element: ET.Element) -> bool:
    # JMdict_e normally contains only English glosses and may omit xml:lang.
    lang = gloss_element.attrib.get(XML_LANG) or gloss_element.attrib.get("lang") or "eng"
    return lang == "eng"


def has_japanese_noise(value: str) -> bool:
    return bool(JAPANESE_NOISE_RE.search(value))


def primary_english_candidate(value: str) -> str:
    value = PARENTHETICAL_RE.sub("", value)
    value = clean_text(value)
    if not value:
        return ""

    # JMdict glosses often contain comma-separated synonym lists. Keep the
    # first clean term so Tsuki can display a direct English equivalent.
    return clean_text(value.split(",", 1)[0])


def is_pure_katakana(value: str) -> bool:
    return bool(KATAKANA_ONLY_RE.fullmatch(value))


def unique_in_order(values: Iterable[str]) -> List[str]:
    seen: Set[str] = set()
    result: List[str] = []
    for value in values:
        if value and value not in seen:
            seen.add(value)
            result.append(value)
    return result


def english_glosses(entry: ET.Element) -> List[str]:
    glosses: List[str] = []
    for sense in entry.findall("sense"):
        sense_glosses: List[str] = []
        for gloss in sense.findall("gloss"):
            if not is_english_gloss(gloss):
                continue
            text = clean_text(gloss.text)
            if not text or has_japanese_noise(text):
                continue
            sense_glosses.append(text)

        sense_glosses = unique_in_order(sense_glosses)
        if sense_glosses:
            glosses.append(", ".join(sense_glosses))

    return unique_in_order(glosses)


def primary_english(glosses: Sequence[str]) -> str:
    for gloss in glosses:
        candidate = primary_english_candidate(gloss)
        if candidate:
            return candidate

    return ""


def extract_kanji(entry: ET.Element) -> List[str]:
    values = []
    for element in entry.findall("k_ele"):
        text = clean_text(element.findtext("keb"))
        if text:
            values.append(text)
    return unique_in_order(values)


def extract_readings(entry: ET.Element) -> List[Tuple[str, List[str]]]:
    readings: List[Tuple[str, List[str]]] = []
    seen: Set[Tuple[str, Tuple[str, ...]]] = set()

    for element in entry.findall("r_ele"):
        reading = clean_text(element.findtext("reb"))
        if not reading:
            continue
        restrictions = unique_in_order(
            clean_text(restriction.text) for restriction in element.findall("re_restr")
        )
        key = (reading, tuple(restrictions))
        if key not in seen:
            seen.add(key)
            readings.append((reading, restrictions))

    return readings


def expand_entry(entry: ET.Element) -> Iterator[Tuple[str, str, str, str]]:
    glosses = english_glosses(entry)
    english = primary_english(glosses)
    if not english:
        return
    origin = "; ".join(glosses)

    kanji_values = extract_kanji(entry)
    readings = extract_readings(entry)

    if kanji_values:
        for reading, restrictions in readings:
            japanese_values = restrictions if restrictions else kanji_values
            for japanese in japanese_values:
                if not is_pure_katakana(japanese):
                    continue
                yield japanese, reading, english, origin
    else:
        for reading, _ in readings:
            if not is_pure_katakana(reading):
                continue
            yield reading, reading, english, origin


def open_xml_stream(path: Path) -> BinaryIO:
    raw: BinaryIO
    if path.suffix == ".gz":
        raw = gzip.open(path, "rb")
    else:
        raw = path.open("rb")
    return io.BufferedReader(UnknownEntityFilter(raw))


def iter_rows(xml_path: Path) -> Iterator[Tuple[str, str, str, str]]:
    context = ET.iterparse(open_xml_stream(xml_path), events=("end",))
    seen_rows: Set[Tuple[str, str, str, str]] = set()

    for _, element in context:
        if local_name(element.tag) != "entry":
            continue

        for row in expand_entry(element):
            if row not in seen_rows:
                seen_rows.add(row)
                yield row

        element.clear()


def download(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = destination.with_suffix(destination.suffix + ".tmp")

    with urllib.request.urlopen(url) as response, tmp_path.open("wb") as output:
        total = response.headers.get("Content-Length")
        total_bytes = int(total) if total and total.isdigit() else None
        copied = 0
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            output.write(chunk)
            copied += len(chunk)
            if total_bytes:
                percent = copied * 100 / total_bytes
                print(f"\rDownloading {percent:5.1f}% ({copied / 1024 / 1024:.1f} MiB)", end="")
            else:
                print(f"\rDownloading {copied / 1024 / 1024:.1f} MiB", end="")
    print()
    tmp_path.replace(destination)


def create_database(db_path: Path, rows: Iterable[Tuple[str, str, str, str]], batch_size: int) -> Dict[str, object]:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    if db_path.exists():
        db_path.unlink()

    start = time.perf_counter()
    connection = sqlite3.connect(str(db_path))
    try:
        connection.execute("PRAGMA journal_mode = OFF")
        connection.execute("PRAGMA synchronous = OFF")
        connection.execute("PRAGMA temp_store = MEMORY")
        connection.execute("PRAGMA cache_size = -200000")

        connection.executescript(
            """
            CREATE TABLE entries (
                id INTEGER PRIMARY KEY,
                japanese TEXT NOT NULL,
                reading TEXT NOT NULL,
                english TEXT NOT NULL,
                origin TEXT NOT NULL
            );

            CREATE INDEX idx_entries_japanese ON entries(japanese);
            CREATE INDEX idx_entries_reading ON entries(reading);

            """
        )

        insert_sql = "INSERT INTO entries(japanese, reading, english, origin) VALUES (?, ?, ?, ?)"
        total_rows = 0
        batch: List[Tuple[str, str, str, str]] = []

        for row in rows:
            batch.append(row)
            if len(batch) >= batch_size:
                connection.executemany(insert_sql, batch)
                total_rows += len(batch)
                print(f"\rInserted {total_rows:,} rows", end="")
                batch.clear()

        if batch:
            connection.executemany(insert_sql, batch)
            total_rows += len(batch)
            print(f"\rInserted {total_rows:,} rows", end="")
        print()

        connection.execute("PRAGMA optimize")
        connection.commit()

        elapsed = time.perf_counter() - start
        return {
            "db_path": str(db_path),
            "rows": total_rows,
            "size_bytes": db_path.stat().st_size,
            "elapsed_seconds": round(elapsed, 3),
        }
    finally:
        connection.close()


def benchmark(db_path: Path) -> Dict[str, Dict[str, object]]:
    queries = {
        "exact_パソコン": ("SELECT japanese, reading, english, origin FROM entries WHERE japanese = ? LIMIT 5", ("パソコン",)),
        "exact_コンピューター": (
            "SELECT japanese, reading, english, origin FROM entries WHERE japanese = ? OR reading = ? LIMIT 5",
            ("コンピューター", "コンピューター"),
        ),
    }

    results: Dict[str, Dict[str, object]] = {}
    connection = sqlite3.connect(str(db_path))
    try:
        for name, (sql, params) in queries.items():
            start = time.perf_counter()
            rows = connection.execute(sql, params).fetchall()
            elapsed_ms = (time.perf_counter() - start) * 1000
            results[name] = {
                "elapsed_ms": round(elapsed_ms, 3),
                "row_count": len(rows),
                "sample": rows[:3],
            }
    finally:
        connection.close()
    return results


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Tsuki's JMdict SQLite database.")
    parser.add_argument("--url", default=DEFAULT_URL, help="JMdict_e gzip URL.")
    parser.add_argument("--source", type=Path, default=Path("data/JMdict_e.xml.gz"), help="Local JMdict XML or XML.gz path.")
    parser.add_argument("--db", type=Path, default=Path("data/jmdict.sqlite3"), help="Output SQLite database path.")
    parser.add_argument("--stats", type=Path, default=Path("data/jmdict.stats.json"), help="Output build stats JSON path.")
    parser.add_argument("--download", action="store_true", help="Download source before building.")
    parser.add_argument("--force-download", action="store_true", help="Download even if source exists.")
    parser.add_argument("--batch-size", type=int, default=5000, help="SQLite insert batch size.")
    return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
    args = parse_args(argv)

    if args.download and (args.force_download or not args.source.exists()):
        print(f"Downloading {args.url}")
        download(args.url, args.source)

    if not args.source.exists():
        print(f"Source file not found: {args.source}", file=sys.stderr)
        print("Run with --download or place JMdict_e.xml.gz at that path.", file=sys.stderr)
        return 2

    print(f"Building {args.db} from {args.source}")
    stats = create_database(args.db, iter_rows(args.source), args.batch_size)
    stats["benchmarks"] = benchmark(args.db)
    stats["source"] = str(args.source)
    stats["url"] = args.url

    args.stats.parent.mkdir(parents=True, exist_ok=True)
    args.stats.write_text(json.dumps(stats, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps(stats, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
