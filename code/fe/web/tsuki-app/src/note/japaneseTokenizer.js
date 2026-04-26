let tokenizerPromise;
let scriptPromise;
const URL_REGEX = /https?:\/\/[^\s]+/gi;

function ensureKuromojiScriptLoaded() {
  if (typeof window === "undefined") {
    return Promise.reject(new Error("Window is not available"));
  }

  if (window.kuromoji) {
    return Promise.resolve();
  }

  if (!scriptPromise) {
    scriptPromise = new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = "/libs/kuromoji.js";
      script.async = true;
      script.onload = () => resolve();
      script.onerror = () => reject(new Error("Failed to load kuromoji.js"));
      document.head.appendChild(script);
    });
  }

  return scriptPromise;
}

async function buildTokenizer() {
  await ensureKuromojiScriptLoaded();

  return new Promise((resolve, reject) => {
    window.kuromoji.builder({ dicPath: "/dict/" }).build((error, tokenizer) => {
      if (error) {
        reject(error);
        return;
      }
      resolve(tokenizer);
    });
  });
}

function toHiragana(value = "") {
  return value.replace(/[\u30a1-\u30f6]/g, (char) =>
    String.fromCharCode(char.charCodeAt(0) - 0x60)
  );
}

function isPunctuation(surface = "") {
  return /^[、。！？,.!?・]$/.test(surface);
}

function splitTextWithUrls(value = "") {
  const source = String(value || "");
  const segments = [];
  let lastIndex = 0;

  URL_REGEX.lastIndex = 0;
  for (const match of source.matchAll(URL_REGEX)) {
    const matchIndex = match.index ?? -1;
    const matchedText = match[0] || "";
    if (matchIndex < 0 || !matchedText) {
      continue;
    }

    if (matchIndex > lastIndex) {
      segments.push({ type: "text", value: source.slice(lastIndex, matchIndex) });
    }

    segments.push({ type: "url", value: matchedText });
    lastIndex = matchIndex + matchedText.length;
  }

  if (lastIndex < source.length) {
    segments.push({ type: "text", value: source.slice(lastIndex) });
  }

  return segments.length > 0 ? segments : [{ type: "text", value: source }];
}

export async function tokenizeJapaneseWithReading(text = "") {
  const normalized = String(text || "");
  if (!normalized.trim()) {
    return [];
  }

  const segments = splitTextWithUrls(normalized);
  const hasTextSegments = segments.some(
    (segment) => segment.type === "text" && segment.value.trim().length > 0
  );

  let tokenizer = null;
  if (hasTextSegments) {
    if (!tokenizerPromise) {
      tokenizerPromise = buildTokenizer();
    }

    tokenizer = await tokenizerPromise;
  }

  return segments.flatMap((segment) => {
    if (segment.type === "url") {
      return [{ kanji: segment.value, furigana: "" }];
    }

    if (!tokenizer || !segment.value.trim()) {
      return [];
    }

    return tokenizer
      .tokenize(segment.value)
      .map((token) => {
        const surface = token.surface_form || "";
        const reading = token.reading ? toHiragana(token.reading) : "";

        return {
          kanji: surface,
          furigana: isPunctuation(surface) ? "" : reading
        };
      })
      .filter((token) => token.kanji.trim().length > 0);
  });
}
