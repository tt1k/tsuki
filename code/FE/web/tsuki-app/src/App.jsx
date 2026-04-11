import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import MdEntryPanel from "./MdEntryPanel";
import MdViewerPage from "./MdViewerPage";
import { getMdEntryCta, getMdEntryHeading, getMdEntrySub } from "./md-entry-copy";
import SiteFooter from "./SiteFooter";
import { collectFilesFromDataTransfer } from "./md-drop-utils";

function hasMarkdownEntries(entries = []) {
  return entries.some((item) => /\.md$/i.test(item.path || ""));
}

async function directoryContainsMarkdown(rootHandle) {
  const stack = [rootHandle];

  while (stack.length) {
    const current = stack.pop();
    for await (const entry of current.values()) {
      if (entry.kind === "file" && /\.md$/i.test(entry.name)) {
        return true;
      }

      if (entry.kind === "directory") {
        stack.push(entry);
      }
    }
  }

  return false;
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
  ja: "/product_ja.png",
  "zh-CN": "/product_zh-CN.png",
  "zh-TW": "/product_zh-TW.png",
  en: "/product_en.png",
  ko: "/product_ko.png",
  es: "/product_es.png",
  fr: "/product_fr.png",
  de: "/product_de.png",
  ru: "/product_ru.png"
};

const MODAL_COPY = {
  ja: { title: "お知らせ", ok: "了解です" },
  "zh-CN": { title: "提示", ok: "确定" },
  "zh-TW": { title: "提示", ok: "確定" },
  en: { title: "Notice", ok: "OK" },
  ko: { title: "안내", ok: "확인" },
  es: { title: "Aviso", ok: "Aceptar" },
  fr: { title: "Information", ok: "OK" },
  de: { title: "Hinweis", ok: "OK" },
  ru: { title: "Уведомление", ok: "ОК" }
};

const COPY = {
  ja: {
    heroTitleLine1: "翻訳はもっと速く",
    heroTitleLine2: "理解はもっと深く",
    heroTitleLine3: "月の言葉",
    heroDesc: "没入感あるダークUIでつくった、語学学習向けデスクトップ翻訳アプリ",
    ctaPrimary: "無料で試す",
    ctaSecondary: "機能を見る",
    sectionFeatureTitle: "翻訳流れを継続的高效に",
    f1Title: "ワンクリックで即翻訳",
    f1Desc: "すぐに呼び出せて、そのまま発話を翻訳；思考を止めない操作体験です",
    f2Title: "Tsuki CLIでアプリ横断の秒翻訳",
    f2Desc: "Tsuki CLI で、他アプリから即座に翻訳へ接続できます",
    f3Title: "語形・発音・例文を一画面表示",
    f3Desc: "必要な語彙情報を分散させず、理解に必要な要素を一度に確認できます",
    f4Title: "例文トークン強調 + ふりがな表示",
    f4Desc: "分かち書きと読み情報を同時に示し、長文でも視線移動を減らして読めます",
    f5Title: "Dark / Light テーマ切换",
    f5Desc: "シーンに応じてテーマを切り替えられ、日中を問わず快適",
    f6Title: "翻訳を自動蓄積して学習資産化",
    f6Desc: "当日 NOTE.md と画像の保存まで自動で完了、手動整理不要",
    resultTitle: "訳すだけで終わらない",
    resultDesc:
      "文脈内の語彙情報を構造化して可視化；トークン強調で要点をすぐに把握できます",
    previewInput: "Input",
    previewResult: "Result",
    lastCtaTitle: "すべての翻訳を、定着する学習へ",
    lastCtaDesc: "月の言葉で入力・理解・記憶の流れをつなげましょう",
    lastCtaBtn: "今すぐダウンロード",
    statusReady: "Ready",
    mdEntryHeading: getMdEntryHeading("ja"),
    mdEntryTitle: "フォルダをここにドロップ",
    mdEntrySub: getMdEntrySub("ja"),
    mdEntryCta: getMdEntryCta("ja"),
    mdEntryNoMarkdown: "このフォルダには Markdown ファイルがありません",
    mdEntryPermissionDenied: "フォルダへのアクセスが許可されませんでした"
  },
  "zh-CN": {
    heroTitleLine1: "翻译速度更快更准",
    heroTitleLine2: "内容理解更深更透",
    heroTitleLine3: "言叶之月",
    heroDesc: "采用沉浸式深色视觉，打造面向语言学习的桌面翻译工具",
    ctaPrimary: "免费体验",
    ctaSecondary: "查看功能",
    sectionFeatureTitle: "让翻译流程持续高效",
    f1Title: "一键唤起，开口即译",
    f1Desc: "快速调起并立即翻译，不打断当前工作流",
    f2Title: "支持 Tsuki CLI 跨应用秒翻",
    f2Desc: "通过 tsuki cli 在任意应用间无缝跳转翻译",
    f3Title: "词形、读音、释义、例句一屏看全",
    f3Desc: "核心词汇信息聚合展示，减少来回切换成本",
    f4Title: "例句分词高亮 + 假名标注",
    f4Desc: "阅读路径更清晰，长句理解更直观",
    f5Title: "Dark / Light 主题切换",
    f5Desc: "根据场景自由切换显示风格，兼顾舒适与专注",
    f6Title: "翻译自动沉淀为学习资产",
    f6Desc: "当日 NOTE.md + 截图自动归档，无需手动整理",
    resultTitle: "结果不只是翻译正确",
    resultDesc: "在上下文中展示结构化词汇信息，用分词高亮快速定位重点",
    previewInput: "输入",
    previewResult: "结果",
    lastCtaTitle: "让每次翻译都更接近掌握",
    lastCtaDesc: "现在开始体验言叶之月，建立更顺滑的学习链路",
    lastCtaBtn: "立即下载",
    statusReady: "就绪",
    mdEntryHeading: getMdEntryHeading("zh-CN"),
    mdEntryTitle: "把文件夹拖到这里",
    mdEntrySub: getMdEntrySub("zh-CN"),
    mdEntryCta: getMdEntryCta("zh-CN"),
    mdEntryNoMarkdown: "未检测到 Markdown",
    mdEntryPermissionDenied: "权限未授予"
  },
  "zh-TW": {
    heroTitleLine1: "翻譯速度更快更準",
    heroTitleLine2: "內容理解更深更透",
    heroTitleLine3: "言葉之月",
    heroDesc: "採用沉浸式深色視覺，打造語言學習導向的桌面翻譯工具",
    ctaPrimary: "免費體驗",
    ctaSecondary: "查看功能",
    sectionFeatureTitle: "讓翻譯流程持續高效",
    f1Title: "一鍵喚起，開口即譯",
    f1Desc: "快速呼叫並立即翻譯，不中斷目前工作流程",
    f2Title: "支援 Tsuki CLI 跨應用秒翻",
    f2Desc: "透過 Tsuki CLI 在任意應用間無縫跳轉翻譯",
    f3Title: "詞形、讀音、釋義、例句一屏看全",
    f3Desc: "核心詞彙資訊集中呈現，減少來回切換成本",
    f4Title: "例句分詞高亮 + 假名標註",
    f4Desc: "閱讀路徑更清楚，長句理解更直觀",
    f5Title: "Dark / Light 主題切換",
    f5Desc: "依使用情境自由切換顯示風格，兼顧舒適與專注",
    f6Title: "翻譯自動沉澱為學習資產",
    f6Desc: "當日 NOTE.md + 截圖自動歸檔，省去手動整理",
    resultTitle: "結果不只翻譯正確",
    resultDesc: "在上下文中展示結構化詞彙資訊，用分詞高亮快速定位重點",
    previewInput: "輸入",
    previewResult: "結果",
    lastCtaTitle: "讓每次翻譯都更接近掌握",
    lastCtaDesc: "現在開始體驗言葉之月，建立更流暢的學習鏈路",
    lastCtaBtn: "立即下載",
    statusReady: "就緒",
    mdEntryHeading: getMdEntryHeading("zh-TW"),
    mdEntryTitle: "把資料夾拖到這裡",
    mdEntrySub: getMdEntrySub("zh-TW"),
    mdEntryCta: getMdEntryCta("zh-TW"),
    mdEntryNoMarkdown: "該資料夾中沒有 Markdown 檔案",
    mdEntryPermissionDenied: "未取得該資料夾的存取權限"
  },
  en: {
    heroTitleLine1: "Translate faster",
    heroTitleLine2: "understand deeper",
    heroTitleLine3: "Tsuki Translate",
    heroDesc: "Built with an immersive dark visual language for language learning",
    ctaPrimary: "Try for free",
    ctaSecondary: "View features",
    sectionFeatureTitle: "Workflow that stays in flow",
    f1Title: "One-tap invoke, speak and translate",
    f1Desc: "Launch quickly and translate right away without breaking your flow",
    f2Title: "Tsuki CLI based cross-app instant translation",
    f2Desc: "Jump in via Tsuki CLI from any app in seconds, seamless integration",
    f3Title: "Lemma, pronunciation, senses, examples in one view",
    f3Desc: "See all key lexical signals together instead of switching panels",
    f4Title: "Token highlight + furigana on example lines",
    f4Desc: "Read longer sentences faster with clearer segmentation and reading aids",
    f5Title: "Switch between Dark / Light themes",
    f5Desc: "Match your environment with visual comfort, day and night",
    f6Title: "Automatic translation archive for learning",
    f6Desc: "Daily NOTE.md entries and screenshots are saved automatically",
    resultTitle: "More than correct translation",
    resultDesc:
      "See structured word-level context and jump to key chunks instantly with token highlighting",
    previewInput: "Input",
    previewResult: "Result",
    lastCtaTitle: "Turn every translation into learning",
    lastCtaDesc: "Start with Tsuki Translate and connect input, understanding, and memory",
    lastCtaBtn: "Download now",
    statusReady: "Ready",
    mdEntryHeading: getMdEntryHeading("en"),
    mdEntryTitle: "Drop a folder here",
    mdEntrySub: getMdEntrySub("en"),
    mdEntryCta: getMdEntryCta("en"),
    mdEntryNoMarkdown: "No Markdown files found in this folder",
    mdEntryPermissionDenied: "Folder access was not granted"
  },
  ko: {
    heroTitleLine1: "더 빠르게 번역하고",
    heroTitleLine2: "더 깊게 이해하세요",
    heroTitleLine3: "月の言葉",
    heroDesc: "몰입형 다크 디자인으로 만든 언어 학습용 데스크톱 번역 앱입니다",
    ctaPrimary: "무료로 시작",
    ctaSecondary: "기능 보기",
    sectionFeatureTitle: "흐름을 끊지 않는 번역 운영",
    f1Title: "원클릭 호출, 말하면 즉시 번역",
    f1Desc: "빠르게 실행하고 바로 번역해 작업 흐름을 끊지 않습니다",
    f2Title: "Tsuki CLI 로 앱 간 초고속 번역",
    f2Desc: "Tsuki CLI 로 어떤 앱에서도 즉시 번역 화면으로 이동합니다",
    f3Title: "어형, 발음, 뜻, 예문을 한 번에",
    f3Desc: "핵심 어휘 정보를 한 화면에 모아 전환 비용을 줄였습니다",
    f4Title: "예문 토큰 하이라이트 + 후리가나",
    f4Desc: "문장 분해와 읽기 힌트를 함께 보여 더 직관적으로 읽을 수 있습니다",
    f5Title: "Dark / Light 테마切换",
    f5Desc: "환경에 맞춰 시각 모드를切り替えられます",
    f6Title: "번역 자동 축적",
    f6Desc: "당일 NOTE.md 와 스크린샷이 자동으로 정리됩니다",
    resultTitle: "정답 번역 그 이상",
    resultDesc: "문맥 기반 구조화 정보와 토큰 하이라이트로 핵심을 빠르게 파악합니다",
    previewInput: "입력",
    previewResult: "결과",
    lastCtaTitle: "모든 번역을 학습으로 연결하세요",
    lastCtaDesc: "月の言葉로 입력-이해-기억의 흐름을 만드세요",
    lastCtaBtn: "지금 다운로드",
    statusReady: "준비됨",
    mdEntryHeading: getMdEntryHeading("ko"),
    mdEntryTitle: "폴더를 여기에 드롭하세요",
    mdEntrySub: getMdEntrySub("ko"),
    mdEntryCta: getMdEntryCta("ko"),
    mdEntryNoMarkdown: "이 폴더에 Markdown 파일이 없습니다"
  },
  es: {
    heroTitleLine1: "Traduce mas rapido",
    heroTitleLine2: "comprende mas profundo",
    heroTitleLine3: "月の言葉",
    heroDesc: "Con un lenguaje visual oscuro e inmersivo, creado para aprender idiomas",
    ctaPrimary: "Probar gratis",
    ctaSecondary: "Ver funciones",
    sectionFeatureTitle: "Flujo continuo para traducir",
    f1Title: "Invocacion con un clic y traduccion al hablar",
    f1Desc: "Abre rapido y traduce sin romper tu flujo de trabajo",
    f2Title: "Traduccion instantanea entre apps via Tsuki CLI",
    f2Desc: "Entra desde cualquier app con Tsuki CLI",
    f3Title: "Forma, pronunciacion, significado y ejemplos en una vista",
    f3Desc: "Toda la informacion lexical clave en un solo lugar",
    f4Title: "Resaltado por tokens + furigana en ejemplos",
    f4Desc: "Lectura mas clara y comprension mas directa en frases largas",
    f5Title: "Cambio libre entre temas Dark / Light",
    f5Desc: "Ajusta la visualizacion al entorno",
    f6Title: "Archivo automatico de traducciones",
    f6Desc: "NOTE.md diario y capturas se guardan automaticamente",
    resultTitle: "Mas que una traduccion correcta",
    resultDesc: "Visualiza contexto estructurado y detecta partes clave con resaltado por tokens",
    previewInput: "Entrada",
    previewResult: "Resultado",
    lastCtaTitle: "Convierte cada traduccion en aprendizaje",
    lastCtaDesc: "Empieza con 月の言葉 hoy",
    lastCtaBtn: "Descargar ahora",
    statusReady: "Listo",
    mdEntryHeading: getMdEntryHeading("es"),
    mdEntryTitle: "Suelta tu carpeta aqui",
    mdEntrySub: getMdEntrySub("es"),
    mdEntryCta: getMdEntryCta("es"),
    mdEntryNoMarkdown: "No se encontraron archivos Markdown en esta carpeta"
  },
  fr: {
    heroTitleLine1: "Traduisez plus vite",
    heroTitleLine2: "comprenez plus profondement",
    heroTitleLine3: "月の言葉",
    heroDesc: "Construit avec un langage visuel sombre et immersif, concu pour l'apprentissage des langues",
    ctaPrimary: "Essayer gratuitement",
    ctaSecondary: "Voir les fonctions",
    sectionFeatureTitle: "Un flux de traduction sans rupture",
    f1Title: "Invocation en un clic, parler puis traduire",
    f1Desc: "Lancez rapidement et traduisez sans casser votre flux",
    f2Title: "Traduction inter-apps instantanee via Tsuki CLI",
    f2Desc: "Entree immediate depuis n'importe quelle app avec Tsuki CLI",
    f3Title: "Lemme, prononciation, sens et exemples sur un ecran",
    f3Desc: "Toutes les informations lexicales utiles dans la meme vue",
    f4Title: "Surlignage token + furigana sur les exemples",
    f4Desc: "Lecture plus directe et comprehension plus rapide des phrases longues",
    f5Title: "Themes Dark / Light libres",
    f5Desc: "Adaptez l'affichage a votre environnement",
    f6Title: "Archivage automatique des traductions",
    f6Desc: "NOTE.md du jour et captures sont ranges automatiquement",
    resultTitle: "Plus qu'une traduction correcte",
    resultDesc: "Informations lexicales structurees en contexte avec surlignage par token",
    previewInput: "Entree",
    previewResult: "Resultat",
    lastCtaTitle: "Transformez chaque traduction en apprentissage",
    lastCtaDesc: "Demarrez avec 月の言葉 des maintenant",
    lastCtaBtn: "Telecharger",
    statusReady: "Pret",
    mdEntryHeading: getMdEntryHeading("fr"),
    mdEntryTitle: "Deposez un dossier ici",
    mdEntrySub: getMdEntrySub("fr"),
    mdEntryCta: getMdEntryCta("fr"),
    mdEntryNoMarkdown: "Aucun fichier Markdown trouve dans ce dossier"
  },
  de: {
    heroTitleLine1: "Schneller ubersetzen",
    heroTitleLine2: "tiefer verstehen",
    heroTitleLine3: "月の言葉",
    heroDesc: "Mit immersiver Dark-Designsprache entwickelt, fur Sprachlernen",
    ctaPrimary: "Kostenlos testen",
    ctaSecondary: "Funktionen ansehen",
    sectionFeatureTitle: "Ubersetzungsfluss ohne Unterbrechung",
    f1Title: "Ein Klick aufrufen, sprechen und sofort ubersetzen",
    f1Desc: "Schnell starten und direkt ubersetzen ohne Kontextwechsel",
    f2Title: "Tsuki CLI basierte Sofortubersetzung zwischen Apps",
    f2Desc: "Mit Tsuki CLI aus jeder App direkt einspringen",
    f3Title: "Wortform, Aussprache, Bedeutung, Beispiele in einer Ansicht",
    f3Desc: "Alle wichtigen Lexiksignale kompakt auf einem Screen",
    f4Title: "Token-Highlight + Furigana in Beispielsatzen",
    f4Desc: "Klarere Lesefuhrung und schnelleres Verstehen langer Satze",
    f5Title: "Dark / Light Themen wechseln",
    f5Desc: "Darstellung an Umgebung anpassen",
    f6Title: "Automatische Ubersetzungsablage",
    f6Desc: "Tagliches NOTE.md und Screenshots werden automatisch archiviert",
    resultTitle: "Mehr als nur korrekt ubersetzt",
    resultDesc: "Strukturierte Wortinformationen im Kontext mit Token-Highlighting",
    previewInput: "Eingabe",
    previewResult: "Ergebnis",
    lastCtaTitle: "Mach aus jeder Ubersetzung Lernen",
    lastCtaDesc: "Starte jetzt mit 月の言葉",
    lastCtaBtn: "Jetzt herunterladen",
    statusReady: "Bereit",
    mdEntryHeading: getMdEntryHeading("de"),
    mdEntryTitle: "Ordner hier ablegen",
    mdEntrySub: getMdEntrySub("de"),
    mdEntryCta: getMdEntryCta("de"),
    mdEntryNoMarkdown: "In diesem Ordner wurden keine Markdown-Dateien gefunden"
  },
  ru: {
    heroTitleLine1: "Perevodite bystree",
    heroTitleLine2: "ponimaite glubzhe",
    heroTitleLine3: "月の言葉",
    heroDesc: "Sdelano v immersivnom temnom stile dlia izucheniia iazykov",
    ctaPrimary: "Poprobovat besplatno",
    ctaSecondary: "Smotret funktsii",
    sectionFeatureTitle: "Nepreyrvnyi perevodcheskii potok",
    f1Title: "Odin klik, skazali i srazu perevod",
    f1Desc: "Bystryi zapusk i perevod bez razryva rabochego potoka",
    f2Title: "Mgnovennyi mezhprilozhencheskii perevod cherez Tsuki CLI",
    f2Desc: "Vkhod v perevod iz liubogo prilozheniia po Tsuki CLI",
    f3Title: "Forma, proiznoshenie, znachenie i primery v odnom vide",
    f3Desc: "Vazhnaia leksicheskaia informatsiia sobrana na odnom ekrane",
    f4Title: "Podsvetka tokenov + furigana v primerakh",
    f4Desc: "Chtenie stanovitsia poniatnee, dlinnye frazy vosprinimaiutsia legche",
    f5Title: "Perekliuchenie mezhdu Dark / Light",
    f5Desc: "Vybirajte temu po obstanovke",
    f6Title: "Avtomaticheskoe nakoplenie perevodov",
    f6Desc: "Dnevnoi NOTE.md i skrinhoty sokhraniaiutsia avtomaticheski",
    resultTitle: "Bolshe, chem prosto pravilnyi perevod",
    resultDesc: "Strukturirovannaia leksika v kontekste i bystryi fokus cherez podsvetku tokenov",
    previewInput: "Vvod",
    previewResult: "Rezultat",
    lastCtaTitle: "Prevratite kazhdyi perevod v obuchenie",
    lastCtaDesc: "Nachnite s 月の言葉 uzhe seichas",
    lastCtaBtn: "Skachat",
    statusReady: "Gotovo",
    mdEntryHeading: getMdEntryHeading("ru"),
    mdEntryTitle: "Peretashchite papku siuda",
    mdEntrySub: getMdEntrySub("ru"),
    mdEntryCta: getMdEntryCta("ru"),
    mdEntryNoMarkdown: "V etoi papke net failov Markdown"
  }
};

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

function App() {
  const [pathname, setPathname] = useState(() =>
    typeof window === "undefined" ? "/" : window.location.pathname
  );
  const folderInputRef = useRef(null);
  const [mdInitialEntries, setMdInitialEntries] = useState([]);
  const [mdEntryDragging, setMdEntryDragging] = useState(false);
  const [noMarkdownModalOpen, setNoMarkdownModalOpen] = useState(false);
  const [modalMessage, setModalMessage] = useState("");

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
    if (typeof window !== "undefined" && window.location.pathname !== "/md") {
      window.history.pushState(null, "", "/md");
    }
    setMdInitialEntries(initialEntries);
    setPathname("/md");
  }, []);

  const [language, setLanguage] = useState(() => {
    const savedLanguage = readLanguageFromCookie();
    return LANGUAGES.some((item) => item.code === savedLanguage) ? savedLanguage : "ja";
  });
  const onLanguageChange = useCallback((nextLanguage) => {
    setLanguage(nextLanguage);
    persistLanguageToCookie(nextLanguage);
  }, []);
  const t = useMemo(() => COPY[language] ?? COPY.ja, [language]);
  const modalCopy = useMemo(() => MODAL_COPY[language] ?? MODAL_COPY.ja, [language]);
  const productName = useMemo(() => PRODUCT_NAMES[language] ?? PRODUCT_NAMES.ja, [language]);
  const productImage = useMemo(() => PRODUCT_IMAGES[language] ?? PRODUCT_IMAGES.ja, [language]);
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

        const containsMarkdown = await directoryContainsMarkdown(directoryHandle);

        if (!containsMarkdown) {
          notifyNoMarkdown();
          return;
        }

        const entries = await collectFilesFromDirectoryHandle(directoryHandle);
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
  }, [navigateToMd, notifyNoMarkdown, notifyPermissionDenied]);

  const onFolderInputChange = useCallback(
    (event) => {
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
    [navigateToMd, notifyNoMarkdown]
  );
  const featureItems = [
    { title: t.f1Title, desc: t.f1Desc },
    { title: t.f2Title, desc: t.f2Desc },
    { title: t.f3Title, desc: t.f3Desc },
    { title: t.f4Title, desc: t.f4Desc },
    { title: t.f5Title, desc: t.f5Desc },
    { title: t.f6Title, desc: t.f6Desc }
  ];

  if (pathname === "/md") {
    return (
        <MdViewerPage
          initialEntries={mdInitialEntries}
          onInitialEntriesConsumed={() => setMdInitialEntries([])}
          language={language}
          onLanguageChange={onLanguageChange}
          languageOptions={LANGUAGES}
          productName={productName}
        />
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
          </div>
          <div className="nav-actions">
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
                if (!hasMarkdownEntries(droppedFiles)) {
                  notifyNoMarkdown();
                  return;
                }
                navigateToMd(droppedFiles);
              } catch {
                notifyNoMarkdown();
              }
            }}
            onCtaClick={openFolderPicker}
          />
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
