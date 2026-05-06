export const NOTE_JA_ENTRIES = [
  {
    source: "言葉の風土を記し、文字の奥義を探る",
    headwordKanji: "風土記",
    headwordKana: "ふどき",
    meaning: "言葉の空気感を記録し、読みや構造を見える化する。",
    tokens: [
      { furigana: "ことば", kanji: "言葉", highlight: "yellow" },
      { furigana: "ふうど", kanji: "風土", highlight: "purple" },
      { furigana: "きる", kanji: "記し", highlight: "green" },
      { furigana: "", kanji: "、", highlight: "gray" },
      { furigana: "もじ", kanji: "文字", highlight: "blue" },
      { furigana: "おうぎ", kanji: "奥義", highlight: "gray" },
      { furigana: "さぐる", kanji: "探る", highlight: "yellow" }
    ]
  },
  {
    source: "ブラウザで動作する日本語テキスト解析ツールです",
    headwordKanji: "解析",
    headwordKana: "かいせき",
    meaning: "文を分かち書きし、語の役割と読みを可視化する。",
    tokens: [
      { furigana: "ぶらうざ", kanji: "ブラウザ", highlight: "gray" },
      { furigana: "どうさ", kanji: "動作", highlight: "blue" },
      { furigana: "にほんご", kanji: "日本語", highlight: "purple" },
      { furigana: "てきすと", kanji: "テキスト", highlight: "green" },
      { furigana: "かいせき", kanji: "解析", highlight: "yellow" },
      { furigana: "つーる", kanji: "ツール", highlight: "gray" }
    ]
  },
  {
    source: "形態素解析と音声読み上げで日本語学習を支援する",
    headwordKanji: "学習",
    headwordKana: "がくしゅう",
    meaning: "形態素・読み・音声をつないで理解を助ける。",
    tokens: [
      { furigana: "けいたいそ", kanji: "形態素", highlight: "purple" },
      { furigana: "かいせき", kanji: "解析", highlight: "yellow" },
      { furigana: "おんせい", kanji: "音声", highlight: "blue" },
      { furigana: "よみあげ", kanji: "読み上げ", highlight: "green" },
      { furigana: "にほんご", kanji: "日本語", highlight: "gray" },
      { furigana: "がくしゅう", kanji: "学習", highlight: "yellow" }
    ]
  }
];

export const NOTE_UI_COPY_BY_LANGUAGE = {
  ja: {
    pageTitle: "ノート",
    pageSub: "日本語テキストを Tsuki の出力スタイルで確認",
    inputLabel: "入力",
    outputLabel: "出力",
    inputPlaceholder: "ここに日本語テキストを入力して解析...",
    defaultInput: "どこから始めますか",
    fallbackHeadwordKanji: "",
    fallbackHeadwordKana: "",
    fallbackMeaning: ""
  },
  en: {
    pageTitle: "Note",
    pageSub: "Preview text with Tsuki-style output layout",
    inputLabel: "Input",
    outputLabel: "Output",
    inputPlaceholder: "Enter text here...",
    defaultInput: "How can I help",
    fallbackHeadwordKanji: "",
    fallbackHeadwordKana: "",
    fallbackMeaning: ""
  },
  "cn": {
    pageTitle: "笔记",
    pageSub: "用 Tsuki 风格查看文本输出效果",
    inputLabel: "输入",
    outputLabel: "输出",
    inputPlaceholder: "在这里输入文本...",
    defaultInput: "我能帮什么忙吗",
    fallbackHeadwordKanji: "",
    fallbackHeadwordKana: "",
    fallbackMeaning: ""
  },
  "tw": {
    pageTitle: "筆記",
    pageSub: "用 Tsuki 風格查看文字輸出效果",
    inputLabel: "輸入",
    outputLabel: "輸出",
    inputPlaceholder: "在這裡輸入文字...",
    defaultInput: "我們該從哪裡開始",
    fallbackHeadwordKanji: "",
    fallbackHeadwordKana: "",
    fallbackMeaning: ""
  },
  ko: {
    pageTitle: "노트",
    pageSub: "Tsuki 스타일 출력 레이아웃 미리보기",
    inputLabel: "입력",
    outputLabel: "출력",
    inputPlaceholder: "여기에 텍스트를 입력하세요...",
    defaultInput: "어디서부터 시작할까요",
    fallbackHeadwordKanji: "",
    fallbackHeadwordKana: "",
    fallbackMeaning: ""
  },
  es: {
    pageTitle: "Nota",
    pageSub: "Vista previa del resultado con estilo Tsuki",
    inputLabel: "Entrada",
    outputLabel: "Salida",
    inputPlaceholder: "Escribe texto aqui...",
    defaultInput: "¿Por dónde empezamos",
    fallbackHeadwordKanji: "",
    fallbackHeadwordKana: "",
    fallbackMeaning: ""
  },
  fr: {
    pageTitle: "Note",
    pageSub: "Apercu du rendu de texte style Tsuki",
    inputLabel: "Entree",
    outputLabel: "Sortie",
    inputPlaceholder: "Saisissez du texte ici...",
    defaultInput: "Par où commence-t-on",
    fallbackHeadwordKanji: "",
    fallbackHeadwordKana: "",
    fallbackMeaning: ""
  },
  de: {
    pageTitle: "Notiz",
    pageSub: "Textausgabe im Tsuki-Stil anzeigen",
    inputLabel: "Eingabe",
    outputLabel: "Ausgabe",
    inputPlaceholder: "Text hier eingeben...",
    defaultInput: "Wo fangen wir an",
    fallbackHeadwordKanji: "",
    fallbackHeadwordKana: "",
    fallbackMeaning: ""
  },
  ru: {
    pageTitle: "Zametka",
    pageSub: "Predprosmotr vyvoda v stile Tsuki",
    inputLabel: "Vvod",
    outputLabel: "Vyvod",
    inputPlaceholder: "Vvedite tekst...",
    defaultInput: "С чего начнем",
    fallbackHeadwordKanji: "",
    fallbackHeadwordKana: "",
    fallbackMeaning: ""
  }
};

export const NOTE_DEFAULT_COPY = NOTE_UI_COPY_BY_LANGUAGE.ja;

export function getNoteCopy(language) {
  return NOTE_UI_COPY_BY_LANGUAGE[language] || NOTE_DEFAULT_COPY;
}

export const NOTE_DEFAULT_INPUT_SET = new Set(
  Object.values(NOTE_UI_COPY_BY_LANGUAGE).map((copy) => copy.defaultInput)
);
