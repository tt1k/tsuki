# JMdict Katakana SQLite

This directory contains the offline ETL for Tsuki's local katakana loanword
database, built from `JMdict_e.xml.gz`.

The database is intentionally narrow: it keeps only pure-katakana Japanese
headwords and maps them to an English word or short English phrase.

## Build

From this directory:

```sh
python3 build_jmdict_sqlite.py --download
```

Default outputs:

- `data/JMdict_e.xml.gz`
- `data/jmdict.sqlite3`
- `data/jmdict.stats.json`

`data/` is ignored by git.

## Schema

The generated SQLite database contains one table:

```sql
CREATE TABLE entries (
    id INTEGER PRIMARY KEY,
    japanese TEXT NOT NULL,
    reading TEXT NOT NULL,
    english TEXT NOT NULL,
    origin TEXT NOT NULL
);
```

It also creates two indexes for exact lookup:

```sql
CREATE INDEX idx_entries_japanese ON entries(japanese);
CREATE INDEX idx_entries_reading ON entries(reading);
```

## Fields

- `id`: SQLite row id / primary key.
- `japanese`: pure-katakana Japanese headword, such as `パソコン`.
- `reading`: JMdict reading. For many katakana words this is the same as `japanese`.
- `english`: primary English candidate for direct display, such as `computer`.
- `origin`: merged original English gloss list from JMdict, such as `willy, penis`.

## Query

Exact katakana lookup:

```sql
SELECT id, japanese, reading, english, origin
FROM entries
WHERE japanese = 'パソコン'
   OR reading = 'パソコン'
LIMIT 10;
```

Example rows:

```text
ポコチン       | english: willy             | origin: willy, penis
パソコン       | english: personal computer | origin: personal computer, PC
コンピューター | english: computer          | origin: computer
エレガント     | english: elegant           | origin: elegant
```

## ETL notes

- Only rows whose `japanese` value is pure katakana are kept.
- Mixed forms such as `パソコン通信` are excluded because they contain non-katakana characters.
- Only English glosses are kept. In `JMdict_e`, missing `xml:lang` is treated as English.
- Gloss strings containing Japanese, kanji, hiragana, or katakana are filtered out as noise.
- `english` stores the first clean English candidate instead of the full JMdict explanation list.
- `origin` stores the merged original English explanation list.
- Reading restrictions (`re_restr`) are respected when expanding kanji/reading rows.
- FTS is not generated; this database is for exact offline lookup.
- Swift integration is intentionally not included yet.

## Current output

Latest local build:

- Table count: 1 (`entries`)
- Row count: 62,471
- Integrity check: `ok`
- Approximate SQLite size: 9.5 MiB
