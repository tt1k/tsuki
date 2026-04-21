let tokenizerPromise;
let scriptPromise;

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

export async function tokenizeJapaneseWithReading(text = "") {
  const normalized = String(text || "");
  if (!normalized.trim()) {
    return [];
  }

  if (!tokenizerPromise) {
    tokenizerPromise = buildTokenizer();
  }

  const tokenizer = await tokenizerPromise;
  const rawTokens = tokenizer.tokenize(normalized);

  return rawTokens
    .map((token) => {
      const surface = token.surface_form || "";
      const reading = token.reading ? toHiragana(token.reading) : "";

      return {
        kanji: surface,
        furigana: isPunctuation(surface) ? "" : reading
      };
    })
    .filter((token) => token.kanji.trim().length > 0);
}
