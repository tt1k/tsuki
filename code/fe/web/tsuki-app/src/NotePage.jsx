import { useCallback, useEffect, useMemo, useState } from "react";
import {
  NOTE_DEFAULT_INPUT_SET,
  NOTE_JA_ENTRIES,
  getNoteCopy
} from "./note/noteJaContent";
import { tokenizeJapaneseWithReading } from "./note/japaneseTokenizer";

const HIGHLIGHT_CLASS_MAP = {
  yellow: "token-capsule-yellow",
  purple: "token-capsule-purple",
  green: "token-capsule-green",
  blue: "token-capsule-blue",
  gray: "token-capsule-gray"
};

const FALLBACK_HIGHLIGHTS = ["yellow", "purple", "green", "blue", "gray"];
const PUNCTUATION_REGEX = /^[、。！？,.!?・]$/;
const SENTENCE_BREAK_REGEX = /[。.]/;
const KANA_ONLY_REGEX = /^[\u3040-\u309F\u30A0-\u30FFー]+$/;
const SYMBOL_ONLY_REGEX = /^[「」『』（）\[\]［］【】〈〉《》〔〕｛｝…‥〜～ー―\-・、。！？,.!?〆〃〇]+$/;

function isWhitespaceToken(value) {
  return !String(value).trim();
}

function getTokenHighlight(text, index) {
  if (PUNCTUATION_REGEX.test(text)) {
    return "gray";
  }

  return FALLBACK_HIGHLIGHTS[index % FALLBACK_HIGHLIGHTS.length];
}

function isKanaOnlyText(value) {
  const normalized = String(value || "").trim();
  return normalized.length > 0 && KANA_ONLY_REGEX.test(normalized);
}

function shouldHideFurigana(value) {
  const normalized = String(value || "").trim();
  if (!normalized) {
    return true;
  }

  return isKanaOnlyText(normalized) || SYMBOL_ONLY_REGEX.test(normalized);
}

function toFallbackTokens(text, language) {
  const source = String(text || "").trim();
  if (!source) {
    return [];
  }

  if (typeof Intl !== "undefined" && Intl.Segmenter) {
    const segmenterLanguage = language || "ja";
    const segmenter = new Intl.Segmenter(segmenterLanguage, { granularity: "word" });
    const words = [...segmenter.segment(source)]
      .map((item) => item.segment)
      .filter((item) => !isWhitespaceToken(item));

    if (words.length) {
      return words.map((kanji, index) => ({
        furigana: "",
        kanji,
        highlight: getTokenHighlight(kanji, index)
      }));
    }
  }

  return source
    .split("")
    .filter((char) => !isWhitespaceToken(char))
    .map((kanji, index) => ({
      furigana: "",
      kanji,
      highlight: getTokenHighlight(kanji, index)
    }));
}

function resolveOutputModel(inputText, language, noteCopy) {
  const normalized = String(inputText || "").trim();
  const exactMatch = NOTE_JA_ENTRIES.find((entry) => entry.source === normalized);
  if (exactMatch) {
    return exactMatch;
  }

  return {
    headwordKanji: noteCopy.fallbackHeadwordKanji,
    headwordKana: noteCopy.fallbackHeadwordKana,
    meaning: noteCopy.fallbackMeaning,
    tokens: toFallbackTokens(normalized, language)
  };
}

function withSentenceBreaks(tokens = []) {
  const items = [];
  let lineNumber = 1;

  if (tokens.length > 0) {
    items.push({ type: "break", key: "break-initial", lineNumber });
  }

  tokens.forEach((token, index) => {
    items.push({ type: "token", token, key: `token-${index}` });

    if (SENTENCE_BREAK_REGEX.test(token.kanji || "") && index < tokens.length - 1) {
      lineNumber += 1;
      items.push({ type: "break", key: `break-${index}`, lineNumber });
    }
  });

  if (tokens.length > 0) {
    items.push({ type: "break", key: "break-final" });
  }

  return items;
}

export default function NotePage({ language, onLanguageChange, languageOptions, productName }) {
  const noteCopy = useMemo(() => getNoteCopy(language), [language]);
  const [inputText, setInputText] = useState(() => noteCopy.defaultInput);
  const [computedJaTokens, setComputedJaTokens] = useState(null);

  useEffect(() => {
    if (!inputText.trim() || NOTE_DEFAULT_INPUT_SET.has(inputText)) {
      setInputText(noteCopy.defaultInput);
    }
  }, [language]);

  const exactJaEntry = useMemo(
    () => NOTE_JA_ENTRIES.find((entry) => entry.source === String(inputText || "").trim()) || null,
    [inputText]
  );

  useEffect(() => {
    let cancelled = false;

    if (language !== "ja" || !inputText.trim() || exactJaEntry) {
      setComputedJaTokens(null);
      return undefined;
    }

    tokenizeJapaneseWithReading(inputText)
      .then((tokens) => {
        if (cancelled) {
          return;
        }

        setComputedJaTokens(
          tokens.map((token, index) => ({
            furigana: token.furigana,
            kanji: token.kanji,
            highlight: getTokenHighlight(token.kanji, index)
          }))
        );
      })
      .catch(() => {
        if (!cancelled) {
          setComputedJaTokens(null);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [language, inputText, exactJaEntry]);

  const baseOutputModel = useMemo(
    () => resolveOutputModel(inputText, language, noteCopy),
    [inputText, language, noteCopy]
  );
  const outputModel = useMemo(() => {
    if (language === "ja" && computedJaTokens && computedJaTokens.length > 0) {
      return {
        ...baseOutputModel,
        tokens: computedJaTokens
      };
    }

    return baseOutputModel;
  }, [baseOutputModel, computedJaTokens, language]);
  const outputItems = useMemo(() => withSentenceBreaks(outputModel.tokens), [outputModel.tokens]);
  const copyTokenText = useCallback((text) => {
    const normalized = String(text || "").trim();
    if (!normalized || typeof navigator === "undefined" || !navigator.clipboard?.writeText) {
      return;
    }

    void navigator.clipboard.writeText(normalized);
  }, []);

  return (
    <main className="note-page-wrap">
      <header className="nav">
        <div className="container nav-inner">
          <div className="nav-left">
            <a href="/" className="brand">
              <span className="brand-dot" aria-hidden="true" />
              <span>{productName}</span>
            </a>
            <label className="lang-switch" htmlFor="note-lang-select">
              <span className="sr-only">language</span>
              <span className="lang-switch-icon" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <path d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2zm7.93 9h-3.02a15.2 15.2 0 0 0-1.22-5A8.03 8.03 0 0 1 19.93 11zM12 4.05c.8.98 1.85 3.22 2.33 6.95H9.67C10.15 7.27 11.2 5.03 12 4.05zM4.07 13h3.02a15.2 15.2 0 0 0 1.22 5A8.03 8.03 0 0 1 4.07 13zM7.09 11H4.07a8.03 8.03 0 0 1 4.24-5 15.2 15.2 0 0 0-1.22 5zM12 19.95c-.8-.98-1.85-3.22-2.33-6.95h4.66c-.48 3.73-1.53 5.97-2.33 6.95zM15.69 18a15.2 15.2 0 0 0 1.22-5h3.02a8.03 8.03 0 0 1-4.24 5z" />
                </svg>
              </span>
              <select
                id="note-lang-select"
                value={language}
                onChange={(event) => onLanguageChange(event.target.value)}
              >
                {languageOptions.map((item) => (
                  <option value={item.code} key={item.code}>
                    {item.label}
                  </option>
                ))}
              </select>
            </label>
          </div>
        </div>
      </header>

      <section className="note-shell container">
        <div className="note-card note-input-card">
          <label className="note-card-label" htmlFor="note-input">
            {noteCopy.inputLabel}
          </label>
          <textarea
            id="note-input"
            value={inputText}
            onChange={(event) => setInputText(event.target.value)}
            placeholder={noteCopy.inputPlaceholder}
            className="note-input note-input-multiline"
            maxLength={800}
            rows={8}
          />
        </div>

        <div className="note-card note-output-card" aria-label="note output card">
          <p className="note-card-label">{noteCopy.outputLabel}</p>

          {outputModel.headwordKanji || outputModel.headwordKana ? (
            <div className="note-headword-row">
              <span className="note-headword-kanji">{outputModel.headwordKanji}</span>
              <span className="note-headword-kana">{outputModel.headwordKana}</span>
            </div>
          ) : null}

          {outputModel.meaning ? <p className="note-meaning">{outputModel.meaning}</p> : null}

          <div className="note-token-flow">
            {outputItems.map((item) => {
              if (item.type === "break") {
                return (
                  <span key={item.key} className="note-token-break" aria-hidden="true">
                    {typeof item.lineNumber === "number" ? (
                      <span className="note-token-line-no">#{item.lineNumber}</span>
                    ) : null}
                  </span>
                );
              }

              const token = item.token;
              const capsuleClass = HIGHLIGHT_CLASS_MAP[token.highlight] || HIGHLIGHT_CLASS_MAP.gray;
              const hideFurigana = shouldHideFurigana(token.kanji);
              const showCapsule = !hideFurigana && !PUNCTUATION_REGEX.test(token.kanji || "");
              const furigana = hideFurigana ? "" : token.furigana;
              const hoverableClass = showCapsule ? " note-token-item-hoverable" : "";
              const plainClass = showCapsule ? "" : " note-token-item-plain";
              return (
                <span
                  className={`note-token-item${hoverableClass}${plainClass}`}
                  key={item.key}
                  onClick={showCapsule ? () => copyTokenText(token.kanji) : undefined}
                  onDoubleClick={showCapsule ? () => copyTokenText(token.kanji) : undefined}
                >
                  <span className="note-token-furigana">{furigana || " "}</span>
                  <span className="note-token-text">{token.kanji}</span>
                  {showCapsule ? (
                    <span className={`note-token-capsule ${capsuleClass}`} aria-hidden="true" />
                  ) : null}
                </span>
              );
            })}
          </div>
        </div>
      </section>
    </main>
  );
}
