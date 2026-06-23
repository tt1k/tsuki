const KATAKANA_WORD_REGEX = /^(?=.*[\u30A0-\u30FF\u31F0-\u31FF\uFF66-\uFF9D])[\u30A0-\u30FF\u31F0-\u31FF\uFF66-\uFF9D]+$/u;
const KATAKANA_ANNOTATION_URL = "/dict/katakana-en.json";

let annotationPromise;

function normalizeKatakanaLookupText(value = "") {
  return String(value || "").trim().normalize("NFKC");
}

export function isKatakanaWord(value = "") {
  const normalized = normalizeKatakanaLookupText(value);
  return Boolean(normalized) && KATAKANA_WORD_REGEX.test(normalized);
}

export function hasKatakanaAnnotationTargets(tokens = []) {
  return tokens.some((token) => isKatakanaWord(token?.kanji));
}

async function loadKatakanaAnnotations() {
  if (!annotationPromise) {
    annotationPromise = fetch(KATAKANA_ANNOTATION_URL)
      .then((response) => {
        if (!response.ok) {
          throw new Error(`Failed to load katakana annotations: ${response.status}`);
        }

        return response.json();
      })
      .catch((error) => {
        console.warn(error);
        return null;
      });
  }

  return annotationPromise;
}

export async function annotateKatakanaTokens(tokens = []) {
  if (!hasKatakanaAnnotationTargets(tokens)) {
    return tokens;
  }

  const annotations = await loadKatakanaAnnotations();
  if (!annotations) {
    return tokens;
  }

  let changed = false;
  const annotatedTokens = tokens.map((token) => {
    const lookupText = normalizeKatakanaLookupText(token?.kanji);
    const annotation = isKatakanaWord(lookupText) ? annotations[lookupText] : "";
    if (!annotation) {
      return token;
    }

    changed = true;
    return {
      ...token,
      annotation
    };
  });

  return changed ? annotatedTokens : tokens;
}
