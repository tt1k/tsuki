let tokenizerPromise;
let scriptPromise;
const DOMAIN_SOURCE = String.raw`(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}(?:\/[^\s"'<>)]*)?`;
const URL_SOURCE = String.raw`https?:\/\/[^\s"'<>)]{1,}|${DOMAIN_SOURCE}`;
const LINK_OR_URL_REGEX = new RegExp(
  String.raw`(!?)\[([^\]\r\n]+)\]\((${URL_SOURCE})\)|(${URL_SOURCE})`,
  "gi"
);
const LINE_BREAK_REGEX = /(?:\r\n|\r|\n)+/g;

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

function toUrlHref(value = "") {
  const normalized = String(value || "").trim();
  if (/^https?:\/\//i.test(normalized)) {
    return normalized;
  }

  return `https://${normalized}`;
}

function splitTextWithUrls(value = "") {
  const source = String(value || "");
  const segments = [];
  let lastIndex = 0;

  const appendTextSegments = (text) => {
    let textLastIndex = 0;

    LINE_BREAK_REGEX.lastIndex = 0;
    for (const match of text.matchAll(LINE_BREAK_REGEX)) {
      const matchIndex = match.index ?? -1;
      const matchedText = match[0] || "";
      if (matchIndex < 0 || !matchedText) {
        continue;
      }

      if (matchIndex > textLastIndex) {
        segments.push({ type: "text", value: text.slice(textLastIndex, matchIndex) });
      }

      segments.push({ type: "lineBreak", value: matchedText });
      textLastIndex = matchIndex + matchedText.length;
    }

    if (textLastIndex < text.length) {
      segments.push({ type: "text", value: text.slice(textLastIndex) });
    }
  };

  LINK_OR_URL_REGEX.lastIndex = 0;
  for (const match of source.matchAll(LINK_OR_URL_REGEX)) {
    const matchIndex = match.index ?? -1;
    const matchedText = match[0] || "";
    if (matchIndex < 0 || !matchedText) {
      continue;
    }

    if (matchIndex > lastIndex) {
      appendTextSegments(source.slice(lastIndex, matchIndex));
    }

    const isMarkdownImage = Boolean(match[1]);
    const markdownLabel = match[2] || "";
    const markdownHref = match[3] || "";
    const standaloneUrl = match[4] || "";

    if (markdownLabel && markdownHref) {
      segments.push({
        type: isMarkdownImage ? "imageLinkText" : "linkText",
        value: markdownLabel,
        href: toUrlHref(markdownHref)
      });
    } else {
      const urlValue = standaloneUrl || matchedText;
      segments.push({ type: "url", value: urlValue, href: toUrlHref(urlValue) });
    }

    lastIndex = matchIndex + matchedText.length;
  }

  if (lastIndex < source.length) {
    appendTextSegments(source.slice(lastIndex));
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
    (segment) =>
      (segment.type === "text" ||
        segment.type === "linkText" ||
        segment.type === "imageLinkText") &&
      segment.value.trim().length > 0
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
      return [{ kanji: segment.value, furigana: "", isUrl: true, urlHref: segment.href }];
    }

    if (segment.type === "linkText" || segment.type === "imageLinkText") {
      if (!tokenizer || !segment.value.trim()) {
        return [];
      }

      const labelTokens = tokenizer
        .tokenize(segment.value)
        .map((token) => {
          const surface = token.surface_form || "";
          const reading = token.reading ? toHiragana(token.reading) : "";

          return {
            kanji: surface,
            furigana: isPunctuation(surface) ? "" : reading,
            linkHref: segment.href
          };
        })
        .filter((token) => token.kanji.trim().length > 0);

      if (segment.type === "imageLinkText") {
        labelTokens.push({
          kanji: segment.href,
          furigana: "",
          isUrl: true,
          urlHref: segment.href
        });
      }

      return labelTokens;
    }

    if (segment.type === "lineBreak") {
      return [{ kanji: "", furigana: "", inputBreak: true }];
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
