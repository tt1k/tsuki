import { Suspense, lazy, useCallback, useEffect, useMemo, useRef, useState } from "react";
import MdEntryPanel from "./MdEntryPanel";
import { getMdEntryCta, getMdEntryHeading, getMdEntrySub } from "./md-entry-copy";
import SiteFooter from "./SiteFooter";
import {
  getFallbackLandingPack,
  loadLandingLanguagePack,
  preloadLandingLanguagePack
} from "./i18n/landing";
import { collectFilesFromDataTransfer } from "./md-drop-utils";

const MdViewerPage = lazy(() => import("./MdViewerPage"));
const NotePage = lazy(() => import("./NotePage"));

function normalizeEntryPath(path = "") {
  return String(path)
    .replaceAll("\\", "/")
    .replace(/^\.\//, "")
    .replace(/^\/+/, "")
    .replace(/\/+/g, "/");
}

function stripCommonRootFolder(entries) {
  if (entries.length <= 1) {
    return entries;
  }

  const firstSegment = entries[0].path.split("/")[0];
  if (!firstSegment) {
    return entries;
  }

  const hasSingleRoot = entries.every((item) => item.path.startsWith(`${firstSegment}/`));
  if (!hasSingleRoot) {
    return entries;
  }

  return entries.map((item) => ({
    ...item,
    path: item.path.slice(firstSegment.length + 1)
  }));
}

function hasMarkdownEntries(entries = []) {
  const normalized = stripCommonRootFolder(
    entries.map((item) => ({
      ...item,
      path: normalizeEntryPath(item.path || "")
    }))
  );

  return normalized.some((item) => /\.md$/i.test(item.path) && !item.path.includes("/"));
}

async function collectFilesFromDirectoryHandle(directoryHandle, parentPath = "") {
  const entries = [];

  for await (const entry of directoryHandle.values()) {
    if (entry.kind === "file") {
      const file = await entry.getFile();
      entries.push({
        path: `${parentPath}${entry.name}`,
        file
      });
      continue;
    }

    if (entry.kind === "directory") {
      const nestedEntries = await collectFilesFromDirectoryHandle(
        entry,
        `${parentPath}${entry.name}/`
      );
      entries.push(...nestedEntries);
    }
  }

  return entries;
}

const LANGUAGES = [
  { code: "zh-CN", label: "中文" },
  { code: "zh-TW", label: "繁體中文" },
  { code: "en", label: "English" },
  { code: "ja", label: "日本語" },
  { code: "ko", label: "Korean" },
  { code: "es", label: "Spanish" },
  { code: "fr", label: "French" },
  { code: "de", label: "German" },
  { code: "ru", label: "Russian" }
];

const PRODUCT_NAMES = {
  ja: "月の言葉",
  "zh-CN": "言叶之月",
  "zh-TW": "言葉之月",
  en: "Tsuki Translate"
};

const PRODUCT_IMAGES = {
  ja: "/main/main_ja.png",
  "zh-CN": "/main/main_zh-CN.png",
  "zh-TW": "/main/main_zh-TW.png",
  en: "/main/main_en.png",
  ko: "/main/main_ko.png",
  es: "/main/main_es.png",
  fr: "/main/main_fr.png",
  de: "/main/main_de.png",
  ru: "/main/main_ru.png"
};

const MARKDOWN_IMAGES = {
  ja: "/markdown/markdown_ja.png",
  "zh-CN": "/markdown/markdown_zh-CN.png",
  "zh-TW": "/markdown/markdown_zh-TW.png",
  en: "/markdown/markdown_en.png",
  ko: "/markdown/markdown_kr.png",
  es: "/markdown/markdown_es.png",
  fr: "/markdown/markdown_fr.png",
  de: "/markdown/markdown_de.png",
  ru: "/markdown/markdown_ru.png"
};

const FALLBACK_LANDING_PACK = getFallbackLandingPack();

const RELEASE_URL = "https://github.com/tt1k/tsuki/releases";
const LANGUAGE_COOKIE_KEY = "tsuki_lang";

function readLanguageFromCookie() {
  if (typeof document === "undefined") {
    return "ja";
  }

  const cookies = document.cookie ? document.cookie.split(";") : [];
  for (const cookieItem of cookies) {
    const [rawKey, ...rawValueParts] = cookieItem.trim().split("=");
    if (rawKey !== LANGUAGE_COOKIE_KEY) {
      continue;
    }

    const value = decodeURIComponent(rawValueParts.join("="));
    return value || "ja";
  }

  return "ja";
}

function persistLanguageToCookie(language) {
  if (typeof document === "undefined") {
    return;
  }

  const maxAge = 60 * 60 * 24 * 365;
  document.cookie = `${LANGUAGE_COOKIE_KEY}=${encodeURIComponent(language)}; path=/; max-age=${maxAge}; samesite=lax`;
}

function AppleDownloadIcon() {
  return (
    <svg className="v6-apple-icon" width="16" height="16" viewBox="0 0 814 1000" fill="currentColor" aria-hidden="true">
      <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76.5 0-103.7 40.8-165.9 40.8s-105.6-57.8-155.5-127.4c-58.8-82-106.5-209.3-106.5-330.5 0-194.6 126.4-298.1 250.8-298.1 66.1 0 121.2 43.4 162.7 43.4 39.5 0 101.1-46 176.3-46 28.5 0 130.9 2.6 198.3 99.2zM554.1 159.4c31.1-36.9 53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.5 32.4-55.1 83.6-55.1 135.5 0 7.8 1.3 15.6 1.9 18.1 3.2.6 8.4 1.3 13.6 1.3 45.4 0 103.5-30.4 135.5-71.3z" />
    </svg>
  );
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

function App() {
  const [pathname, setPathname] = useState(() =>
    typeof window === "undefined" ? "/" : window.location.pathname
  );
  const folderInputRef = useRef(null);
  const [mdInitialEntries, setMdInitialEntries] = useState([]);
  const [mdEntryDragging, setMdEntryDragging] = useState(false);
  const [noMarkdownModalOpen, setNoMarkdownModalOpen] = useState(false);
  const [modalMessage, setModalMessage] = useState("");

  const preloadMdViewerPage = useCallback(() => {
    void import("./MdViewerPage");
  }, []);

  const preloadNotePage = useCallback(() => {
    void import("./NotePage");
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") {
      return undefined;
    }

    const onPopState = () => setPathname(window.location.pathname);
    window.addEventListener("popstate", onPopState);

    return () => {
      window.removeEventListener("popstate", onPopState);
    };
  }, []);

  const navigateToMd = useCallback((initialEntries = []) => {
    preloadMdViewerPage();
    if (typeof window !== "undefined" && window.location.pathname !== "/md") {
      window.history.pushState(null, "", "/md");
    }
    setMdInitialEntries(initialEntries);
    setPathname("/md");
  }, [preloadMdViewerPage]);

  const navigateToRoute = useCallback((routePath) => {
    if (typeof window !== "undefined" && window.location.pathname !== routePath) {
      window.history.pushState(null, "", routePath);
    }
    setPathname(routePath);
  }, []);

  const openNotePage = useCallback(() => {
    preloadNotePage();
    navigateToRoute("/note");
  }, [navigateToRoute, preloadNotePage]);

  const [language, setLanguage] = useState(() => {
    const savedLanguage = readLanguageFromCookie();
    return LANGUAGES.some((item) => item.code === savedLanguage) ? savedLanguage : "ja";
  });
  const [themeMode, setThemeMode] = useState("night");
  const [landingPack, setLandingPack] = useState(() => FALLBACK_LANDING_PACK);

  useEffect(() => {
    if (typeof document === "undefined") {
      return;
    }

    document.body.dataset.theme = themeMode;
  }, [themeMode]);

  useEffect(() => {
    let cancelled = false;

    loadLandingLanguagePack(language).then((nextPack) => {
      if (!cancelled) {
        setLandingPack(nextPack);
      }
    });

    return () => {
      cancelled = true;
    };
  }, [language]);

  const onLanguageChange = useCallback((nextLanguage) => {
    setLanguage(nextLanguage);
    persistLanguageToCookie(nextLanguage);
    preloadLandingLanguagePack(nextLanguage);
  }, []);
  const toggleThemeMode = useCallback(() => {
    setThemeMode((prev) => (prev === "night" ? "day" : "night"));
  }, []);
  const t = useMemo(
    () => ({
      ...(landingPack?.landing ?? FALLBACK_LANDING_PACK.landing),
      mdEntryHeading: getMdEntryHeading(language),
      mdEntrySub: getMdEntrySub(language),
      mdEntryCta: getMdEntryCta(language)
    }),
    [language, landingPack]
  );
  const modalCopy = useMemo(
    () => landingPack?.modal ?? FALLBACK_LANDING_PACK.modal,
    [landingPack]
  );
  const productName = useMemo(() => PRODUCT_NAMES[language] ?? PRODUCT_NAMES.ja, [language]);
  const productImage = useMemo(() => PRODUCT_IMAGES[language] ?? PRODUCT_IMAGES.ja, [language]);
  const markdownImage = useMemo(() => MARKDOWN_IMAGES[language] ?? MARKDOWN_IMAGES.ja, [language]);
  const markdownPreviewCopy = useMemo(
    () => landingPack?.markdownPreview ?? FALLBACK_LANDING_PACK.markdownPreview,
    [landingPack]
  );
  const closeNoMarkdownModal = useCallback(() => {
    setNoMarkdownModalOpen(false);
    setModalMessage("");
  }, []);
  const openNoticeModal = useCallback((message) => {
    setModalMessage(message);
    setNoMarkdownModalOpen(true);
  }, []);
  const notifyNoMarkdown = useCallback(() => {
    openNoticeModal(t.mdEntryNoMarkdown);
  }, [openNoticeModal, t.mdEntryNoMarkdown]);
  const notifyPermissionDenied = useCallback(() => {
    openNoticeModal(t.mdEntryPermissionDenied ?? "Folder access was not granted");
  }, [openNoticeModal, t.mdEntryPermissionDenied]);

  useEffect(() => {
    if (!noMarkdownModalOpen || typeof window === "undefined") {
      return undefined;
    }

    const onKeyDown = (event) => {
      if (event.key === "Escape") {
        setNoMarkdownModalOpen(false);
      }
    };

    window.addEventListener("keydown", onKeyDown);
    return () => {
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [noMarkdownModalOpen]);

  const openFolderPicker = useCallback(async () => {
    preloadMdViewerPage();

    if (typeof window !== "undefined" && typeof window.showDirectoryPicker === "function") {
      try {
        const directoryHandle = await window.showDirectoryPicker({ mode: "read" });

        if (typeof directoryHandle.requestPermission === "function") {
          const permissionState = await directoryHandle.requestPermission({ mode: "read" });
          if (permissionState !== "granted") {
            notifyPermissionDenied();
            return;
          }
        }

        const entries = await collectFilesFromDirectoryHandle(directoryHandle);
        if (!hasMarkdownEntries(entries)) {
          notifyNoMarkdown();
          return;
        }

        navigateToMd(entries);
        return;
      } catch (error) {
        const errorName = typeof error === "object" && error ? error.name : "";

        if (
          errorName === "AbortError" ||
          errorName === "NotAllowedError" ||
          errorName === "SecurityError"
        ) {
          notifyPermissionDenied();
          return;
        }
      }
    }

    folderInputRef.current?.click();
  }, [navigateToMd, notifyNoMarkdown, notifyPermissionDenied, preloadMdViewerPage]);

  const onFolderInputChange = useCallback(
    (event) => {
      preloadMdViewerPage();

      const files = Array.from(event.target.files ?? []);

      if (!files.length) {
        event.target.value = "";
        return;
      }

      const entries = files.map((file) => ({
        path: file.webkitRelativePath || file.name,
        file
      }));

      if (!hasMarkdownEntries(entries)) {
        notifyNoMarkdown();
        event.target.value = "";
        return;
      }

      navigateToMd(entries);
      event.target.value = "";
    },
    [navigateToMd, notifyNoMarkdown, preloadMdViewerPage]
  );
  const onMdPanelKeyDown = useCallback(
    (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        openFolderPicker();
      }
    },
    [openFolderPicker]
  );
  const onMdPanelDragOver = useCallback(
    (event) => {
      event.preventDefault();
      setMdEntryDragging(true);
      preloadMdViewerPage();
    },
    [preloadMdViewerPage]
  );
  const onMdPanelDragLeave = useCallback((event) => {
    event.preventDefault();
    setMdEntryDragging(false);
  }, []);
  const onMdPanelDrop = useCallback(
    async (event) => {
      event.preventDefault();
      setMdEntryDragging(false);
      preloadMdViewerPage();

      try {
        const droppedFiles = await collectFilesFromDataTransfer(event.dataTransfer);
        if (!hasMarkdownEntries(droppedFiles)) {
          notifyNoMarkdown();
          return;
        }
        navigateToMd(droppedFiles);
      } catch {
        notifyNoMarkdown();
      }
    },
    [navigateToMd, notifyNoMarkdown, preloadMdViewerPage]
  );
  const featureItems = useMemo(
    () => [
      { title: t.f1Title, desc: t.f1Desc },
      { title: t.f2Title, desc: t.f2Desc },
      { title: t.f3Title, desc: t.f3Desc },
      { title: t.f4Title, desc: t.f4Desc },
      { title: t.f5Title, desc: t.f5Desc },
      { title: t.f6Title, desc: t.f6Desc }
    ],
    [t.f1Desc, t.f1Title, t.f2Desc, t.f2Title, t.f3Desc, t.f3Title, t.f4Desc, t.f4Title, t.f5Desc, t.f5Title, t.f6Desc, t.f6Title]
  );

  if (pathname === "/md") {
    return (
      <Suspense fallback={<main className="container"><section className="hero"><p>{t.statusReady}...</p></section></main>}>
        <MdViewerPage
          initialEntries={mdInitialEntries}
          onInitialEntriesConsumed={() => setMdInitialEntries([])}
          language={language}
          onLanguageChange={onLanguageChange}
          languageOptions={LANGUAGES}
          productName={productName}
        />
      </Suspense>
    );
  }

  if (pathname === "/note") {
    return (
      <Suspense fallback={<main className="container"><section className="hero"><p>{t.statusReady}...</p></section></main>}>
        <NotePage
          language={language}
          onLanguageChange={onLanguageChange}
          languageOptions={LANGUAGES}
          productName={productName}
          themeMode={themeMode}
          onToggleTheme={toggleThemeMode}
        />
      </Suspense>
    );
  }

  return (
    <>
      <header className="nav">
        <div className="container nav-inner">
          <div className="nav-left">
            <a href="#" className="brand">
              <span className="brand-dot" aria-hidden="true" />
              <span>{productName}</span>
            </a>
            <label className="lang-switch" htmlFor="lang-select">
              <span className="sr-only">language</span>
              <span className="lang-switch-icon" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <path d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2zm7.93 9h-3.02a15.2 15.2 0 0 0-1.22-5A8.03 8.03 0 0 1 19.93 11zM12 4.05c.8.98 1.85 3.22 2.33 6.95H9.67C10.15 7.27 11.2 5.03 12 4.05zM4.07 13h3.02a15.2 15.2 0 0 0 1.22 5A8.03 8.03 0 0 1 4.07 13zM7.09 11H4.07a8.03 8.03 0 0 1 4.24-5 15.2 15.2 0 0 0-1.22 5zM12 19.95c-.8-.98-1.85-3.22-2.33-6.95h4.66c-.48 3.73-1.53 5.97-2.33 6.95zM15.69 18a15.2 15.2 0 0 0 1.22-5h3.02a8.03 8.03 0 0 1-4.24 5z" />
                </svg>
              </span>
              <select
                  id="lang-select"
                  value={language}
                  onChange={(event) => onLanguageChange(event.target.value)}
                >
                {LANGUAGES.map((item) => (
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
              onClick={toggleThemeMode}
            >
              <span className="theme-switch-icon">
                <ThemeToggleIcon themeMode={themeMode} />
              </span>
            </button>
          </div>
          <div className="nav-actions">
            <button
              type="button"
              className="btn btn-ghost"
              onClick={openNotePage}
              onMouseEnter={preloadNotePage}
            >
              {t.noteBtn}
            </button>
            <a href={RELEASE_URL} className="btn btn-primary" target="_blank" rel="noreferrer">
              <AppleDownloadIcon />
              {t.lastCtaBtn}
            </a>
          </div>
        </div>
      </header>

      <main className="container">
        <section className="hero">
          <div className="hero-grid">
            <div>
              <h1>
                {t.heroTitleLine1}
                <br />
                {t.heroTitleLine2}
                <br />
                <span className="hero-accent">{productName}</span>
              </h1>
              <p>{t.heroDesc}</p>
              <a className="btn btn-primary" href={RELEASE_URL} target="_blank" rel="noreferrer">
                {t.ctaPrimary}
              </a>
              <a className="btn btn-ghost" href="#features">
                {t.ctaSecondary}
              </a>
            </div>
            <div className="hero-card">
              <img src={productImage} alt={`${productName} product preview`} />
            </div>
          </div>
        </section>

        <section className="section" id="features">
          <h2>{t.sectionFeatureTitle}</h2>
          <div className="feature-grid">
            {featureItems.map((item, index) => (
              <article className="feature" key={item.title}>
                <div className="feature-icon">{String(index + 1).padStart(2, "0")}</div>
                <h3>{item.title}</h3>
                <p>{item.desc}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="md-entry-section" aria-label="markdown drop entry">
          <input
            ref={folderInputRef}
            type="file"
            webkitdirectory=""
            multiple
            className="sr-only"
            onChange={onFolderInputChange}
          />
          <h2>{t.mdEntryHeading}</h2>
          <MdEntryPanel
            title={t.mdEntryTitle}
            sub={t.mdEntrySub}
            ctaLabel={t.mdEntryCta}
            isDragging={mdEntryDragging}
            ariaLabel="拖入文件夹后进入 Markdown 渲染页面"
            onPanelClick={openFolderPicker}
            onPanelKeyDown={onMdPanelKeyDown}
            onDragOver={onMdPanelDragOver}
            onDragLeave={onMdPanelDragLeave}
            onDrop={onMdPanelDrop}
            onCtaClick={openFolderPicker}
          />
          <div className="md-entry-preview" aria-label="markdown preview image">
            <p className="md-entry-preview-kicker">{markdownPreviewCopy.title}</p>
            <p className="md-entry-preview-sub">{markdownPreviewCopy.desc}</p>
            <div className="hero-card md-entry-preview-card">
              <img src={markdownImage} alt={`${productName} markdown preview`} loading="lazy" />
            </div>
          </div>
        </section>

        <section className="cta">
          <h2>{t.lastCtaTitle}</h2>
          <p>{t.lastCtaDesc}</p>
          <a className="btn btn-primary" href={RELEASE_URL} target="_blank" rel="noreferrer">
            <AppleDownloadIcon />
            {t.lastCtaBtn}
          </a>
        </section>
      </main>

      <SiteFooter productName={productName} />

      {noMarkdownModalOpen ? (
        <div
          className="app-modal-backdrop"
          role="presentation"
          onClick={closeNoMarkdownModal}
        >
          <div
            className="app-modal"
            role="dialog"
            aria-modal="true"
            aria-label="markdown validation"
            onClick={(event) => event.stopPropagation()}
          >
            <h3>{modalCopy.title}</h3>
            <p>{modalMessage || t.mdEntryNoMarkdown}</p>
            <button type="button" className="btn btn-primary" onClick={closeNoMarkdownModal}>
              {modalCopy.ok}
            </button>
          </div>
        </div>
      ) : null}
    </>
  );
}

export default App;
