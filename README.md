<p align="center">
  <img src="./icon.svg" alt="Tsuki Icon" width="128" height="128" />
</p>

# Tsuki

Tsuki is a desktop-first Japanese translation workspace built for learners who want speed, clarity, and long-term retention in one focused flow.

## What is Tsuki

Tsuki combines a native macOS app with a lightweight CLI entrypoint for Japanese-focused translation and study.
It is designed for fast lookup, sentence-level understanding, and automatic note accumulation,
so each translation can move from a quick answer to durable Japanese learning progress.

## Features

1. **One-tap invoke, speak and translate**  
   Launch quickly and translate immediately without breaking your working context.

2. **Tsuki CLI based cross-app instant translation**  
   Jump into translation from any app through Tsuki CLI in seconds.

3. **Lemma, pronunciation, senses, examples in one view**  
   Keep key Japanese lexical signals on a single screen instead of switching panels.

4. **Token highlight + furigana on example lines**  
   Read longer Japanese sentences faster with clearer segmentation and reading guidance.

5. **Switch between Dark / Light themes**  
   Adapt visual style to your environment for day and night use.

6. **Automatic translation archive for learning**  
   Save daily note entries and screenshots automatically as long-term study assets.

## CLI

Tsuki includes a CLI for instant cross-app Japanese translation:

```bash
tsuki "text to translate"
```

You can also invoke translation via URL scheme:

```text
tsuki://translate?text=<urlencoded-text>
```

## Getting Started

Download the latest packaged app from GitHub Releases, or run from source.

From the repository root:

```bash
./tsuki.sh fe run
```
