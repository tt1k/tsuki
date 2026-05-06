import { memo, useCallback, useEffect, useMemo, useRef, useState } from "react";
import ReactMarkdown from "react-markdown";
import MdEntryPanel from "./MdEntryPanel";
import { getMdEntryCta, getMdEntryHeading, getMdEntrySub } from "./md-entry-copy";
import { collectFilesFromDataTransfer } from "./md-drop-utils";
import SiteFooter from "./SiteFooter";
import "./md-viewer.css";

const IMAGE_EXTENSIONS = new Set([".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".svg"]);
const RELEASE_URL = "https://github.com/tt1k/tsuki/releases";
const RAW_HTML_TAG_PATTERN = /<([a-z][\w-]*)(\s[^>]*)?>/i;

const UI_COPY = {
  ja: {
    title: getMdEntryHeading("ja"),
    subtitle: "フォルダはホームでドロップ；ここではレンダーと閲覧を行います",
    themeAria: "theme mode",
    themeLight: "ライト",
    themeDark: "ダーク",
    emptyHint: "フォルダをここにドロップ",
    emptySub: getMdEntrySub("ja"),
    emptyCta: getMdEntryCta("ja"),
    controlHeadingSize: "文字サイズ",
    controlImageWidth: "画像幅",
    controlImageAlign: "画像位置",
    controlLayout: "レイアウト",
    controlTheme: "テーマ",
    exportPdf: "PDF出力",
    resetConfig: "リセット",
    modalAcknowledge: "確認",
    modalOk: "確認",
    modalCancel: "キャンセル",
    exportPdfFilenameLabel: "出力ファイル名",
    exportPdfFilenamePlaceholder: "ファイル名を入力",
    exportPdfDarkHint:
      "現在はダークモードです；PDF 背景を黒にするには、印刷パネルで More settings -> Background graphics を有効にしてから続行してください",
    controlSizeSmall: "小",
    controlSizeMedium: "中",
    controlSizeLarge: "大",
    controlAlignLeft: "左",
    controlAlignCenter: "中",
    controlAlignRight: "右",
    controlLayoutSingle: "1列",
    controlLayoutDouble: "2列",
    pickerTitle: "Markdown ファイルを選択",
    placeholder: "フォルダをドロップするとここで Markdown をプレビューできます",
    imageMissing: "Image not found",
    errFileNotFound: "選択した Markdown ファイルが見つかりません",
    errReadFailed: "ファイルの解析に失敗しました",
    errDropFolder: "Markdown を含むフォルダをドロップしてください",
    errNoMarkdown: "Markdown ファイルが見つかりません"
  },
  "cn": {
    title: getMdEntryHeading("cn"),
    subtitle: "目录请在主页入口拖入，这里只负责渲染与浏览",
    themeAria: "theme mode",
    themeLight: "白天",
    themeDark: "黑夜",
    emptyHint: "把文件夹拖到这里",
    emptySub: getMdEntrySub("cn"),
    emptyCta: getMdEntryCta("cn"),
    controlHeadingSize: "文字大小",
    controlImageWidth: "图片宽度",
    controlImageAlign: "图片位置",
    controlLayout: "布局",
    controlTheme: "主题",
    exportPdf: "导出 PDF",
    resetConfig: "重置",
    modalAcknowledge: "确认",
    modalOk: "确定",
    modalCancel: "取消",
    exportPdfFilenameLabel: "导出文件名",
    exportPdfFilenamePlaceholder: "请输入文件名",
    exportPdfDarkHint:
      "当前是黑夜模式；为保证 PDF 背景为黑色，请在打印面板开启 More settings -> Background graphics；点击确定继续导出",
    controlSizeSmall: "小",
    controlSizeMedium: "中",
    controlSizeLarge: "大",
    controlAlignLeft: "左",
    controlAlignCenter: "中",
    controlAlignRight: "右",
    controlLayoutSingle: "单列",
    controlLayoutDouble: "双列",
    pickerTitle: "选择 Markdown 文件",
    placeholder: "拖入目录后即可在这里预览 Markdown 内容",
    imageMissing: "图片未找到",
    errFileNotFound: "未找到所选 Markdown 文件",
    errReadFailed: "文件解析失败",
    errDropFolder: "请拖入包含 Markdown 的文件夹",
    errNoMarkdown: "未检测到 Markdown 文件"
  },
  "tw": {
    title: getMdEntryHeading("tw"),
    subtitle: "目錄請在首頁入口拖入，這裡只負責渲染與瀏覽",
    themeAria: "theme mode",
    themeLight: "白天",
    themeDark: "黑夜",
    emptyHint: "把資料夾拖到這裡",
    emptySub: getMdEntrySub("tw"),
    emptyCta: getMdEntryCta("tw"),
    controlHeadingSize: "文字大小",
    controlImageWidth: "圖片寬度",
    controlImageAlign: "圖片位置",
    controlLayout: "佈局",
    controlTheme: "主題",
    exportPdf: "匯出 PDF",
    resetConfig: "重置",
    modalAcknowledge: "確認",
    modalOk: "確定",
    modalCancel: "取消",
    exportPdfFilenameLabel: "匯出檔名",
    exportPdfFilenamePlaceholder: "請輸入檔名",
    exportPdfDarkHint:
      "目前是黑夜模式；為了讓 PDF 背景維持黑色，請在列印面板開啟 More settings -> Background graphics；點擊確定繼續匯出",
    controlSizeSmall: "小",
    controlSizeMedium: "中",
    controlSizeLarge: "大",
    controlAlignLeft: "左",
    controlAlignCenter: "中",
    controlAlignRight: "右",
    controlLayoutSingle: "單欄",
    controlLayoutDouble: "雙欄",
    pickerTitle: "選擇 Markdown 檔案",
    placeholder: "拖入目錄後即可在這裡預覽 Markdown 內容",
    imageMissing: "圖片未找到",
    errFileNotFound: "未找到所選 Markdown 檔案",
    errReadFailed: "檔案解析失敗",
    errDropFolder: "請拖入包含 Markdown 的資料夾",
    errNoMarkdown: "未偵測到 Markdown 檔案"
  },
  en: {
    title: getMdEntryHeading("en"),
    subtitle: "Drop folders from the home entry; This page focuses on rendering and browsing",
    themeAria: "theme mode",
    themeLight: "Day",
    themeDark: "Night",
    emptyHint: "Drop a folder here",
    emptySub: getMdEntrySub("en"),
    emptyCta: getMdEntryCta("en"),
    controlHeadingSize: "Text size",
    controlImageWidth: "Image width",
    controlImageAlign: "Image align",
    controlLayout: "Layout",
    controlTheme: "Theme",
    exportPdf: "Export PDF",
    resetConfig: "Reset",
    modalAcknowledge: "Confirm",
    modalOk: "OK",
    modalCancel: "Cancel",
    exportPdfFilenameLabel: "Export filename",
    exportPdfFilenamePlaceholder: "Enter filename",
    exportPdfDarkHint:
      "Dark mode is enabled; To keep a black PDF background, turn on More settings -> Background graphics in the print dialog; then continue",
    controlSizeSmall: "S",
    controlSizeMedium: "M",
    controlSizeLarge: "L",
    controlAlignLeft: "Left",
    controlAlignCenter: "Center",
    controlAlignRight: "Right",
    controlLayoutSingle: "Single",
    controlLayoutDouble: "Double",
    pickerTitle: "Choose a Markdown file",
    placeholder: "Drop a directory to preview Markdown content here",
    imageMissing: "Image not found",
    errFileNotFound: "Selected Markdown file not found",
    errReadFailed: "Failed to parse file",
    errDropFolder: "Please drop a folder that includes Markdown files",
    errNoMarkdown: "No Markdown files detected"
  },
  ko: {
    title: getMdEntryHeading("ko"),
    subtitle: "폴더는 홈에서 드롭하세요; 이 페이지는 렌더링과 보기만 담당합니다",
    themeAria: "theme mode",
    themeLight: "라이트",
    themeDark: "다크",
    emptyHint: "폴더를 여기에 드롭하세요",
    emptySub: getMdEntrySub("ko"),
    emptyCta: getMdEntryCta("ko"),
    controlHeadingSize: "글자 크기",
    controlImageWidth: "이미지 너비",
    controlImageAlign: "이미지 정렬",
    controlLayout: "레이아웃",
    controlTheme: "테마",
    exportPdf: "PDF 내보내기",
    resetConfig: "재설정",
    modalAcknowledge: "확인",
    modalOk: "확인",
    modalCancel: "취소",
    exportPdfFilenameLabel: "내보낼 파일명",
    exportPdfFilenamePlaceholder: "파일명을 입력하세요",
    exportPdfDarkHint:
      "현재 다크 모드입니다; PDF 배경을 검은색으로 유지하려면 인쇄 패널에서 More settings -> Background graphics를 켜고 계속하세요",
    controlSizeSmall: "작게",
    controlSizeMedium: "중간",
    controlSizeLarge: "크게",
    controlAlignLeft: "왼쪽",
    controlAlignCenter: "가운데",
    controlAlignRight: "오른쪽",
    controlLayoutSingle: "단일",
    controlLayoutDouble: "2열",
    pickerTitle: "Markdown 파일 선택",
    placeholder: "디렉터리를 드롭하면 여기서 Markdown을 미리 볼 수 있습니다",
    imageMissing: "Image not found",
    errFileNotFound: "선택한 Markdown 파일을 찾을 수 없습니다",
    errReadFailed: "파일 파싱에 실패했습니다",
    errDropFolder: "Markdown이 포함된 폴더를 드롭하세요",
    errNoMarkdown: "Markdown 파일이 감지되지 않았습니다"
  },
  es: {
    title: getMdEntryHeading("es"),
    subtitle: "Suelta carpetas desde la pagina principal; Aqui solo renderizas y navegas",
    themeAria: "theme mode",
    themeLight: "Dia",
    themeDark: "Noche",
    emptyHint: "Suelta tu carpeta aqui",
    emptySub: getMdEntrySub("es"),
    emptyCta: getMdEntryCta("es"),
    controlHeadingSize: "Tamano de texto",
    controlImageWidth: "Ancho de imagen",
    controlImageAlign: "Alineacion",
    controlLayout: "Diseno",
    controlTheme: "Tema",
    exportPdf: "Exportar PDF",
    resetConfig: "Restablecer",
    modalAcknowledge: "Confirmar",
    modalOk: "OK",
    modalCancel: "Cancelar",
    exportPdfFilenameLabel: "Nombre del archivo",
    exportPdfFilenamePlaceholder: "Escribe el nombre",
    exportPdfDarkHint:
      "El modo oscuro esta activo; Para mantener fondo negro en PDF, activa More settings -> Background graphics en el panel de impresion; luego continua",
    controlSizeSmall: "Peq",
    controlSizeMedium: "Med",
    controlSizeLarge: "Gra",
    controlAlignLeft: "Izq",
    controlAlignCenter: "Centro",
    controlAlignRight: "Der",
    controlLayoutSingle: "Simple",
    controlLayoutDouble: "Doble",
    pickerTitle: "Elegir archivo Markdown",
    placeholder: "Suelta un directorio para previsualizar Markdown aqui",
    imageMissing: "Image not found",
    errFileNotFound: "No se encontro el archivo Markdown seleccionado",
    errReadFailed: "No se pudo analizar el archivo",
    errDropFolder: "Suelta una carpeta que contenga archivos Markdown",
    errNoMarkdown: "No se detectaron archivos Markdown"
  },
  fr: {
    title: getMdEntryHeading("fr"),
    subtitle: "Deposez les dossiers depuis l'accueil; Cette page sert au rendu et a la lecture",
    themeAria: "theme mode",
    themeLight: "Jour",
    themeDark: "Nuit",
    emptyHint: "Deposez un dossier ici",
    emptySub: getMdEntrySub("fr"),
    emptyCta: getMdEntryCta("fr"),
    controlHeadingSize: "Taille du texte",
    controlImageWidth: "Largeur d'image",
    controlImageAlign: "Alignement",
    controlLayout: "Mise en page",
    controlTheme: "Theme",
    exportPdf: "Exporter PDF",
    resetConfig: "Reinitialiser",
    modalAcknowledge: "Confirmer",
    modalOk: "OK",
    modalCancel: "Annuler",
    exportPdfFilenameLabel: "Nom du fichier",
    exportPdfFilenamePlaceholder: "Saisir le nom",
    exportPdfDarkHint:
      "Le mode sombre est actif; Pour garder un fond PDF noir, activez More settings -> Background graphics dans la boite d'impression; puis continuez",
    controlSizeSmall: "Petit",
    controlSizeMedium: "Moyen",
    controlSizeLarge: "Grand",
    controlAlignLeft: "Gauche",
    controlAlignCenter: "Centre",
    controlAlignRight: "Droite",
    controlLayoutSingle: "Simple",
    controlLayoutDouble: "Double",
    pickerTitle: "Choisir un fichier Markdown",
    placeholder: "Deposez un dossier pour previsualiser le Markdown ici",
    imageMissing: "Image not found",
    errFileNotFound: "Fichier Markdown selectionne introuvable",
    errReadFailed: "Echec de lecture du fichier",
    errDropFolder: "Deposez un dossier contenant des fichiers Markdown",
    errNoMarkdown: "Aucun fichier Markdown detecte"
  },
  de: {
    title: getMdEntryHeading("de"),
    subtitle: "Ordner auf der Startseite ablegen; Diese Seite zeigt nur Rendering und Vorschau",
    themeAria: "theme mode",
    themeLight: "Tag",
    themeDark: "Nacht",
    emptyHint: "Ordner hier ablegen",
    emptySub: getMdEntrySub("de"),
    emptyCta: getMdEntryCta("de"),
    controlHeadingSize: "Textgroesse",
    controlImageWidth: "Bildbreite",
    controlImageAlign: "Ausrichtung",
    controlLayout: "Layout",
    controlTheme: "Thema",
    exportPdf: "PDF exportieren",
    resetConfig: "Zurucksetzen",
    modalAcknowledge: "Bestatigen",
    modalOk: "OK",
    modalCancel: "Abbrechen",
    exportPdfFilenameLabel: "Exportdateiname",
    exportPdfFilenamePlaceholder: "Dateiname eingeben",
    exportPdfDarkHint:
      "Der Dunkelmodus ist aktiv; Damit der PDF-Hintergrund schwarz bleibt, aktivieren Sie More settings -> Background graphics im Druckdialog; dann fortfahren",
    controlSizeSmall: "Klein",
    controlSizeMedium: "Mittel",
    controlSizeLarge: "Gross",
    controlAlignLeft: "Links",
    controlAlignCenter: "Mitte",
    controlAlignRight: "Rechts",
    controlLayoutSingle: "Einspaltig",
    controlLayoutDouble: "Zweispaltig",
    pickerTitle: "Markdown-Datei auswahlen",
    placeholder: "Ordner ablegen, um Markdown hier zu sehen",
    imageMissing: "Image not found",
    errFileNotFound: "Ausgewahlte Markdown-Datei nicht gefunden",
    errReadFailed: "Datei konnte nicht gelesen werden",
    errDropFolder: "Bitte einen Ordner mit Markdown-Dateien ablegen",
    errNoMarkdown: "Keine Markdown-Dateien gefunden"
  },
  ru: {
    title: getMdEntryHeading("ru"),
    subtitle: "Peretaskivaite papki na glavnoi; Eta stranitsa tolko dlia rendera i prosmotra",
    themeAria: "theme mode",
    themeLight: "Den",
    themeDark: "Noch",
    emptyHint: "Peretashchite papku siuda",
    emptySub: getMdEntrySub("ru"),
    emptyCta: getMdEntryCta("ru"),
    controlHeadingSize: "Razmer teksta",
    controlImageWidth: "Shirina izobrazheniia",
    controlImageAlign: "Vyravnivanie",
    controlLayout: "Maket",
    controlTheme: "Tema",
    exportPdf: "Eksport PDF",
    resetConfig: "Sbros",
    modalAcknowledge: "Podtverdit",
    modalOk: "OK",
    modalCancel: "Otmena",
    exportPdfFilenameLabel: "Imia faila",
    exportPdfFilenamePlaceholder: "Vvedite imia faila",
    exportPdfDarkHint:
      "Vkluchen temnyi rezhim; Chtoby sokhranit chernyi fon PDF, vkliuchite More settings -> Background graphics v okne pechati; potom prodolzhite",
    controlSizeSmall: "Malyi",
    controlSizeMedium: "Srednii",
    controlSizeLarge: "Bolshoi",
    controlAlignLeft: "Levo",
    controlAlignCenter: "Tsentr",
    controlAlignRight: "Pravo",
    controlLayoutSingle: "Odna kolonka",
    controlLayoutDouble: "Dve kolonki",
    pickerTitle: "Vybrat Markdown-fail",
    placeholder: "Peretashchite direktoriiu, chtoby posmotret Markdown",
    imageMissing: "Image not found",
    errFileNotFound: "Vybrannyi Markdown fail ne naiden",
    errReadFailed: "Ne udalos obrabotat fail",
    errDropFolder: "Peretashchite papku s failami Markdown",
    errNoMarkdown: "Faily Markdown ne naideny"
  }
};

const STORAGE_KEYS = {
  headingScale: "tsuki.md.headingScale",
  imageWidth: "tsuki.md.imageWidth",
  imageAlign: "tsuki.md.imageAlign",
  theme: "tsuki.md.theme",
  layout: "tsuki.md.layout"
};

function normalizePath(path) {
  if (!path) {
    return "";
  }

  return path
    .normalize("NFC")
    .replaceAll("\\", "/")
    .replace(/^\.\//, "")
    .replace(/^\/+/, "")
    .replace(/\/+/g, "/");
}

function toPathKey(path) {
  return normalizePath(path).toLowerCase();
}

function decodePath(path) {
  try {
    return decodeURIComponent(path);
  } catch {
    return path;
  }
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

function isMarkdown(path) {
  return /\.md$/i.test(path);
}

function isImage(path) {
  const normalized = toPathKey(path);
  for (const ext of IMAGE_EXTENSIONS) {
    if (normalized.endsWith(ext)) {
      return true;
    }
  }
  return false;
}

function pickDefaultMarkdownPath(mdFiles = []) {
  if (!mdFiles.length) {
    return "";
  }

  const preferred = mdFiles.find((item) => /(^|\/)note-?night\.md$/i.test(item.pathKey));
  if (preferred) {
    return preferred.pathKey;
  }

  const fallback = mdFiles.find((item) => /(^|\/)[^/]*night[^/]*\.md$/i.test(item.pathKey));
  return (fallback ?? mdFiles[0]).pathKey;
}

const HEADING_SCALE_OPTIONS = [
  { key: "small", scale: 0.88 },
  { key: "medium", scale: 1 },
  { key: "large", scale: 1.14 }
];

const IMAGE_WIDTH_MAX_SINGLE = 740;
const IMAGE_WIDTH_MAX_DOUBLE = 360;

function buildImageWidthOptions(maxWidth) {
  const options = [];

  for (let width = 100; width <= maxWidth; width += 40) {
    options.push({ key: String(width), width: `${width}px`, label: `${width}px` });
  }

  if (options[options.length - 1]?.key !== String(maxWidth)) {
    options.push({ key: String(maxWidth), width: `${maxWidth}px`, label: `${maxWidth}px` });
  }

  return options;
}

const IMAGE_WIDTH_OPTIONS_SINGLE = buildImageWidthOptions(IMAGE_WIDTH_MAX_SINGLE);
const IMAGE_WIDTH_OPTIONS_DOUBLE = buildImageWidthOptions(IMAGE_WIDTH_MAX_DOUBLE);

const IMAGE_ALIGN_OPTIONS = [{ key: "left" }, { key: "center" }, { key: "right" }];

const THEME_OPTIONS = [{ key: "light" }, { key: "dark" }];

const LAYOUT_OPTIONS = [{ key: "single" }, { key: "double" }];

function readLocalStorageValue(key) {
  if (typeof window === "undefined") {
    return "";
  }

  try {
    return window.localStorage.getItem(key) ?? "";
  } catch {
    return "";
  }
}

function pickOption(options, key, fallbackKey = "medium") {
  return options.find((item) => item.key === key) ?? options.find((item) => item.key === fallbackKey) ?? options[0];
}

function splitMarkdownByLevel3(markdown = "") {
  const lines = markdown.split(/\r?\n/);
  let lead = "";
  const sections = [];
  let current = [];
  let seenFirstSection = false;

  for (const line of lines) {
    if (/^###\s+/.test(line)) {
      if (seenFirstSection && current.length) {
        sections.push(current.join("\n").trim());
      }

      seenFirstSection = true;
      current = [line];
      continue;
    }

    if (seenFirstSection) {
      current.push(line);
    } else {
      lead = lead ? `${lead}\n${line}` : line;
    }
  }

  if (current.length) {
    sections.push(current.join("\n").trim());
  }

  return {
    lead: lead.trim(),
    sections: sections.filter(Boolean)
  };
}

function getMarkdownTitle(markdown = "", fallback = "") {
  const lines = markdown.split(/\r?\n/);

  for (const line of lines) {
    const match = line.match(/^#\s+(.+)$/);
    if (!match) {
      continue;
    }

    const title = match[1].replace(/\s+#+\s*$/, "").trim();
    if (title) {
      return title;
    }
  }

  return fallback;
}

function getPathFilename(path = "") {
  const normalized = normalizePath(path);
  if (!normalized) {
    return "";
  }

  const parts = normalized.split("/");
  const filename = parts[parts.length - 1] ?? "";
  return filename.replace(/\.md$/i, "");
}

function normalizePdfFilename(name) {
  return String(name ?? "")
    .replace(/\.pdf$/i, "")
    .replace(/[\\/:*?"<>|]/g, "-")
    .trim();
}

function stripFirstMarkdownTitle(markdown = "") {
  const lines = markdown.split(/\r?\n/);
  const titleIndex = lines.findIndex((line) => /^#\s+.+$/.test(line));

  if (titleIndex < 0) {
    return markdown;
  }

  const nextIndex = titleIndex + 1;
  const shouldDropFollowingBlank = nextIndex < lines.length && lines[nextIndex].trim() === "";
  const removeCount = shouldDropFollowingBlank ? 2 : 1;

  lines.splice(titleIndex, removeCount);
  return lines.join("\n");
}

function hasRawHtmlTag(markdown = "") {
  return RAW_HTML_TAG_PATTERN.test(markdown);
}

const MarkdownDocument = memo(function MarkdownDocument({
  layoutModeKey,
  splitContent,
  printableMarkdown,
  renderers,
  rehypePlugins
}) {
  if (layoutModeKey === "double" && splitContent.sections.length > 1) {
    return (
      <>
        {splitContent.lead ? (
          <div className="md-double-intro">
            <ReactMarkdown rehypePlugins={rehypePlugins} components={renderers}>
              {splitContent.lead}
            </ReactMarkdown>
          </div>
        ) : null}
        <div className="md-double-grid">
          {splitContent.sections.map((section, index) => (
            <section className="md-double-item" key={`${index}-${section.slice(0, 24)}`}>
              <ReactMarkdown rehypePlugins={rehypePlugins} components={renderers}>
                {section}
              </ReactMarkdown>
            </section>
          ))}
        </div>
      </>
    );
  }

  return (
    <ReactMarkdown rehypePlugins={rehypePlugins} components={renderers}>
      {printableMarkdown}
    </ReactMarkdown>
  );
});

const MdFilePicker = memo(function MdFilePicker({ mdFiles, selectedMdPath, onSelectMdFile }) {
  if (mdFiles.length <= 1) {
    return null;
  }

  return (
    <section className="md-picker">
      <div className="md-picker-list">
        {mdFiles.map((item) => (
          <button
            type="button"
            key={item.pathKey}
            className={selectedMdPath === item.pathKey ? "is-selected" : ""}
            onClick={() => onSelectMdFile(item.pathKey)}
          >
            {item.path}
          </button>
        ))}
      </div>
    </section>
  );
});

const MdControls = memo(function MdControls({
  t,
  headingScaleKey,
  imageWidthKey,
  imageAlignKey,
  layoutModeKey,
  themeModeKey,
  imageWidthOptions,
  onHeadingScaleChange,
  onImageWidthChange,
  onImageAlignChange,
  onLayoutChange,
  onThemeChange,
  onReset,
  onExportPdf,
  canExport
}) {
  return (
    <section className="md-controls" aria-label="markdown display controls">
      <div className="md-controls-group">
        <span>{t.controlHeadingSize}</span>
        <select
          className="md-controls-select"
          value={headingScaleKey}
          onChange={onHeadingScaleChange}
          aria-label={t.controlHeadingSize}
        >
          {HEADING_SCALE_OPTIONS.map((item) => (
            <option value={item.key} key={item.key}>
              {item.key === "small"
                ? t.controlSizeSmall
                : item.key === "medium"
                  ? t.controlSizeMedium
                  : t.controlSizeLarge}
            </option>
          ))}
        </select>
      </div>

      <div className="md-controls-group md-controls-group-image">
        <span>{t.controlImageWidth}</span>
        <select
          className="md-controls-select"
          value={imageWidthKey}
          onChange={onImageWidthChange}
          aria-label={t.controlImageWidth}
        >
          {imageWidthOptions.map((item) => (
            <option value={item.key} key={item.key}>
              {item.label}
            </option>
          ))}
        </select>
      </div>

      <div className="md-controls-group">
        <span>{t.controlImageAlign}</span>
        <select
          className="md-controls-select"
          value={imageAlignKey}
          onChange={onImageAlignChange}
          aria-label={t.controlImageAlign}
        >
          {IMAGE_ALIGN_OPTIONS.map((item) => (
            <option value={item.key} key={item.key}>
              {item.key === "left"
                ? t.controlAlignLeft
                : item.key === "center"
                  ? t.controlAlignCenter
                  : t.controlAlignRight}
            </option>
          ))}
        </select>
      </div>

      <div className="md-controls-group">
        <span>{t.controlLayout}</span>
        <select
          className="md-controls-select"
          value={layoutModeKey}
          onChange={onLayoutChange}
          aria-label={t.controlLayout}
        >
          {LAYOUT_OPTIONS.map((item) => (
            <option value={item.key} key={item.key}>
              {item.key === "single" ? t.controlLayoutSingle : t.controlLayoutDouble}
            </option>
          ))}
        </select>
      </div>

      <div className="md-controls-group">
        <span>{t.controlTheme}</span>
        <select
          className="md-controls-select"
          value={themeModeKey}
          onChange={onThemeChange}
          aria-label={t.controlTheme}
        >
          {THEME_OPTIONS.map((item) => (
            <option value={item.key} key={item.key}>
              {item.key === "light" ? t.themeLight : t.themeDark}
            </option>
          ))}
        </select>
      </div>

      <div className="md-controls-action">
        <button type="button" className="md-controls-reset" onClick={onReset}>
          {t.resetConfig ?? "Reset"}
        </button>
        <button type="button" onClick={onExportPdf} disabled={!canExport}>
          {t.exportPdf}
        </button>
      </div>
    </section>
  );
});

function MdViewerPage({
  initialEntries = [],
  onInitialEntriesConsumed,
  language = "ja",
  onLanguageChange,
  languageOptions = [],
  productName = "Tsuki Translate"
}) {
  const t = useMemo(() => UI_COPY[language] ?? UI_COPY.ja, [language]);
  const [error, setError] = useState("");
  const [mdFiles, setMdFiles] = useState([]);
  const [selectedMdPath, setSelectedMdPath] = useState("");
  const [markdownText, setMarkdownText] = useState("");
  const [fileMap, setFileMap] = useState(new Map());
  const [mdEntryDragging, setMdEntryDragging] = useState(false);
  const [headingScale, setHeadingScale] = useState(() =>
    pickOption(HEADING_SCALE_OPTIONS, readLocalStorageValue(STORAGE_KEYS.headingScale))
  );
  const [layoutMode, setLayoutMode] = useState(() =>
    pickOption(LAYOUT_OPTIONS, readLocalStorageValue(STORAGE_KEYS.layout), "double")
  );
  const imageWidthOptions = useMemo(
    () => (layoutMode.key === "double" ? IMAGE_WIDTH_OPTIONS_DOUBLE : IMAGE_WIDTH_OPTIONS_SINGLE),
    [layoutMode.key]
  );
  const [imageWidth, setImageWidth] = useState(() =>
    pickOption(IMAGE_WIDTH_OPTIONS_SINGLE, readLocalStorageValue(STORAGE_KEYS.imageWidth), "260")
  );
  const [imageAlign, setImageAlign] = useState(() =>
    pickOption(IMAGE_ALIGN_OPTIONS, readLocalStorageValue(STORAGE_KEYS.imageAlign), "left")
  );
  const [themeMode, setThemeMode] = useState(() => pickOption(THEME_OPTIONS, readLocalStorageValue(STORAGE_KEYS.theme), "dark"));
  const [pdfHintModalOpen, setPdfHintModalOpen] = useState(false);
  const [pdfFilename, setPdfFilename] = useState("");
  const [rehypeRawPlugin, setRehypeRawPlugin] = useState(null);
  const folderInputRef = useRef(null);
  const pdfFilenameInputRef = useRef(null);

  useEffect(() => {
    try {
      window.localStorage.setItem(STORAGE_KEYS.headingScale, headingScale.key);
    } catch {}
  }, [headingScale.key]);

  useEffect(() => {
    try {
      window.localStorage.setItem(STORAGE_KEYS.imageWidth, imageWidth.key);
    } catch {}
  }, [imageWidth.key]);

  useEffect(() => {
    try {
      window.localStorage.setItem(STORAGE_KEYS.imageAlign, imageAlign.key);
    } catch {}
  }, [imageAlign.key]);

  useEffect(() => {
    try {
      window.localStorage.setItem(STORAGE_KEYS.theme, themeMode.key);
    } catch {}
  }, [themeMode.key]);

  useEffect(() => {
    try {
      window.localStorage.setItem(STORAGE_KEYS.layout, layoutMode.key);
    } catch {}
  }, [layoutMode.key]);

  useEffect(() => {
    setImageWidth((current) =>
      pickOption(imageWidthOptions, current.key, imageWidthOptions[imageWidthOptions.length - 1]?.key ?? "360")
    );
  }, [imageWidthOptions]);

  useEffect(() => {
    document.body.classList.add("md-viewer-body");

    return () => {
      document.body.classList.remove("md-viewer-body");
    };
  }, []);

  useEffect(() => {
    document.body.setAttribute("data-md-print-theme", themeMode.key);

    return () => {
      document.body.removeAttribute("data-md-print-theme");
    };
  }, [themeMode.key]);

  useEffect(() => {
    if (!pdfHintModalOpen || typeof window === "undefined") {
      return undefined;
    }

    const onKeyDown = (event) => {
      if (event.key === "Escape") {
        setPdfHintModalOpen(false);
      }
    };

    window.addEventListener("keydown", onKeyDown);
    return () => {
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [pdfHintModalOpen]);

  useEffect(() => {
    if (!pdfHintModalOpen || typeof window === "undefined") {
      return undefined;
    }

    const frame = window.requestAnimationFrame(() => {
      pdfFilenameInputRef.current?.focus();
      pdfFilenameInputRef.current?.select();
    });

    return () => {
      window.cancelAnimationFrame(frame);
    };
  }, [pdfHintModalOpen]);

  const imageBlobMap = useMemo(() => {
    const nextMap = new Map();

    for (const [path, file] of fileMap.entries()) {
      if (!isImage(path)) {
        continue;
      }

      nextMap.set(path, URL.createObjectURL(file));
    }

    return nextMap;
  }, [fileMap]);

  useEffect(() => {
    return () => {
      for (const blobUrl of imageBlobMap.values()) {
        URL.revokeObjectURL(blobUrl);
      }
    };
  }, [imageBlobMap]);

  const renderers = useMemo(
    () => ({
      img: ({ src = "", alt = "" }) => {
        const normalizedSrc = toPathKey(decodePath(src));
        const url = imageBlobMap.get(normalizedSrc);

        if (!url) {
          return (
            <span className="md-image-missing">
              {t.imageMissing}: {src}
            </span>
          );
        }

        return <img src={url} alt={alt} loading="lazy" />;
      }
    }),
    [imageBlobMap, t.imageMissing]
  );

  const printableMarkdown = useMemo(() => stripFirstMarkdownTitle(markdownText), [markdownText]);
  const needsRawHtmlPlugin = useMemo(() => hasRawHtmlTag(printableMarkdown), [printableMarkdown]);
  const rehypePlugins = useMemo(() => {
    if (!needsRawHtmlPlugin || !rehypeRawPlugin) {
      return [];
    }

    return [rehypeRawPlugin];
  }, [needsRawHtmlPlugin, rehypeRawPlugin]);
  const splitContent = useMemo(() => splitMarkdownByLevel3(printableMarkdown), [printableMarkdown]);
  const printHeaderTitle = useMemo(() => {
    const fallbackTitle = getPathFilename(selectedMdPath);
    return getMarkdownTitle(markdownText, fallbackTitle);
  }, [markdownText, selectedMdPath]);
  const activePrintHeaderTitle = useMemo(
    () => normalizePdfFilename(pdfFilename) || printHeaderTitle,
    [pdfFilename, printHeaderTitle]
  );

  useEffect(() => {
    if (!needsRawHtmlPlugin || rehypeRawPlugin) {
      return;
    }

    let cancelled = false;

    import("rehype-raw")
      .then((module) => {
        if (cancelled) {
          return;
        }

        setRehypeRawPlugin(() => module.default);
      })
      .catch(() => {});

    return () => {
      cancelled = true;
    };
  }, [needsRawHtmlPlugin, rehypeRawPlugin]);

  const readMarkdown = useCallback(async (targetPath, files) => {
    const target = files.find((item) => item.pathKey === targetPath);
    if (!target) {
      setError(t.errFileNotFound);
      setMarkdownText("");
      return;
    }

    try {
      const text = await target.file.text();
      setSelectedMdPath(target.pathKey);
      setMarkdownText(text);
      setError("");
    } catch (readError) {
      setError(`${t.errReadFailed}: ${readError instanceof Error ? readError.message : String(readError)}`);
      setMarkdownText("");
    }
  }, [t.errFileNotFound, t.errReadFailed]);

  const processCollectedFiles = useCallback(
    async (allFiles) => {
      setError("");

      if (!allFiles.length) {
        setError(t.errDropFolder);
        setMdFiles([]);
        setSelectedMdPath("");
        setMarkdownText("");
        setFileMap(new Map());
        return;
      }

      const normalizedEntries = stripCommonRootFolder(
        allFiles.map((item) => ({
          path: normalizePath(item.path),
          file: item.file
        }))
      ).map((item) => ({
        ...item,
        pathKey: toPathKey(item.path)
      }));

      const nextMap = new Map();
      for (const item of normalizedEntries) {
        nextMap.set(item.pathKey, item.file);
      }

      const nextMdFiles = normalizedEntries.filter(
        (item) => isMarkdown(item.pathKey) && !item.path.includes("/")
      );
      const defaultPath = pickDefaultMarkdownPath(nextMdFiles);
      const defaultIndex = nextMdFiles.findIndex((item) => item.pathKey === defaultPath);
      const orderedMdFiles =
        defaultIndex > 0
          ? [nextMdFiles[defaultIndex], ...nextMdFiles.filter((item) => item.pathKey !== defaultPath)]
          : nextMdFiles;

      setFileMap(nextMap);
      setMdFiles(orderedMdFiles);

      if (!nextMdFiles.length) {
        setError(t.errNoMarkdown);
        setSelectedMdPath("");
        setMarkdownText("");
        return;
      }

      await readMarkdown(defaultPath, orderedMdFiles);
    },
    [readMarkdown, t.errDropFolder, t.errNoMarkdown]
  );

  useEffect(() => {
    if (!initialEntries.length) {
      return;
    }

    processCollectedFiles(initialEntries).finally(() => {
      onInitialEntriesConsumed?.();
    });
  }, [initialEntries, onInitialEntriesConsumed, processCollectedFiles]);

  const hasPickedFolder = fileMap.size > 0;
  const openFolderPicker = useCallback(() => {
    folderInputRef.current?.click();
  }, []);

  const onFolderInputChange = useCallback(
    async (event) => {
      const files = Array.from(event.target.files ?? []);

      if (!files.length) {
        event.target.value = "";
        return;
      }

      const entries = files.map((file) => ({
        path: file.webkitRelativePath || file.name,
        file
      }));

      await processCollectedFiles(entries);
      event.target.value = "";
    },
    [processCollectedFiles]
  );

  const doPrint = useCallback((nextFilename = "") => {
    if (typeof window === "undefined") {
      return;
    }

    const normalizedName = normalizePdfFilename(nextFilename);
    const originalTitle = document.title;

    if (normalizedName) {
      document.title = normalizedName;
    }

    const restoreTitle = () => {
      document.title = originalTitle;
    };

    window.addEventListener("afterprint", restoreTitle, { once: true });

    window.print();

    window.setTimeout(restoreTitle, 1500);
  }, []);

  const exportPdf = useCallback(() => {
    const suggestedName = normalizePdfFilename(printHeaderTitle) || normalizePdfFilename(getPathFilename(selectedMdPath)) || "export";
    setPdfFilename(suggestedName);
    setPdfHintModalOpen(true);
  }, [printHeaderTitle, selectedMdPath]);

  const onSelectMdFile = useCallback(
    (nextPathKey) => {
      void readMarkdown(nextPathKey, mdFiles);
    },
    [mdFiles, readMarkdown]
  );

  const onHeadingScaleChange = useCallback((event) => {
    setHeadingScale(pickOption(HEADING_SCALE_OPTIONS, event.target.value, "medium"));
  }, []);

  const onImageWidthChange = useCallback(
    (event) => {
      setImageWidth(pickOption(imageWidthOptions, event.target.value, "260"));
    },
    [imageWidthOptions]
  );

  const onImageAlignChange = useCallback((event) => {
    setImageAlign(pickOption(IMAGE_ALIGN_OPTIONS, event.target.value, "left"));
  }, []);

  const onLayoutChange = useCallback((event) => {
    setLayoutMode(pickOption(LAYOUT_OPTIONS, event.target.value, "double"));
  }, []);

  const onThemeChange = useCallback((event) => {
    setThemeMode(pickOption(THEME_OPTIONS, event.target.value, "dark"));
  }, []);

  const resetAllConfig = useCallback(() => {
    setHeadingScale(pickOption(HEADING_SCALE_OPTIONS, "medium", "medium"));
    setLayoutMode(pickOption(LAYOUT_OPTIONS, "double", "double"));
    setImageWidth(pickOption(IMAGE_WIDTH_OPTIONS_SINGLE, "260", "260"));
    setImageAlign(pickOption(IMAGE_ALIGN_OPTIONS, "left", "left"));
    setThemeMode(pickOption(THEME_OPTIONS, "dark", "dark"));
  }, []);

  const confirmPdfExport = useCallback(() => {
    const finalFilename =
      normalizePdfFilename(pdfFilename) ||
      normalizePdfFilename(printHeaderTitle) ||
      normalizePdfFilename(getPathFilename(selectedMdPath)) ||
      "export";

    setPdfHintModalOpen(false);
    if (typeof window === "undefined") {
      return;
    }

    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        doPrint(finalFilename);
      });
    });
  }, [doPrint, pdfFilename, printHeaderTitle, selectedMdPath]);

  return (
    <>
      <header className="nav">
        <div className="container nav-inner">
          <div className="nav-left">
            <a href="/" className="brand">
              <span className="brand-dot" aria-hidden="true" />
              <span>{productName}</span>
            </a>
            <label className="lang-switch" htmlFor="md-lang-select">
              <span className="sr-only">language</span>
              <span className="lang-switch-icon" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <path d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2zm7.93 9h-3.02a15.2 15.2 0 0 0-1.22-5A8.03 8.03 0 0 1 19.93 11zM12 4.05c.8.98 1.85 3.22 2.33 6.95H9.67C10.15 7.27 11.2 5.03 12 4.05zM4.07 13h3.02a15.2 15.2 0 0 0 1.22 5A8.03 8.03 0 0 1 4.07 13zM7.09 11H4.07a8.03 8.03 0 0 1 4.24-5 15.2 15.2 0 0 0-1.22 5zM12 19.95c-.8-.98-1.85-3.22-2.33-6.95h4.66c-.48 3.73-1.53 5.97-2.33 6.95zM15.69 18a15.2 15.2 0 0 0 1.22-5h3.02a8.03 8.03 0 0 1-4.24 5z" />
                </svg>
              </span>
              <select
                id="md-lang-select"
                value={language}
                onChange={(event) => onLanguageChange?.(event.target.value)}
              >
                {languageOptions.map((item) => (
                  <option value={item.code} key={item.code}>
                    {item.label}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <div className="nav-actions">
            <a href={RELEASE_URL} className="btn btn-primary" target="_blank" rel="noreferrer">
              今すぐダウンロード
            </a>
          </div>
        </div>
      </header>

      <main className="container md-page">
        <input
          ref={folderInputRef}
          type="file"
          webkitdirectory=""
          multiple
          className="sr-only"
          onChange={onFolderInputChange}
        />

        <section className="md-header">
          <h2>{t.title}</h2>
        </section>

        {!mdFiles.length && !markdownText && !error ? (
          <MdEntryPanel
            title={t.emptyHint}
            sub={t.emptySub}
            ctaLabel={t.emptyCta}
            isDragging={mdEntryDragging}
            ariaLabel={t.emptyHint}
            onPanelClick={openFolderPicker}
            onPanelKeyDown={(event) => {
              if (event.key === "Enter" || event.key === " ") {
                event.preventDefault();
                openFolderPicker();
              }
            }}
            onDragOver={(event) => {
              event.preventDefault();
              setMdEntryDragging(true);
            }}
            onDragLeave={(event) => {
              event.preventDefault();
              setMdEntryDragging(false);
            }}
            onDrop={async (event) => {
              event.preventDefault();
              setMdEntryDragging(false);

              try {
                const droppedFiles = await collectFilesFromDataTransfer(event.dataTransfer);
                await processCollectedFiles(droppedFiles);
              } catch {
                setError(t.errDropFolder);
              }
            }}
            onCtaClick={openFolderPicker}
          />
        ) : null}

        {error ? (
          <section className="md-error-wrap">
            <p className="md-error">{error}</p>
          </section>
        ) : null}

        {mdFiles.length > 1 ? (
          <MdFilePicker
            mdFiles={mdFiles}
            selectedMdPath={selectedMdPath}
            onSelectMdFile={onSelectMdFile}
          />
        ) : null}

        {hasPickedFolder ? (
          <MdControls
            t={t}
            headingScaleKey={headingScale.key}
            imageWidthKey={imageWidth.key}
            imageAlignKey={imageAlign.key}
            layoutModeKey={layoutMode.key}
            themeModeKey={themeMode.key}
            imageWidthOptions={imageWidthOptions}
            onHeadingScaleChange={onHeadingScaleChange}
            onImageWidthChange={onImageWidthChange}
            onImageAlignChange={onImageAlignChange}
            onLayoutChange={onLayoutChange}
            onThemeChange={onThemeChange}
            onReset={resetAllConfig}
            onExportPdf={exportPdf}
            canExport={Boolean(markdownText)}
          />
        ) : null}

        {hasPickedFolder ? (
          <section className="md-renderer">
            {markdownText ? (
              <>
                <div className="md-print-header" aria-hidden="true">
                  {activePrintHeaderTitle}
                </div>
                <article
                  className={`md-content md-image-align-${imageAlign.key} md-theme-${themeMode.key} md-layout-${layoutMode.key}`}
                  style={{
                    "--md-heading-scale": headingScale.scale,
                    "--md-image-width": imageWidth.width
                  }}
                >
                  <MarkdownDocument
                    layoutModeKey={layoutMode.key}
                    splitContent={splitContent}
                    printableMarkdown={printableMarkdown}
                    renderers={renderers}
                    rehypePlugins={rehypePlugins}
                  />
                </article>
              </>
            ) : (
              <p className="md-placeholder">{t.placeholder}</p>
            )}
          </section>
        ) : null}
      </main>

      <SiteFooter productName={productName} className="md-footer" />

      {pdfHintModalOpen ? (
        <div className="app-modal-backdrop" role="presentation" onClick={() => setPdfHintModalOpen(false)}>
          <div
            className="app-modal"
            role="dialog"
            aria-modal="true"
            aria-label="pdf export hint"
            onClick={(event) => event.stopPropagation()}
          >
            <h3>{t.exportPdf}</h3>
            <label className="md-pdf-modal-field">
              <span>{t.exportPdfFilenameLabel ?? "Export filename"}</span>
              <input
                ref={pdfFilenameInputRef}
                type="text"
                value={pdfFilename}
                placeholder={t.exportPdfFilenamePlaceholder ?? "Enter filename"}
                onChange={(event) => setPdfFilename(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === "Enter") {
                    event.preventDefault();
                    confirmPdfExport();
                  }
                }}
              />
            </label>
            {themeMode.key === "dark" ? (
              <p className="md-pdf-dark-hint">
                {t.exportPdfDarkHint ??
                  "Dark mode is enabled; In the print dialog, turn on More settings -> Background graphics; then continue"}
              </p>
            ) : null}
            <div className="md-pdf-modal-actions">
              <button type="button" className="btn" onClick={() => setPdfHintModalOpen(false)}>
                {t.modalCancel ?? "Cancel"}
              </button>
              <button type="button" className="btn btn-primary" onClick={confirmPdfExport}>
                {t.modalAcknowledge ?? t.modalOk ?? "OK"}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}

export default MdViewerPage;
