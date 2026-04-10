import json
import os
from urllib import error, request


API_KEY = os.getenv("DEEPSEEK_API_KEY")
if not API_KEY:
    raise RuntimeError("Please set the DEEPSEEK_API_KEY environment variable first")

API_URL = "https://api.deepseek.com/chat/completions"
MODEL = "deepseek-chat"
EXPECTED_KEYS = ("kanji", "reading", "meaning", "example")
ALLOWED_LANGS = {"en", "cn", "ja"}


def _extract_json(text: str) -> dict:
    text = text.strip()
    if text.startswith("```"):
        parts = text.split("```")
        if len(parts) >= 3:
            text = parts[1]
            if text.startswith("json"):
                text = text[4:]
            text = text.strip()
    return json.loads(text)


def _normalize_fields(obj: dict) -> dict:
    if not isinstance(obj, dict):
        raise RuntimeError(f"Expected a JSON object, got: {type(obj).__name__}")

    key_map = {
        "kanji": "kanji",
        "standard form": "kanji",
        "standard_form": "kanji",
        "reading": "reading",
        "meaning": "meaning",
        "meanings": "meaning",
        "common Chinese meanings": "meaning",
        "common_chinese_meanings": "meaning",
        "example": "example",
        "example sentence": "example",
        "example_sentence": "example",
    }

    normalized = {}
    for raw_key, value in obj.items():
        mapped = key_map.get(str(raw_key).strip().lower())
        if mapped and mapped not in normalized:
            normalized[mapped] = value

    missing = [k for k in EXPECTED_KEYS if k not in normalized]
    if missing:
        raise RuntimeError(
            f"Missing required fields: {', '.join(missing)}. Raw output: {obj}"
        )

    return {k: normalized[k] for k in EXPECTED_KEYS}


def get_word_info(word: str, lang: str = "cn") -> dict:
    lang = lang.strip().lower()
    if lang not in ALLOWED_LANGS:
        raise ValueError("lang must be one of: en, cn, ja")

    meaning_lang_hint = {
        "en": "English",
        "cn": "Chinese",
        "ja": "Japanese",
    }[lang]

    prompt = f"""
You are a Japanese dictionary assistant.

Task:
Given a Japanese word, return a JSON object with exactly these keys:
- kanji
- reading
- meaning (2-4 common meanings, separated by ;, must be written in {meaning_lang_hint})
- example (one natural Japanese sentence that contains the word)

Requirements:
- output JSON only
- no explanations
- no extra fields
- reading must be in hiragana
- meaning language must match lang={lang}

Word: {word}
"""

    payload = {
        "model": MODEL,
        "messages": [
            {
                "role": "system",
                "content": "You are an assistant that outputs strict JSON only.",
            },
            {
                "role": "user",
                "content": prompt,
            },
        ],
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
    }
    req = request.Request(
        API_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with request.urlopen(req, timeout=60) as resp:
            body = resp.read().decode("utf-8")
    except error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"DeepSeek API request failed: HTTP {exc.code} - {detail}"
        ) from exc
    except error.URLError as exc:
        raise RuntimeError(f"Network request failed: {exc.reason}") from exc

    try:
        data = json.loads(body)
        text = data["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"Unable to parse DeepSeek response: {body}") from exc

    try:
        return _normalize_fields(_extract_json(text))
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Model returned invalid JSON: {text}") from exc


if __name__ == "__main__":
    input_payload = {
        "word": "結構",
        "lang": "cn",
    }
    output_payload = get_word_info(input_payload["word"], input_payload["lang"])
    print(f"req: {json.dumps(input_payload, ensure_ascii=False, indent=2)}")
    print()
    print(f"res: {json.dumps(output_payload, ensure_ascii=False, indent=2)}")
