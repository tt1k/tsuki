export const MD_ENTRY_HEADING_COPY = {
  ja: "あなただけの知識ノートを作ろう",
  "cn": "构建你的专属知识笔记",
  "tw": "構建你的專屬知識筆記",
  en: "Build your own knowledge system",
  ko: "나만의 지식 노트를 구축하세요",
  es: "Construye tus propias notas de conocimiento",
  fr: "Construisez vos propres notes de connaissances",
  de: "Erstelle deine eigenen Wissensnotizen",
  ru: "Sozdavaite svoi sobstvennye zametki znanii"
};

export const MD_ENTRY_SUB_COPY = {
  ja: "フォルダをドロップすると Markdown プレビューへ進みます",
  "cn": "拖入目录可直接进入 Markdown 预览",
  "tw": "拖入目錄可直接進入 Markdown 預覽",
  en: "Drop a directory to open Markdown preview directly",
  ko: "디렉터리를 드롭하면 Markdown 미리보기로 바로 이동합니다",
  es: "Suelta un directorio para abrir la vista previa de Markdown al instante",
  fr: "Deposez un dossier pour ouvrir directement l'aperçu Markdown",
  de: "Lege ein Verzeichnis ab, um die Markdown-Vorschau direkt zu offnen",
  ru: "Peretashchite direktoriiu, chtoby srazu otkryt predprosmotr Markdown"
};

export const MD_ENTRY_CTA_COPY = {
  ja: "またはノートのあるフォルダを選択",
  "cn": "或选择笔记所在的文件夹",
  "tw": "或選擇筆記所在的資料夾",
  en: "Or select the folder containing your notes",
  ko: "또는 노트가 있는 폴더 선택",
  es: "O selecciona la carpeta de tus notas",
  fr: "Ou selectionnez le dossier de vos notes",
  de: "Oder den Ordner mit deinen Notizen auswahlen",
  ru: "Ili vyberite papku s vashimi zametkami"
};

export function getMdEntrySub(language) {
  return MD_ENTRY_SUB_COPY[language] ?? MD_ENTRY_SUB_COPY.ja;
}

export function getMdEntryHeading(language) {
  return MD_ENTRY_HEADING_COPY[language] ?? MD_ENTRY_HEADING_COPY.ja;
}

export function getMdEntryCta(language) {
  return MD_ENTRY_CTA_COPY[language] ?? MD_ENTRY_CTA_COPY.ja;
}
