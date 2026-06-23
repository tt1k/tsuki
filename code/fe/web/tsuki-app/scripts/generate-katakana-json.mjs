import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const webRoot = resolve(scriptDir, "..");
const repoRoot = resolve(webRoot, "../../../..");
const databasePath = process.env.TSUKI_JMDICT_SQLITE
  ? resolve(process.env.TSUKI_JMDICT_SQLITE)
  : resolve(repoRoot, "code/db/jmdict/data/jmdict.sqlite3");
const outputPath = resolve(webRoot, "public/dict/katakana-en.json");

const pythonProgram = String.raw`
import json
import sqlite3
import sys

database_path = sys.argv[1]
connection = sqlite3.connect(database_path)
try:
    cursor = connection.execute("""
        SELECT japanese, english
        FROM entries
        WHERE trim(japanese) <> '' AND trim(english) <> ''
        ORDER BY japanese COLLATE BINARY, length(english), id
    """)

    entries = {}
    for japanese, english in cursor:
        japanese = str(japanese or "").strip()
        english = str(english or "").strip()
        if japanese and english and japanese not in entries:
            entries[japanese] = english

    sys.stdout.write(json.dumps(entries, ensure_ascii=False, separators=(",", ":")))
    sys.stdout.write("\n")
finally:
    connection.close()
`;

function useExistingOutput(reason) {
  if (!existsSync(outputPath)) {
    console.error(`[katakana-json] ${reason}`);
    console.error(`[katakana-json] Missing generated fallback: ${outputPath}`);
    process.exit(1);
  }

  console.warn(`[katakana-json] ${reason}`);
  console.warn(`[katakana-json] Using existing generated file: ${outputPath}`);
}

if (!existsSync(databasePath)) {
  useExistingOutput(`SQLite database not found: ${databasePath}`);
  process.exit(0);
}

const result = spawnSync("python3", ["-c", pythonProgram, databasePath], {
  encoding: "utf8",
  maxBuffer: 64 * 1024 * 1024
});

if (result.status !== 0 || result.error) {
  const details = result.error?.message || result.stderr || "unknown error";
  useExistingOutput(`Failed to generate from SQLite: ${details}`);
  process.exit(0);
}

mkdirSync(dirname(outputPath), { recursive: true });

const nextContent = result.stdout;
const previousContent = existsSync(outputPath) ? readFileSync(outputPath, "utf8") : "";
if (previousContent === nextContent) {
  console.log(`[katakana-json] Up to date: ${outputPath}`);
  process.exit(0);
}

writeFileSync(outputPath, nextContent);
console.log(`[katakana-json] Generated: ${outputPath}`);
