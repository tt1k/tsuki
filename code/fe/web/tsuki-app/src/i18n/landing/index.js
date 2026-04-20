import jaPack from "./ja";

const LANGUAGE_LOADERS = {
  "zh-CN": () => import("./zh-CN"),
  "zh-TW": () => import("./zh-TW"),
  en: () => import("./en"),
  ja: () => Promise.resolve({ default: jaPack }),
  ko: () => import("./ko"),
  es: () => import("./es"),
  fr: () => import("./fr"),
  de: () => import("./de"),
  ru: () => import("./ru")
};

const packCache = new Map();

function normalizeLanguage(language) {
  return LANGUAGE_LOADERS[language] ? language : "ja";
}

export function getFallbackLandingPack() {
  return jaPack;
}

export async function loadLandingLanguagePack(language) {
  const normalizedLanguage = normalizeLanguage(language);

  if (packCache.has(normalizedLanguage)) {
    return packCache.get(normalizedLanguage);
  }

  const packPromise = LANGUAGE_LOADERS[normalizedLanguage]()
    .then((module) => module.default)
    .catch(() => jaPack);

  packCache.set(normalizedLanguage, packPromise);
  return packPromise;
}

export function preloadLandingLanguagePack(language) {
  void loadLandingLanguagePack(language);
}
