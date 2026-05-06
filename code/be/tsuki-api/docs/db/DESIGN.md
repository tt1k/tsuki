# DB Design for Multilingual Japanese Dictionary

## 目标

支持以下能力：

1. **以日语词条为核心存储**
   - `kanji`
   - `hiragana`
   - `sentence`
   - `tokens`（JSON 数组）

2. **支持多语言输入查询（限定 4 种语言）**
   - 输入日语：`食べる`
   - 输入英文：`happy`
   - 输入中文简体：`开心`
   - 输入中文繁体：`開心`

3. **输出仍以日语词条为主**
   - `kanji`
   - `hiragana`
   - `sentence`
   - `tokens`（JSON 数组）

4. **`mean_w` 与 `mean_s` 按目标语言输出**
   - `mean_w`: 词条解释
   - `mean_s`: 例句解释

## 设计原则

### 1. 日语词条本体和多语言释义分离
日语词条本身是主数据；不同语言的解释属于附属数据。

### 2. 查询入口和释义分离
“用户输入什么词可以命中这个日语词条”与“这个词条的多语言解释是什么”是两类不同数据，应该分别建表。

## 表结构

### 1. 日语词条主表

```sql
CREATE TABLE tsuki_main (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kanji TEXT NOT NULL,
  hiragana TEXT NOT NULL,
  sentence TEXT NOT NULL,
  tokens TEXT NOT NULL,
  updated INTEGER NOT NULL
);
```

### 字段说明

- `id`: 主键
- `kanji`: 日语词条（通常是汉字或常见书写形式）
- `hiragana`: 平假名读音
- `sentence`: 日语例句
- `tokens`: 日语分词结果，JSON 数组字符串；每个元素形如 `{"k":"都内","f":"とない"}`，其中 `k` 为词形，`f` 为读音（助词等可省略）
- `updated`: 更新时间戳

### 2. 多语言释义表

```sql
CREATE TABLE tsuki_mean (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  word_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  mean_w TEXT NOT NULL,
  mean_s TEXT NOT NULL,
  updated INTEGER NOT NULL,
  FOREIGN KEY (word_id) REFERENCES tsuki_main(id) ON DELETE CASCADE,
  CHECK(lang IN ('cn', 'tw', 'en', 'ja')),
  UNIQUE(word_id, lang)
);
```

### 字段说明

- `word_id`: 对应 `tsuki_main.id`
- `lang`: 释义语言，限定为 `cn` / `tw` / `en` / `ja`
- `mean_w`: 对应 `kanji` 的解释文本
- `mean_s`: 对应 `sentence` 的解释文本
- `updated`: 更新时间戳

### 约束说明

- `UNIQUE(word_id, lang)`：同一个日语词条在同一种语言下只能有一条主解释

### 3. 多语言查询入口表

```sql
CREATE TABLE tsuki_seek (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  word_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  term TEXT NOT NULL,
  updated INTEGER NOT NULL,
  FOREIGN KEY (word_id) REFERENCES tsuki_main(id) ON DELETE CASCADE,
  CHECK(lang IN ('cn', 'tw', 'en', 'ja')),
  UNIQUE(word_id, lang, term)
);
```

### 字段说明

- `word_id`: 对应 `tsuki_main.id`
- `lang`: 输入词所属语言，限定为 `cn` / `tw` / `en` / `ja`
- `term`: 查询词（入库前已完成归一化），例如 `happy`
- `updated`: 更新时间戳

## 示例数据

### 1. `tsuki_main`（日语词条本体）

> `tokens` 在库中以 JSON 字符串存储。

```sql
INSERT INTO tsuki_main (id, kanji, hiragana, sentence, tokens, updated) VALUES
(1, '都内', 'とない', '都内には多くの観光スポットがあります。', '[{"k":"都内","f":"とない"},{"k":"に"},{"k":"は"},{"k":"多く","f":"おおく"},{"k":"の"},{"k":"観光","f":"かんこう"},{"k":"スポット"},{"k":"が"},{"k":"あり"},{"k":"ます"}]', 1710000000),
(2, '食べる', 'たべる', '私は毎日りんごを食べる。', '[{"k":"私","f":"わたし"},{"k":"は"},{"k":"毎日","f":"まいにち"},{"k":"りんご"},{"k":"を"},{"k":"食べる","f":"たべる"}]', 1710000000);
```

### 2. `tsuki_mean`（多语言释义）

```sql
INSERT INTO tsuki_mean (word_id, lang, mean_w, mean_s, updated) VALUES
(1, 'ja', '東京都の区域内。東京23区内や東京の市部を含む地域を指す。', '都内には多くの観光スポットがある。', 1710000000),
(1, 'en', 'within Tokyo; in the Tokyo metropolitan area', 'There are many tourist attractions within Tokyo.', 1710000000),
(1, 'cn', '东京都内；东京市区范围内', '东京都内有很多观光景点。', 1710000000),
(1, 'tw', '東京都內；東京市區範圍內', '東京都內有很多觀光景點。', 1710000000),
(2, 'ja', '食物を口に入れてかみ、飲み込む', '私は毎日りんごを食べる。', 1710000000),
(2, 'en', 'to eat; to consume food', 'I eat apples every day.', 1710000000),
(2, 'cn', '吃；进食', '我每天吃苹果。', 1710000000),
(2, 'tw', '吃；進食', '我每天吃蘋果。', 1710000000);
```

### 3. `tsuki_seek`（多语言查询入口）

```sql
INSERT INTO tsuki_seek (word_id, lang, term, updated) VALUES
(1, 'ja', '都内', 1710000000),
(1, 'ja', 'とない', 1710000000),
(1, 'en', 'within tokyo', 1710000000),
(1, 'en', 'tokyo metropolitan area', 1710000000),
(1, 'cn', '东京都内', 1710000000),
(1, 'cn', '东京市区', 1710000000),
(1, 'tw', '東京都內', 1710000000),
(1, 'tw', '東京市區', 1710000000),
(2, 'ja', '食べる', 1710000000),
(2, 'ja', 'たべる', 1710000000),
(2, 'en', 'eat', 1710000000),
(2, 'cn', '吃', 1710000000),
(2, 'tw', '吃', 1710000000);
```

## 返回结果示例

```json
{
  "kanji": "都内",
  "hiragana": "とない",
  "mean_w": "within Tokyo; in the Tokyo metropolitan area",
  "mean_s": "There are many tourist attractions within Tokyo.",
  "sentence": "都内には多くの観光スポットがあります。",
  "tokens": [
    {"k": "都内", "f": "とない"},
    {"k": "に"},
    {"k": "は"},
    {"k": "多く", "f": "おおく"},
    {"k": "の"},
    {"k": "観光", "f": "かんこう"},
    {"k": "スポット"},
    {"k": "が"},
    {"k": "あり"},
    {"k": "ます"}
  ]
}
```
