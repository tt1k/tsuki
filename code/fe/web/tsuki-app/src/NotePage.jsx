import { useCallback, useEffect, useMemo, useRef, useState } from "react";
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
const URL_REGEX = /https?:\/\/[^\s]+/gi;
const NOTE_EXPORT_BG_BASE_NIGHT = { r: 18, g: 18, b: 18 };
const NOTE_EXPORT_BG_BASE_DAY = { r: 238, g: 243, b: 248 };

function parseRgbLikeColor(value = "") {
  const matched = String(value || "").match(/^rgba?\(([^)]+)\)$/i);
  if (!matched) {
    return null;
  }

  const parts = matched[1].split(",").map((part) => Number.parseFloat(part.trim()));
  if (parts.length < 3 || parts.slice(0, 3).some((part) => Number.isNaN(part))) {
    return null;
  }

  const alpha = parts.length >= 4 && !Number.isNaN(parts[3]) ? parts[3] : 1;
  return {
    r: Math.max(0, Math.min(255, parts[0])),
    g: Math.max(0, Math.min(255, parts[1])),
    b: Math.max(0, Math.min(255, parts[2])),
    a: Math.max(0, Math.min(1, alpha))
  };
}

function resolveOpaqueExportBackground(color, fallbackBase = NOTE_EXPORT_BG_BASE_NIGHT) {
  const parsed = parseRgbLikeColor(color);
  if (!parsed) {
    return "rgb(31, 31, 31)";
  }

  if (parsed.a >= 1) {
    return `rgb(${Math.round(parsed.r)}, ${Math.round(parsed.g)}, ${Math.round(parsed.b)})`;
  }

  const blend = (foreground, background, alpha) => Math.round(foreground * alpha + background * (1 - alpha));
  const r = blend(parsed.r, fallbackBase.r, parsed.a);
  const g = blend(parsed.g, fallbackBase.g, parsed.a);
  const b = blend(parsed.b, fallbackBase.b, parsed.a);
  return `rgb(${r}, ${g}, ${b})`;
}

function ThemeToggleIcon({ themeMode }) {
  if (themeMode === "day") {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path
          d="M12 4V2m0 20v-2m8-8h2M2 12h2m13.66 5.66 1.42 1.42M4.92 4.92l1.42 1.42m0 11.32-1.42 1.42m12.74-12.74 1.42-1.42M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10z"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    );
  }

  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path
        d="M14.8 3.5a8 8 0 1 0 5.7 12.7A9 9 0 0 1 14.8 3.5z"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path d="M18.6 5.1 19.1 6.4 20.4 6.9 19.1 7.4 18.6 8.7 18.1 7.4 16.8 6.9 18.1 6.4z" />
    </svg>
  );
}

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

function toFallbackTokens(text, language) {
  const source = String(text || "").trim();
  if (!source) {
    return [];
  }

  const segments = splitTextWithUrls(source);
  const tokens = [];

  const appendToken = (kanji) => {
    tokens.push({
      furigana: "",
      kanji,
      highlight: getTokenHighlight(kanji, tokens.length)
    });
  };

  if (typeof Intl !== "undefined" && Intl.Segmenter) {
    const segmenter = new Intl.Segmenter(language || "ja", { granularity: "word" });
    segments.forEach((segment) => {
      if (segment.type === "url") {
        appendToken(segment.value);
        return;
      }

      [...segmenter.segment(segment.value)]
        .map((item) => item.segment)
        .filter((item) => !isWhitespaceToken(item))
        .forEach((word) => appendToken(word));
    });

    if (tokens.length) {
      return tokens;
    }
  }

  segments.forEach((segment) => {
    if (segment.type === "url") {
      appendToken(segment.value);
      return;
    }

    segment.value
      .split("")
      .filter((char) => !isWhitespaceToken(char))
      .forEach((char) => appendToken(char));
  });

  return tokens;
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

export default function NotePage({
  language,
  onLanguageChange,
  languageOptions,
  productName,
  themeMode,
  onToggleTheme
}) {
  const noteCopy = useMemo(() => getNoteCopy(language), [language]);
  const [inputText, setInputText] = useState(() => noteCopy.defaultInput);
  const [inputCollapsed, setInputCollapsed] = useState(false);
  const [outputCollapsed, setOutputCollapsed] = useState(false);
  const [isExportingOutput, setIsExportingOutput] = useState(false);
  const [computedJaTokens, setComputedJaTokens] = useState(null);
  const outputCaptureRef = useRef(null);

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
  const openTsukiTranslateForToken = useCallback((text) => {
    const normalized = String(text || "").trim();
    if (!normalized) {
      return;
    }

    if (typeof window === "undefined" || typeof document === "undefined") {
      copyTokenText(normalized);
      return;
    }

    const encodedText = encodeURIComponent(normalized);
    const schemeUrl = `tsuki://translate?text=${encodedText}`;
    const timeoutMs = 1000;
    let resolved = false;
    let timeoutId;

    const cleanup = () => {
      document.removeEventListener("visibilitychange", handleVisibilityChange);
      window.removeEventListener("pagehide", handlePageHide);
      window.removeEventListener("blur", handleBlur);
      if (timeoutId) {
        window.clearTimeout(timeoutId);
      }
    };

    const resolveAsInstalled = () => {
      if (resolved) {
        return;
      }

      resolved = true;
      cleanup();
    };

    const handleVisibilityChange = () => {
      if (document.visibilityState === "hidden") {
        resolveAsInstalled();
      }
    };

    const handlePageHide = () => {
      resolveAsInstalled();
    };

    const handleBlur = () => {
      if (typeof document.hasFocus === "function" && !document.hasFocus()) {
        resolveAsInstalled();
      }
    };

    document.addEventListener("visibilitychange", handleVisibilityChange);
    window.addEventListener("pagehide", handlePageHide);
    window.addEventListener("blur", handleBlur);

    try {
      window.location.assign(schemeUrl);
    } catch {
      cleanup();
      copyTokenText(normalized);
      return;
    }

    timeoutId = window.setTimeout(() => {
      if (resolved) {
        return;
      }

      cleanup();
      copyTokenText(normalized);
    }, timeoutMs);
  }, [copyTokenText]);

  const exportOutputAsImage = useCallback(async () => {
    if (typeof window === "undefined" || typeof document === "undefined") {
      return;
    }

    const target = outputCaptureRef.current;
    if (!target || outputCollapsed) {
      return;
    }

    setIsExportingOutput(true);

    try {
      if (document.fonts?.ready) {
        await document.fonts.ready;
      }

      const { default: html2canvas } = await import("html2canvas");
      const scale = Math.max(1, Math.min(2, window.devicePixelRatio || 1));
      const outputCard = target.closest(".note-output-card");
      const cardBg = outputCard ? window.getComputedStyle(outputCard).backgroundColor : "";
      const baseBackground = themeMode === "day" ? NOTE_EXPORT_BG_BASE_DAY : NOTE_EXPORT_BG_BASE_NIGHT;
      const captureBackground = resolveOpaqueExportBackground(cardBg, baseBackground);
      const canvas = await html2canvas(target, {
        backgroundColor: captureBackground,
        scale,
        useCORS: true,
        logging: false
      });

      const pngBlob = await new Promise((resolve, reject) => {
        canvas.toBlob((blob) => {
          if (!blob) {
            reject(new Error("Failed to generate image blob"));
            return;
          }
          resolve(blob);
        }, "image/png");
      });

      const fallbackNameBase =
        String(outputModel.headwordKanji || outputModel.headwordKana || "output").trim() || "output";
      const timestamp = new Date().toISOString().replace(/[.:]/g, "-");
      const suggestedName = `tsuki-${fallbackNameBase}-${timestamp}.png`;

      if (typeof window.showSaveFilePicker === "function") {
        const fileHandle = await window.showSaveFilePicker({
          suggestedName,
          types: [
            {
              description: "PNG image",
              accept: {
                "image/png": [".png"]
              }
            }
          ]
        });
        const writable = await fileHandle.createWritable();
        await writable.write(pngBlob);
        await writable.close();
        return;
      }

      const downloadUrl = URL.createObjectURL(pngBlob);
      const link = document.createElement("a");
      link.href = downloadUrl;
      link.download = suggestedName;
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.setTimeout(() => URL.revokeObjectURL(downloadUrl), 0);
    } catch (error) {
      if (!(error && error.name === "AbortError")) {
        console.error("Failed to export output screenshot", error);
      }
    } finally {
      setIsExportingOutput(false);
    }
  }, [outputCollapsed, outputModel.headwordKana, outputModel.headwordKanji, themeMode]);

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
            <button
              type="button"
              className="theme-switch"
              aria-label={themeMode === "night" ? "Switch to day mode" : "Switch to night mode"}
              onClick={onToggleTheme}
            >
              <span className="theme-switch-icon">
                <ThemeToggleIcon themeMode={themeMode} />
              </span>
            </button>
          </div>
        </div>
      </header>

      <section className="note-shell container">
        <div className="note-card note-input-card">
          <div className="note-input-tools" role="toolbar" aria-label="input controls">
            <button
              type="button"
              className="note-input-tool"
              aria-label={inputCollapsed ? "Expand input" : "Collapse input"}
              aria-pressed={inputCollapsed}
              onClick={() => setInputCollapsed((prev) => !prev)}
            >
              <span className="note-input-tool-icon" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <path
                    d={inputCollapsed ? "M6 9l6 6 6-6" : "M6 15l6-6 6 6"}
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2.4"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              </span>
            </button>
          </div>

          {!inputCollapsed ? (
            <textarea
              id="note-input"
              value={inputText}
              onChange={(event) => setInputText(event.target.value)}
              placeholder={noteCopy.inputPlaceholder}
              className="note-input note-input-multiline"
              rows={8}
            />
          ) : null}
        </div>

        <div
          className={`note-card note-output-card${outputCollapsed ? " is-collapsed" : ""}`}
          aria-label="note output card"
        >
          <div className="note-input-tools" role="toolbar" aria-label="output controls">
            <button
              type="button"
              className="note-input-tool"
              aria-label={outputCollapsed ? "Expand output" : "Collapse output"}
              aria-pressed={outputCollapsed}
              onClick={() => setOutputCollapsed((prev) => !prev)}
            >
              <span className="note-input-tool-icon" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <path
                    d={outputCollapsed ? "M6 9l6 6 6-6" : "M6 15l6-6 6 6"}
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2.4"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              </span>
            </button>
            <button
              type="button"
              className="note-input-tool"
              aria-label="Export output as image"
              onClick={exportOutputAsImage}
              disabled={outputCollapsed || isExportingOutput}
            >
              <span className="note-input-tool-icon" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <path
                    d="M12 4v9m0 0l-4-4m4 4l4-4M6 15v4h12v-4"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2.2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              </span>
            </button>
          </div>

          {!outputCollapsed ? (
            <div className="note-output-content" ref={outputCaptureRef}>
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
                      onDoubleClick={showCapsule ? () => openTsukiTranslateForToken(token.kanji) : undefined}
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
          ) : null}
        </div>
      </section>
    </main>
  );
}
