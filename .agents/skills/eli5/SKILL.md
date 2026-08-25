---
name: eli5
description: Explain a topic like I'm a 5 year old. Use when the user asks for an ELI5, a dead-simple explanation, or a picture explainer of how something works.
---

# eli5

Explain the topic like I'm someone who knows nothing about it, using a single self-contained HTML page with big pictures and few words.

## How to build the explainer

1. Distill the topic into 3-6 core ideas. If you can't explain it simply, you don't understand it well enough yet — investigate first.
2. Create one self-contained HTML file (all CSS inline, no external dependencies) where each idea gets its own full-width section:
   - **One idea per section** — a huge visual (inline SVG, large emoji compositions, or simple CSS shapes) plus at most two short sentences
   - **Everyday analogies only** — mailboxes, water pipes, recipe cards; zero jargon, zero acronyms without explanation
   - **Big type, generous whitespace** — readable from across the room
   - **A one-line summary at the end** — the whole topic in a single sentence a child could repeat
3. Save it as `eli5-<topic>.html` in the current directory (or where the user asks) and tell the user to open it in a browser.

## Rules

- Few words. If a section needs a paragraph, split it or cut it.
- Pictures carry the explanation; text only labels the pictures.
- Accuracy still matters: simplify by omitting detail, never by saying something false.
