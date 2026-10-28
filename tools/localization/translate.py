#!/usr/bin/env python3
"""Translate new and changed strings in assets/locales/en.po into every other locale.

Detection needs no stored state. A key that is missing or empty in a locale is
translated, a key that left en.po is removed, and when --base names a reachable
commit, keys whose English text changed since then are re-translated. Every
translation passes deterministic checks, a back-translation, and an independent
review before it is written. Reports (JSON, Markdown, HTML) land in --out.

Supported locales are whatever .po files exist in assets/locales. Each needs a
section in guides.md and an entry in config.toml next to this script. Models,
thresholds and the glossary live in config.toml too.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
import threading
from dataclasses import asdict, dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
LOCALES_DIR = ROOT / "assets" / "locales"
GUIDES = HERE / "guides.md"
SOURCE = "en"
ZERO_SHA = "0" * 40

# --------------------------------------------------------------------------- config

CONFIG_PATH = HERE / "config.toml"

# Filled by load_config(); module globals so the pipeline and the tests share them.
MODELS: dict[str, str] = {}
BATCH_SIZE = WORKERS = MAX_TOKENS = EXAMPLES = 0
FIX_MIN_CONFIDENCE = LOW_CONFIDENCE = 0.0
KEEP: list[str] = []
ALIASES: dict[str, dict[str, str]] = {}
ALLOW_IDENTICAL: set[str] = set()
LENGTH: dict[str, tuple[float, float]] = {}
LOCALES: dict[str, tuple[str, bool, str]] = {}


def load_config(path: Path = CONFIG_PATH) -> None:
    import tomllib

    g = globals()
    d = tomllib.loads(path.read_text(encoding="utf-8"))
    g["MODELS"] = dict(d["models"])
    run = d.get("run", {})
    g["BATCH_SIZE"] = int(run.get("batch_size", 40))
    g["WORKERS"] = int(run.get("workers", 6))
    g["MAX_TOKENS"] = int(run.get("max_tokens", 8192))
    g["EXAMPLES"] = int(run.get("examples", 10))
    g["FIX_MIN_CONFIDENCE"] = float(run.get("apply_fix_min_confidence", 0.8))
    g["LOW_CONFIDENCE"] = float(run.get("low_confidence", 0.7))
    gl = d.get("glossary", {})
    g["KEEP"] = list(gl.get("keep", []))
    g["ALIASES"] = {k: dict(v) for k, v in gl.get("aliases", {}).items()}
    g["ALLOW_IDENTICAL"] = set(g["KEEP"]) | set(gl.get("allow_identical", []))
    g["LENGTH"] = {k: (float(v[0]), float(v[1])) for k, v in d.get("length", {}).items()}
    g["LENGTH"].setdefault("default", (0.4, 3.0))
    g["LOCALES"] = {
        code: (m.get("name", code), bool(m.get("rtl", False)), m.get("script", "default"))
        for code, m in d.get("locales", {}).items()
    }
    a = d.get("audit", {})
    g["AUDIT_SOURCE_DIRS"] = list(a.get("source_dirs", ["lib"]))
    g["AUDIT_DYNAMIC_PREFIXES"] = list(a.get("dynamic_prefixes", []))


AUDIT_SOURCE_DIRS: list[str] = []
AUDIT_DYNAMIC_PREFIXES: list[str] = []
load_config()

PLACEHOLDER_RE = re.compile(r"%(?:\d+\$)?[sd]")
LEAK_RE = re.compile(r"^\s*(translation|translated|traducci[oó]n)\s*:", re.I)


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


@dataclass
class LocaleMeta:
    code: str
    name: str
    rtl: bool = False
    script: str = "default"


def meta_for(code: str) -> LocaleMeta:
    if code in LOCALES:
        name, rtl, script = LOCALES[code]
        return LocaleMeta(code, name, rtl, script)
    log(f"warning: no metadata for {code}; using defaults")
    return LocaleMeta(code, code)


def load_guide(code: str) -> str:
    """The 'common' section of guides.md followed by the locale's own section."""
    sections: dict[str, list[str]] = {}
    current = None
    for line in GUIDES.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^## (\S+)", line)
        if m:
            current = m.group(1)
            sections[current] = []
        elif current:
            sections[current].append(line)
    if code not in sections:
        log(f"warning: guides.md has no '## {code}' section")
    common = "\n".join(sections.get("common", [])).strip()
    own = "\n".join(sections.get(code, [])).strip()
    return f"{common}\n\n{own}".strip()


# --------------------------------------------------------------------------- PO files


def po_unescape(s: str) -> str:
    out, i = [], 0
    table = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\"}
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            out.append(table.get(s[i + 1], "\\" + s[i + 1]))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def po_escape(s: str) -> str:
    return (s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
            .replace("\t", "\\t").replace("\r", "\\r"))


_STR_LINE = re.compile(r'^\s*"(.*)"\s*$')
_KW_LINE = re.compile(r'^(?:msgid|msgstr)\s+"(.*)"\s*$')


@dataclass
class Entry:
    key: str | None
    value: str
    comment: str
    raw: list[str]
    msgstr_start: int
    msgstr_end: int


class PoFile:
    """Line-preserving PO reader/writer. Untouched entries round-trip byte for byte."""

    def __init__(self, path: Path):
        self.path = path
        self.entries: list[Entry] = []
        self._index: dict[str, Entry] = {}
        self._parse(path.read_text(encoding="utf-8"))

    def _parse(self, text: str) -> None:
        groups: list[list[str]] = []
        cur: list[str] = []
        seen_msgstr = False
        for line in text.splitlines(keepends=True):
            s = line.rstrip("\r\n")
            if seen_msgstr and (s.startswith("#") or s.startswith("msgid")):
                groups.append(cur)
                cur, seen_msgstr = [], False
            if s.startswith("msgstr"):
                seen_msgstr = True
            cur.append(line)
        if cur:
            groups.append(cur)
        self.entries = [self._entry(raw) for raw in groups]
        self._index = {e.key: e for e in self.entries if e.key is not None}

    @staticmethod
    def _entry(raw: list[str]) -> Entry:
        stripped = [l.rstrip("\r\n") for l in raw]
        msgid_i = next((i for i, l in enumerate(stripped) if l.startswith("msgid ")), None)
        if msgid_i is None:
            return Entry(None, "", "", raw, -1, -1)
        msgstr_i = next(i for i, l in enumerate(stripped) if l.startswith("msgstr "))

        def collect(start: int, stop: int) -> tuple[str, int]:
            m = _KW_LINE.match(stripped[start])
            if not m:
                raise ValueError(f"malformed PO line: {stripped[start]!r}")
            parts = [m.group(1)]
            end = start + 1
            while end < stop:
                m = _STR_LINE.match(stripped[end])
                if not m:
                    break
                parts.append(m.group(1))
                end += 1
            return po_unescape("".join(parts)), end

        key, _ = collect(msgid_i, msgstr_i)
        value, msgstr_end = collect(msgstr_i, len(stripped))
        comment = "\n".join(l[1:].strip() for l in stripped[:msgid_i]
                            if l.startswith("#") and l[1:].strip())
        return Entry(key, value, comment, raw, msgstr_i, msgstr_end)

    def keys(self) -> list[str]:
        return [e.key for e in self.entries if e.key]

    def has(self, key: str) -> bool:
        return key in self._index

    def get(self, key: str) -> str | None:
        e = self._index.get(key)
        return None if e is None else e.value

    def comment(self, key: str) -> str:
        e = self._index.get(key)
        return "" if e is None else e.comment

    def set(self, key: str, value: str) -> None:
        e = self._index.get(key)
        line = f'msgstr "{po_escape(value)}"\n'
        if e is None:
            self._ensure_separator()
            e = Entry(key, value, "", [f'msgid "{po_escape(key)}"\n', line, "\n"], 1, 2)
            self.entries.append(e)
            self._index[key] = e
            return
        e.raw = e.raw[: e.msgstr_start] + [line] + e.raw[e.msgstr_end:]
        e.msgstr_end = e.msgstr_start + 1
        e.value = value

    def remove(self, key: str) -> None:
        e = self._index.pop(key, None)
        if e is not None:
            self.entries.remove(e)

    def _ensure_separator(self) -> None:
        if not self.entries:
            return
        last = self.entries[-1].raw
        if not last[-1].endswith("\n"):
            last[-1] += "\n"
        if last[-1].strip() != "":
            last.append("\n")

    def text(self) -> str:
        return "".join("".join(e.raw) for e in self.entries).rstrip("\n") + "\n"

    def write(self) -> None:
        self.path.write_text(self.text(), encoding="utf-8")


def validate_po(path: Path, expected_keys: int) -> None:
    """msgfmt when available, otherwise a strict re-parse."""
    if shutil.which("msgfmt"):
        r = subprocess.run(["msgfmt", "--check", "-o", os.devnull, str(path)],
                           capture_output=True, text=True)
        if r.returncode != 0:
            raise RuntimeError(f"msgfmt rejected {path.name}:\n{r.stderr}")
    if len(PoFile(path).keys()) != expected_keys:
        raise RuntimeError(f"{path.name} did not re-parse to the expected number of entries")


# --------------------------------------------------------------------------- detection


@dataclass
class Work:
    translate: dict[str, str | None] = field(default_factory=dict)  # key -> old value
    remove: list[str] = field(default_factory=list)
    reasons: dict[str, str] = field(default_factory=dict)  # key -> gap | changed


def english_at(base: str) -> dict[str, str] | None:
    if not base or base == ZERO_SHA:
        return None
    rel = LOCALES_DIR.relative_to(ROOT) / f"{SOURCE}.po"
    r = subprocess.run(["git", "show", f"{base}:{rel.as_posix()}"], cwd=ROOT,
                       capture_output=True, text=True)
    if r.returncode != 0:
        log(f"warning: cannot read en.po at {base}; using gap detection only")
        return None
    tmp = ROOT / "build" / "translate" / "en.base.po"
    tmp.parent.mkdir(parents=True, exist_ok=True)
    tmp.write_text(r.stdout, encoding="utf-8")
    po = PoFile(tmp)
    return {k: po.get(k) or "" for k in po.keys()}


def detect(en: PoFile, targets: dict[str, PoFile], base: str, limit: int) -> dict[str, Work]:
    old = english_at(base)
    changed: set[str] = set()
    if old is not None:
        changed = {k for k in en.keys() if k in old and old[k] != en.get(k)}
        log(f"{len(changed)} English strings changed since {base[:10]}")
    out: dict[str, Work] = {}
    for code, po in targets.items():
        w = Work()
        for k in en.keys():
            if not en.get(k):
                continue
            cur = po.get(k)
            if cur is None or cur == "":
                w.translate[k], w.reasons[k] = cur, "gap"
            elif k in changed:
                w.translate[k], w.reasons[k] = cur, "changed"
        if limit and len(w.translate) > limit:
            keep = list(w.translate)[:limit]
            w.translate = {k: w.translate[k] for k in keep}
            w.reasons = {k: w.reasons[k] for k in keep}
        w.remove = [k for k in po.keys() if not en.has(k)]
        out[code] = w
    return out


# --------------------------------------------------------------------------- checks


def placeholders(s: str) -> list[str]:
    return PLACEHOLDER_RE.findall(s)


def has_letters(s: str) -> bool:
    return any(c.isalpha() for c in s)


def check(source: str, target: str, meta: LocaleMeta) -> tuple[list[str], list[str]]:
    """Return (hard, soft) issues. Hard issues reject the string outright."""
    hard, soft = [], []
    if not target.strip():
        return ["empty"], soft
    if placeholders(source) != placeholders(target):
        hard.append(f"placeholders {placeholders(source)} -> {placeholders(target)}")
    if source.count("\n") != target.count("\n"):
        hard.append("line break count differs")
    if LEAK_RE.search(target):
        soft.append("starts with a 'Translation:' style prefix")
    if target.strip() == source.strip() and has_letters(source) and source.strip() not in ALLOW_IDENTICAL:
        soft.append("identical to English")
    if len(source) >= 6 and has_letters(source):
        lo, hi = LENGTH.get(meta.script, LENGTH["default"])
        ratio = len(target) / max(len(source), 1)
        if ratio < lo or ratio > hi:
            soft.append(f"length ratio {ratio:.2f} outside [{lo}, {hi}]")
    aliases = ALIASES.get(meta.code, {})
    for term in KEEP:
        if re.search(rf"(?<![A-Za-z]){re.escape(term)}(?![A-Za-z])", source):
            if term not in target and aliases.get(term, term) not in target:
                soft.append(f"glossary term '{term}' missing")
    return hard, soft


# --------------------------------------------------------------------------- model calls


class TruncatedResponse(RuntimeError):
    pass


class Claude:
    def __init__(self):
        import anthropic  # imported lazily so tests run without the SDK

        self.client = anthropic.Anthropic()
        self.usage: dict[str, dict[str, int]] = {}
        self._lock = threading.Lock()

    def _account(self, model: str, usage) -> None:
        with self._lock:
            u = self.usage.setdefault(model, {"input": 0, "cache_read": 0, "cache_write": 0, "output": 0})
            u["input"] += getattr(usage, "input_tokens", 0) or 0
            u["cache_read"] += getattr(usage, "cache_read_input_tokens", 0) or 0
            u["cache_write"] += getattr(usage, "cache_creation_input_tokens", 0) or 0
            u["output"] += getattr(usage, "output_tokens", 0) or 0

    def tool_call(self, model: str, system: str, user: str, tool: dict) -> dict:
        resp = self.client.messages.create(
            model=model,
            max_tokens=MAX_TOKENS,
            system=[{"type": "text", "text": system, "cache_control": {"type": "ephemeral"}}],
            tools=[tool],
            tool_choice={"type": "tool", "name": tool["name"]},
            messages=[{"role": "user", "content": user}],
        )
        self._account(model, resp.usage)
        if resp.stop_reason == "max_tokens":
            raise TruncatedResponse(model)
        for block in resp.content:
            if block.type == "tool_use":
                return block.input
        raise RuntimeError(f"{model} returned no tool call")

    def batched(self, items: list, fn) -> list:
        """Run fn on chunks of items, halving a chunk that overflows max_tokens."""
        results = []
        queue = [items[i:i + BATCH_SIZE] for i in range(0, len(items), BATCH_SIZE)]
        while queue:
            chunk = queue.pop(0)
            try:
                results.extend(fn(chunk))
            except TruncatedResponse:
                if len(chunk) == 1:
                    raise
                mid = len(chunk) // 2
                queue[:0] = [chunk[:mid], chunk[mid:]]
        return results


def _tool(name: str, desc: str, item: dict, required: list[str], list_key: str) -> dict:
    return {
        "name": name,
        "description": desc,
        "input_schema": {
            "type": "object",
            "properties": {list_key: {"type": "array", "items": {
                "type": "object", "properties": item, "required": required}}},
            "required": [list_key],
        },
    }


TRANSLATE_TOOL = _tool(
    "submit_translations", "Submit the final UI translations, one entry per key.",
    {"key": {"type": "string"},
     "text": {"type": "string", "description": "The translated UI string only."},
     "note": {"type": "string", "description": "One short sentence when a choice was not obvious, else empty."}},
    ["key", "text", "note"], "translations")

BACK_TOOL = _tool(
    "submit_back_translations", "Submit a literal English rendering of each string.",
    {"key": {"type": "string"}, "english": {"type": "string"}},
    ["key", "english"], "items")

SCORE = {"type": "integer", "minimum": 1, "maximum": 5}
REVIEW_TOOL = _tool(
    "submit_review", "Submit the review verdict for every string.",
    {"key": {"type": "string"},
     "verdict": {"type": "string", "enum": ["pass", "fix", "flag"]},
     "confidence": {"type": "number", "minimum": 0, "maximum": 1},
     "fix": {"type": "string", "description": "Corrected UI string when verdict is fix, else empty."},
     "note": {"type": "string", "description": "One sentence, empty on a clean pass."},
     "scores": {"type": "object",
                "properties": {k: SCORE for k in ("accuracy", "naturalness", "register", "terminology", "ui_fit")},
                "required": ["accuracy", "naturalness", "register", "terminology", "ui_fit"]}},
    ["key", "verdict", "confidence", "fix", "note", "scores"], "reviews")


def glossary_text(code: str) -> str:
    aliases = ALIASES.get(code, {})
    terms = [f"{t} (written {aliases[t]} in this locale)" if t in aliases else t for t in KEEP]
    return "Keep these product and platform names exactly as written, in Latin script: " + ", ".join(terms)


def translator_system(meta: LocaleMeta, guide: str) -> str:
    return f"""You are the localization lead for Lantern, a VPN and censorship-circumvention app. You translate its user interface from English into {meta.name} ({meta.code}).

{guide}

{glossary_text(meta.code)}

Output rules:
- Call submit_translations once with exactly one entry per key you were given.
- "text" is the final UI string and nothing else: no quotes around it, no explanations, no alternatives.
- "note" is one short English sentence only when you made a choice a reviewer should know about; otherwise an empty string."""


def back_system(meta: LocaleMeta) -> str:
    return f"""You render {meta.name} app UI strings back into literal English so a reviewer who does not read {meta.name} can judge their meaning.
Translate what the text actually says, including any awkwardness or errors. Do not improve it, do not guess the intended meaning, keep placeholders like %s and %d and \\n where they appear.
Call submit_back_translations once with one entry per key."""


def reviewer_system(meta: LocaleMeta, guide: str) -> str:
    return f"""You are an independent senior {meta.name} localization reviewer for Lantern, a VPN and censorship-circumvention app. You did not write these translations. Judge each one against the style guide below.

{guide}

{glossary_text(meta.code)}

For each string you get the English source, developer context, the {meta.name} translation, a literal back-translation produced by a model that did not see the English, and any automated check notes.

Verdicts:
- pass: ship as is.
- fix: there is a real problem and you supply the corrected UI string in "fix". Keep placeholders identical in count and order.
- flag: a problem you cannot fix confidently, or a judgment call that should be visible in the report.

"confidence" (0 to 1) is how sure you are that the final string (your fix when verdict is fix, otherwise the translation) is correct, natural, and right for the UI.
Score accuracy, naturalness, register, terminology, and ui_fit from 1 to 5.
Be strict about meaning, placeholders, register, and script. Do not rewrite acceptable translations for taste alone.
Call submit_review once with one entry per key."""


def pick_examples(en: PoFile, po: PoFile, pending: list[str], n: int) -> list[dict]:
    done = [k for k in po.keys() if po.get(k) and en.get(k) and k not in pending]
    if not done:
        return []
    prefixes = {k.rsplit("_", 1)[0] for k in pending}
    chosen = [k for k in done if k.rsplit("_", 1)[0] in prefixes][:n]
    if len(chosen) < n:
        rest = [k for k in done if k not in chosen]
        step = max(1, len(rest) // max(1, n - len(chosen)))
        chosen += rest[::step][: n - len(chosen)]
    return [{"key": k, "english": en.get(k), "translation": po.get(k)} for k in chosen]


# --------------------------------------------------------------------------- pipeline


@dataclass
class Item:
    key: str
    source: str
    context: str
    reason: str
    old: str | None
    translation: str = ""
    translator_note: str = ""
    back_translation: str = ""
    verdict: str = ""
    confidence: float | None = None
    scores: dict = field(default_factory=dict)
    reviewer_note: str = ""
    hard_issues: list[str] = field(default_factory=list)
    soft_issues: list[str] = field(default_factory=list)
    status: str = "pending"  # passed | fixed | flagged | rejected | failed
    final: str = ""


@dataclass
class LocaleResult:
    code: str
    name: str
    rtl: bool
    items: list[Item]
    removed: list[str]
    error: str = ""

    def stats(self) -> dict:
        counts = {s: 0 for s in ("passed", "fixed", "flagged", "rejected", "failed")}
        for i in self.items:
            counts[i.status] = counts.get(i.status, 0) + 1
        confs = [i.confidence for i in self.items if i.confidence is not None]
        return {
            "translated": sum(1 for i in self.items if i.status in ("passed", "fixed", "flagged")),
            **counts,
            "removed": len(self.removed),
            "mean_confidence": round(sum(confs) / len(confs), 2) if confs else None,
            "min_confidence": round(min(confs), 2) if confs else None,
        }


def run_locale(code: str, en: PoFile, po: PoFile, work: Work, claude: Claude | None, args) -> LocaleResult:
    meta = meta_for(code)
    items = [Item(k, en.get(k) or "", en.comment(k), work.reasons[k], old) for k, old in work.translate.items()]
    result = LocaleResult(code, meta.name, meta.rtl, items, work.remove)
    if not items or claude is None:
        return result
    guide = load_guide(code)
    by_key = {i.key: i for i in items}

    # 1. translate
    examples = pick_examples(en, po, list(by_key), EXAMPLES)

    def translate(chunk: list[Item]) -> list[dict]:
        user = json.dumps({
            "instructions": f"Translate these {len(chunk)} strings into {meta.name}. "
                            "'context' is the developer's note about where the string appears. "
                            "The key hints at the screen and the role of the string (title, body, button).",
            "existing_translations_for_style": examples,
            "strings": [{"key": i.key, "source": i.source, "context": i.context} for i in chunk],
        }, ensure_ascii=False, indent=1)
        return claude.tool_call(MODELS["translate"], translator_system(meta, guide), user, TRANSLATE_TOOL).get("translations", [])

    def absorb(rows: list[dict]) -> None:
        for t in rows:
            it = by_key.get(t.get("key"))
            if it is not None and not it.translation:
                it.translation = str(t.get("text", "")).strip()
                it.translator_note = str(t.get("note", "")).strip()

    absorb(claude.batched(items, translate))
    missing = [i for i in items if not i.translation]
    if missing:
        log(f"{code}: retrying {len(missing)} strings the translator skipped")
        absorb(claude.batched(missing, translate))
    for i in items:
        if not i.translation:
            i.status, i.reviewer_note = "failed", "translator returned nothing for this key"

    live = [i for i in items if i.status == "pending"]
    for i in live:
        i.hard_issues, i.soft_issues = check(i.source, i.translation, meta)

    # 2. back-translate, 3. review
    if live and not args.skip_review:
        def back(chunk: list[Item]) -> list[dict]:
            user = json.dumps({"strings": [{"key": i.key, "text": i.translation} for i in chunk]},
                              ensure_ascii=False, indent=1)
            return claude.tool_call(MODELS["backtranslate"], back_system(meta), user, BACK_TOOL).get("items", [])

        for b in claude.batched(live, back):
            it = by_key.get(b.get("key"))
            if it is not None:
                it.back_translation = str(b.get("english", "")).strip()

        def review(chunk: list[Item]) -> list[dict]:
            user = json.dumps({"strings": [{
                "key": i.key, "source": i.source, "context": i.context, "translation": i.translation,
                "back_translation": i.back_translation, "check_notes": i.hard_issues + i.soft_issues,
            } for i in chunk]}, ensure_ascii=False, indent=1)
            return claude.tool_call(MODELS["review"], reviewer_system(meta, guide), user, REVIEW_TOOL).get("reviews", [])

        for r in claude.batched(live, review):
            it = by_key.get(r.get("key"))
            if it is None:
                continue
            it.verdict = str(r.get("verdict", "")).strip()
            try:
                it.confidence = max(0.0, min(1.0, float(r.get("confidence"))))
            except (TypeError, ValueError):
                it.confidence = None
            it.scores = r.get("scores") or {}
            it.reviewer_note = str(r.get("note", "")).strip()
            fix = str(r.get("fix", "")).strip()
            if it.verdict == "fix" and fix:
                if (it.confidence or 0) >= FIX_MIN_CONFIDENCE:
                    fh, fs = check(it.source, fix, meta)
                    if not fh:
                        it.final, it.hard_issues, it.soft_issues, it.status = fix, fh, fs, "fixed"
                        continue
                    it.reviewer_note = (it.reviewer_note + " Fix rejected by checks: " + "; ".join(fh)).strip()
                else:
                    it.reviewer_note = (it.reviewer_note + f" Suggested: {fix}").strip()

    # 4. decide
    for i in live:
        if i.status == "fixed":
            continue
        i.final = i.translation
        if i.hard_issues:
            i.status = "rejected"
        elif args.skip_review:
            i.status = "flagged" if i.soft_issues else "passed"
        elif i.verdict == "pass" and not i.soft_issues and (i.confidence or 0) >= LOW_CONFIDENCE:
            i.status = "passed"
        else:
            i.status = "flagged"
            if not i.verdict:
                i.reviewer_note = (i.reviewer_note + " Reviewer returned no verdict.").strip()
    return result


# --------------------------------------------------------------------------- reports


def text_table(headers: list[str], rows: list[list], align_right_from: int = 1) -> str:
    """Aligned plain-text table for the terminal."""
    cells = [[str(c) for c in r] for r in rows]
    widths = [max(len(h), *(len(r[i]) for r in cells)) if cells else len(h) for i, h in enumerate(headers)]

    def fmt(r):
        return "  ".join(c.rjust(widths[i]) if i >= align_right_from else c.ljust(widths[i]) for i, c in enumerate(r))

    return "\n".join([fmt(headers), "  ".join("-" * w for w in widths)] + [fmt(r) for r in cells])


def plan_table(work: dict, targets: dict) -> str:
    rows = [[code, len(targets[code].keys()), sum(1 for r in w.reasons.values() if r == "gap"),
             sum(1 for r in w.reasons.values() if r == "changed"), len(w.remove)] for code, w in work.items()]
    rows.append(["total", sum(r[1] for r in rows), sum(r[2] for r in rows), sum(r[3] for r in rows), sum(r[4] for r in rows)])
    return text_table(["Locale", "Entries", "To fill", "Changed", "To remove"], rows)


def result_table(results: list) -> str:
    rows = []
    for r in results:
        st = r.stats()
        rows.append([r.code, st["translated"], st["passed"], st["fixed"], st["flagged"], st["rejected"] + st["failed"],
                     st["removed"], fmt_conf(st["mean_confidence"]), fmt_conf(st["min_confidence"]), "FAILED" if r.error else "ok"])
    tot = [sum(r[i] for r in rows) for i in range(1, 7)]
    rows.append(["total", *tot, "", "", ""])
    return text_table(["Locale", "Written", "Passed", "Fixed", "Flagged", "Not written", "Removed", "Mean conf", "Lowest", "Status"], rows)


def esc_md(s: str) -> str:
    return (s or "").replace("|", "\\|").replace("\n", "\\n").replace("\r", "")


def fmt_conf(c: float | None) -> str:
    return "" if c is None else f"{c:.2f}"


def summary_markdown(results: list[LocaleResult], run: dict) -> str:
    lines = [f"## Translation run {run['timestamp']}", ""]
    lines.append(f"Mode: `{run['mode']}` · Base: `{run['base'] or 'none (gaps only)'}` · "
                 f"Translate: `{MODELS['translate']}` · Review: `{MODELS['review']}` · "
                 f"Back-translate: `{MODELS['backtranslate']}`")
    if run.get("run_url"):
        lines.append(f"Full HTML report: the `translation-report` artifact on [this run]({run['run_url']}).")
    lines.append("")
    if not any(r.items or r.removed for r in results):
        lines.append("Nothing to translate: every locale already covers en.po.")
        return "\n".join(lines) + "\n"
    lines += ["| Locale | Translated | Passed | Fixed | Flagged | Rejected | Failed | Removed | Mean conf | Lowest |",
              "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for r in results:
        s = r.stats()
        lines.append(f"| {r.code} ({r.name}) | {s['translated']} | {s['passed']} | {s['fixed']} | {s['flagged']} | "
                     f"{s['rejected']} | {s['failed']} | {s['removed']} | {fmt_conf(s['mean_confidence'])} | {fmt_conf(s['min_confidence'])} |")
    lines.append("")
    if run.get("usage"):
        lines.append("Tokens: " + "; ".join(f"{m}: in {u['input']:,} (+{u['cache_read']:,} cached), out {u['output']:,}"
                                            for m, u in run["usage"].items()))
        lines.append("")
    for r in results:
        if r.error:
            lines += [f"> **{r.code}: run failed** — {esc_md(r.error)}", ""]
        if not r.items:
            continue
        lines += [f"<details><summary>{r.code} — {len(r.items)} strings</summary>", "",
                  "| Key | English | Translation | Back-translation | Status | Conf | Notes |",
                  "|---|---|---|---|---|---:|---|"]
        for i in r.items:
            notes = "; ".join(filter(None, [i.reviewer_note, i.translator_note] + i.hard_issues + i.soft_issues))
            shown = esc_md(i.final or i.translation)
            if i.reason == "changed" and i.old:
                shown = f"~~{esc_md(i.old)}~~ {shown}"
            lines.append(f"| `{i.key}` | {esc_md(i.source)} | {shown} | {esc_md(i.back_translation)} | "
                         f"{i.status} | {fmt_conf(i.confidence)} | {esc_md(notes)} |")
        lines += ["", "</details>", ""]
    return "\n".join(lines) + "\n"


def commit_message(results: list[LocaleResult], run: dict) -> str:
    total = sum(r.stats()["translated"] for r in results)
    removed = sum(len(r.removed) for r in results)
    locales = [r for r in results if r.items or r.removed]
    head = f"Translate {total} strings into {len(locales)} locales"
    if removed:
        head += f", remove {removed} stale entries"
    body = [f"{r.code}: {r.stats()['translated']} translated"
            + (f", {r.stats()['flagged']} flagged" if r.stats()['flagged'] else "")
            + (f", {r.stats()['rejected'] + r.stats()['failed']} not written" if r.stats()['rejected'] + r.stats()['failed'] else "")
            + (f", {len(r.removed)} removed" if r.removed else "")
            for r in locales]
    if run.get("run_url"):
        body += ["", f"Report: {run['run_url']}"]
    return head + "\n\n" + "\n".join(body) + "\n"


def html_report(results: list[LocaleResult], run: dict) -> str:
    data = {"run": run, "models": MODELS, "locales": [
        {"code": r.code, "name": r.name, "rtl": r.rtl, "removed": r.removed, "error": r.error,
         "stats": r.stats(), "items": [asdict(i) for i in r.items]} for r in results]}
    payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    return HTML_TEMPLATE.replace("__DATA__", payload)


# --------------------------------------------------------------------------- audit


def source_literals(dirs: list[Path]) -> tuple[set[str], list[tuple[str, str]]]:
    """All quoted snake_case literals in the Dart sources, plus the static parts
    around any string interpolation (prefix, suffix), which mark dynamic keys."""
    literals: set[str] = set()
    dynamic: set[tuple[str, str]] = set()
    for d in dirs:
        for p in d.rglob("*.dart"):
            if "generated" in p.name or p.name.endswith((".g.dart", ".freezed.dart")):
                continue
            src = p.read_text(encoding="utf-8", errors="ignore")
            # quote-bounded tokens; lookarounds so a key nested in an interpolation still counts
            literals.update(re.findall(r"""(?<=['"])([^'"\\\n]+)(?=['"])""", src))
            for pre, suf in re.findall(r"""['"]([a-z0-9_]*)\$\{[^}]*\}([a-z0-9_]*)['"]""", src):
                if pre or suf:
                    dynamic.add((pre, suf))
    return literals, sorted(dynamic)


def dynamically_referenced(key: str, dynamic: list[tuple[str, str]], prefixes: list[str]) -> bool:
    if any(key.startswith(p) for p in prefixes):
        return True
    return any(key.startswith(pre) and key.endswith(suf) and len(pre) + len(suf) < len(key)
               for pre, suf in dynamic)


def i18n_literals(dirs: list[Path]) -> set[str]:
    out: set[str] = set()
    for d in dirs:
        for p in d.rglob("*.dart"):
            src = p.read_text(encoding="utf-8", errors="ignore")
            for m in re.findall(r"""['"]([^'"\\\n]+)['"]\s*\.i18n\b""", src):
                if "$" not in m:
                    out.add(m)
    return out


def audit_report(en: PoFile, targets: dict[str, PoFile]) -> str:
    dirs = [ROOT / d for d in AUDIT_SOURCE_DIRS]
    lines = ["# Localization audit", ""]

    literals, dynamic = source_literals(dirs)
    candidates = [k for k in en.keys() if k not in literals
                  and not dynamically_referenced(k, dynamic, AUDIT_DYNAMIC_PREFIXES)]
    hits = code_references(candidates, dirs)
    unreferenced = [k for k in candidates if k not in hits]
    lines += [f"## Keys in en.po with no reference in {', '.join(AUDIT_SOURCE_DIRS)} ({len(unreferenced)})", ""]
    lines += ["Two checks agree: no quoted literal and no word match in the raw text of "
              + ", ".join(AUDIT_SOURCE_DIRS) + ". `--cleanup` removes exactly these. "
              "Dynamic key families from string interpolation are excluded: "
              + (", ".join(f"`{p}…{s}`" for p, s in dynamic) or "none")
              + (". Extra prefixes from config: " + ", ".join(f"`{p}`" for p in AUDIT_DYNAMIC_PREFIXES) if AUDIT_DYNAMIC_PREFIXES else "")
              + ".", ""]
    if hits:
        lines += ["Kept because the word still appears in the code: "
                  + ", ".join(f"`{k}` ({f})" for k, f in sorted(hits.items())), ""]
    groups: dict[str, list[str]] = {}
    for k in unreferenced:
        groups.setdefault(k.split("_")[0], []).append(k)
    for g, ks in sorted(groups.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        lines.append(f"- **{g}** ({len(ks)}): " + ", ".join(f"`{k}`" for k in ks))
    if not unreferenced:
        lines.append("- none")
    lines.append("")

    missing = sorted(k for k in i18n_literals(dirs) if not en.has(k))
    lines += [f"## Keys used with .i18n in code but missing from en.po ({len(missing)})", ""]
    lines += ["These render as the raw key in the app. A renamed key usually shows up here and in the list above.", ""]
    lines += [f"- `{k}`" for k in missing] or ["- none"]
    lines.append("")

    lines += ["## Per-locale state", "", "| Locale | Entries | Missing or empty | Stale (not in en.po) |", "|---|---:|---:|---:|"]
    for code, po in targets.items():
        gaps = sum(1 for k in en.keys() if en.get(k) and not po.get(k))
        stale = sum(1 for k in po.keys() if not en.has(k))
        lines.append(f"| {code} | {len(po.keys())} | {gaps} | {stale} |")
    lines.append("")
    return "\n".join(lines) + "\n"


# --------------------------------------------------------------------------- cleanup

SCAN_SUFFIXES = {".dart", ".yaml", ".json", ".arb"}


def code_references(keys: list[str], dirs: list[Path]) -> dict[str, str]:
    """Second layer: word-boundary search for each key in the raw text of the source
    dirs, so a key inside a longer string or an identifier still counts.
    Returns key -> first file that mentions it, relative to the repo root."""
    if not keys:
        return {}
    pattern = re.compile(r"(?<![A-Za-z0-9_])(" + "|".join(re.escape(k) for k in keys) + r")(?![A-Za-z0-9_])")
    found: dict[str, str] = {}
    for d in dirs:
        for p in d.rglob("*"):
            if not p.is_file() or p.suffix not in SCAN_SUFFIXES:
                continue
            text = p.read_text(encoding="utf-8", errors="ignore")
            for m in pattern.finditer(text):
                found.setdefault(m.group(1), str(p.relative_to(ROOT) if p.is_relative_to(ROOT) else p))
            if len(found) == len(keys):
                return found
    return found


def ensure_charset(po: PoFile) -> bool:
    """msgfmt refuses a file whose header has no charset; add the standard UTF-8 line."""
    hdr = po.get("")
    if hdr is None or "charset=" in hdr:
        return False
    po.set("", hdr + "Content-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: 8bit\n")
    return True


def cleanup(en: PoFile, targets: dict[str, PoFile], dry_run: bool) -> str:
    """Remove en.po keys that nothing in the source dirs references (two independent
    checks must agree), then prune every locale. Returns a plain-text report."""
    dirs = [ROOT / d for d in AUDIT_SOURCE_DIRS]
    literals, dynamic = source_literals(dirs)
    candidates = [k for k in en.keys() if k not in literals
                  and not dynamically_referenced(k, dynamic, AUDIT_DYNAMIC_PREFIXES)]
    hits = code_references(candidates, dirs)
    dead = [k for k in candidates if k not in hits]
    kept = [(k, hits[k]) for k in candidates if k in hits]

    out = [f"Layer 1 (literal scan of {', '.join(AUDIT_SOURCE_DIRS)}): {len(candidates)} keys with no reference",
           f"Layer 2 (word search in the raw text of {', '.join(AUDIT_SOURCE_DIRS)}): {len(kept)} still appear and are kept",
           f"Removing {len(dead)} keys from en.po" + (" (dry run)" if dry_run else ""), ""]
    if kept:
        out += [text_table(["Kept key", "Referenced in"], [[k, f] for k, f in kept]), ""]
    if dead:
        out += [text_table(["Removed key", "English"], [[k, (en.get(k) or "")[:60]] for k in dead]), ""]
    if not dry_run:
        for k in dead:
            en.remove(k)
        if dead:
            en.write()
            validate_po(en.path, len(en.keys()))
    rows = []
    for code, po in targets.items():
        stale = [k for k in po.keys() if not en.has(k)]
        if dry_run:
            rows.append([code, len(stale)])
            continue
        changed = ensure_charset(po)
        for k in stale:
            po.remove(k)
            changed = True
        if changed:
            po.write()
            validate_po(po.path, len(po.keys()))
        rows.append([code, len(stale)])
    rows.append(["total", sum(r[1] for r in rows)])
    out += ["Stale entries removed per locale" + (" (dry run)" if dry_run else ""), text_table(["Locale", "Removed"], rows)]
    return "\n".join(out) + "\n"


# --------------------------------------------------------------------------- main


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", default="", help="commit to diff en.po against for changed strings")
    ap.add_argument("--locales", default="", help="comma-separated locale codes; default all")
    ap.add_argument("--limit", type=int, default=0, help="cap strings per locale (for test runs)")
    ap.add_argument("--dry-run", action="store_true", help="write reports only, leave .po files untouched")
    ap.add_argument("--skip-review", action="store_true", help="skip back-translation and review (cheap test)")
    ap.add_argument("--out", default=str(ROOT / "build" / "translate"), help="report directory")
    ap.add_argument("--config", default=str(CONFIG_PATH), help="settings file (models, thresholds, glossary, locales)")
    ap.add_argument("--plan", action="store_true",
                    help="show per-locale counts of what a run would translate and remove, then exit; no API calls")
    ap.add_argument("--prune", action="store_true",
                    help="only remove locale entries whose key left en.po, then exit; no API calls")
    ap.add_argument("--cleanup", action="store_true",
                    help="remove en.po keys nothing in lib references (two independent checks) and prune every locale; no API calls")
    ap.add_argument("--audit", action="store_true",
                    help="report unreferenced en.po keys, keys missing from en.po, and per-locale gaps; no API calls")
    args = ap.parse_args()

    if Path(args.config) != CONFIG_PATH:
        load_config(Path(args.config))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    en = PoFile(LOCALES_DIR / f"{SOURCE}.po")
    wanted = {c.strip() for c in args.locales.split(",") if c.strip()}
    targets = {p.stem: PoFile(p) for p in sorted(LOCALES_DIR.glob("*.po"))
               if p.stem != SOURCE and (not wanted or p.stem in wanted)}
    unknown = wanted - set(targets)
    if unknown:
        log(f"error: no .po file for {', '.join(sorted(unknown))}")
        return 1

    if args.audit:
        report = audit_report(en, targets)
        (out / "audit.md").write_text(report, encoding="utf-8")
        print(report)
        return 0

    work = detect(en, targets, args.base, args.limit)
    pending = sum(len(w.translate) for w in work.values())
    removals = sum(len(w.remove) for w in work.values())
    log(f"{pending} strings to translate, {removals} stale entries to remove across {len(targets)} locales")
    if args.plan:
        print(plan_table(work, targets))
        return 0
    if args.cleanup:
        report = cleanup(en, targets, args.dry_run)
        (out / "cleanup.txt").write_text(report, encoding="utf-8")
        print(report)
        return 0
    if args.prune:
        rows = []
        for code, w in work.items():
            if not w.remove:
                continue
            po = targets[code]
            for k in w.remove:
                po.remove(k)
            po.write()
            validate_po(po.path, len(po.keys()))
            rows.append([code, len(w.remove)])
        print(text_table(["Locale", "Removed"], rows) if rows else "Nothing stale to remove.")
        return 0
    if pending and not os.environ.get("ANTHROPIC_API_KEY"):
        log("error: ANTHROPIC_API_KEY is not set")
        return 1
    claude = Claude() if pending else None

    def one(code: str) -> LocaleResult:
        try:
            return run_locale(code, en, targets[code], work[code], claude, args)
        except Exception as e:  # keep the other locales going, surface this one in the report
            log(f"{code}: failed: {e}")
            meta = meta_for(code)
            return LocaleResult(code, meta.name, meta.rtl, [], work[code].remove, error=f"{type(e).__name__}: {e}")

    results: list[LocaleResult] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=WORKERS) as pool:
        for r in pool.map(one, list(targets)):
            results.append(r)
            s = r.stats()
            log(f"  {r.code:<8} done: {s['translated']:>4} written, {s['flagged']:>3} flagged, "
                f"{s['rejected'] + s['failed']:>3} not written, {s['removed']:>3} removed"
                + (f"  FAILED: {r.error}" if r.error else ""))

    written = 0
    if not args.dry_run:
        for r in results:
            po = targets[r.code]
            changed = ensure_charset(po)
            for k in r.removed:
                po.remove(k)
                changed = True
            for i in r.items:
                if i.status in ("passed", "fixed", "flagged") and i.final:
                    po.set(i.key, i.final)
                    changed = True
            if changed:
                po.write()
                validate_po(po.path, len(po.keys()))
                written += 1
        log(f"wrote {written} locale files")

    run = {
        "timestamp": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        "mode": "dry-run" if args.dry_run else "translate",
        "base": args.base,
        "usage": claude.usage if claude else {},
        "run_url": (f"{os.environ['GITHUB_SERVER_URL']}/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}"
                    if os.environ.get("GITHUB_RUN_ID") else ""),
    }
    (out / "results.json").write_text(json.dumps(
        {"run": run, "models": MODELS, "locales": [{**asdict(r), "stats": r.stats()} for r in results]},
        ensure_ascii=False, indent=1), encoding="utf-8")
    summary = summary_markdown(results, run)
    (out / "summary.md").write_text(summary, encoding="utf-8")
    (out / "commit_message.txt").write_text(commit_message(results, run), encoding="utf-8")
    (out / "report.html").write_text(html_report(results, run), encoding="utf-8")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as f:
            f.write(summary)

    flagged = sum(r.stats()["flagged"] + r.stats()["rejected"] + r.stats()["failed"] for r in results)
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as f:
            f.write(f"changed={'true' if written else 'false'}\nflagged={flagged}\n"
                    f"translated={sum(r.stats()['translated'] for r in results)}\n")
    print()
    print(result_table(results))
    print()
    print(f"{'Dry run: no locale files changed' if args.dry_run else f'{written} locale files written'}. "
          f"Reports: {out}/report.html, summary.md, results.json")
    return 1 if any(r.error for r in results) else 0


# --------------------------------------------------------------------------- HTML report

HTML_TEMPLATE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Translation report</title>
<style>
  :root { --bg:#fff; --fg:#1f2328; --muted:#656d76; --line:#d0d7de; --row:#f6f8fa; --pass:#1a7f37; --fix:#0969da; --flag:#9a6700; --bad:#cf222e; }
  @media (prefers-color-scheme: dark) { :root { --bg:#0d1117; --fg:#e6edf3; --muted:#8d96a0; --line:#30363d; --row:#161b22; --pass:#3fb950; --fix:#58a6ff; --flag:#d29922; --bad:#f85149; } }
  body { margin:0; padding:16px; font:14px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; background:var(--bg); color:var(--fg); }
  h1 { font-size:20px; margin:0 0 4px; } .meta { color:var(--muted); margin-bottom:12px; }
  .controls { display:flex; flex-wrap:wrap; gap:10px; align-items:center; margin:12px 0; }
  .controls label { display:flex; gap:4px; align-items:center; }
  input[type=text], select { padding:4px 6px; border:1px solid var(--line); border-radius:6px; background:var(--bg); color:var(--fg); }
  table { border-collapse:collapse; width:100%; }
  th, td { border-bottom:1px solid var(--line); padding:6px 8px; vertical-align:top; text-align:left; }
  th { position:sticky; top:0; background:var(--bg); cursor:pointer; white-space:nowrap; user-select:none; }
  tbody tr:nth-child(odd) { background:var(--row); }
  td.k { font-family:ui-monospace, SFMono-Regular, Menlo, monospace; font-size:12px; white-space:nowrap; }
  td.t { max-width:320px; } td.n { color:var(--muted); font-size:12px; max-width:280px; }
  .old { text-decoration:line-through; color:var(--muted); display:block; }
  .s { font-weight:600; } .passed{color:var(--pass)} .fixed{color:var(--fix)} .flagged{color:var(--flag)} .rejected,.failed{color:var(--bad)}
  .stats { display:grid; grid-template-columns:repeat(auto-fill, minmax(190px,1fr)); gap:8px; margin-bottom:8px; }
  .card { border:1px solid var(--line); border-radius:8px; padding:8px 10px; } .card b { display:block; } .card small { color:var(--muted); display:block; }
  .bar { height:4px; background:var(--line); border-radius:2px; margin-top:6px; overflow:hidden; } .bar i { display:block; height:100%; background:var(--pass); }
  .err { color:var(--bad); }
</style>
</head>
<body>
<h1>Translation report</h1>
<div class="meta" id="meta"></div>
<div class="stats" id="stats"></div>
<div class="controls">
  <label>Locale <select id="locale"><option value="">all</option></select></label>
  <label>Status <select id="status"><option value="">all</option><option>passed</option><option>fixed</option><option>flagged</option><option>rejected</option><option>failed</option></select></label>
  <label>Max confidence <input type="range" id="conf" min="0" max="1" step="0.05" value="1"> <span id="confv">1.00</span></label>
  <label>Search <input type="text" id="q" placeholder="key, English, translation, note"></label>
  <span id="count" class="meta"></span>
</div>
<table>
  <thead><tr>
    <th data-k="locale">Locale</th><th data-k="key">Key</th><th data-k="source">English</th><th data-k="final">Translation</th>
    <th data-k="back_translation">Back-translation</th><th data-k="status">Status</th><th data-k="confidence">Conf</th><th data-k="scores">Scores</th><th data-k="notes">Notes</th>
  </tr></thead>
  <tbody id="rows"></tbody>
</table>
<script id="data" type="application/json">__DATA__</script>
<script>
const data = JSON.parse(document.getElementById('data').textContent);
const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const rows = [];
for (const L of data.locales) for (const it of L.items) rows.push({
  locale: L.code, rtl: L.rtl, ...it, final: it.final || it.translation,
  notes: [it.reviewer_note, it.translator_note, ...(it.hard_issues||[]), ...(it.soft_issues||[])].filter(Boolean).join(' · '),
  scoreText: it.scores && Object.keys(it.scores).length ? Object.entries(it.scores).map(([k,v]) => k.slice(0,3)+' '+v).join(' ') : ''
});
const r = data.run, m = data.models;
document.getElementById('meta').textContent =
  `${r.timestamp} · mode ${r.mode} · base ${r.base || 'none (gaps only)'} · translate ${m.translate} · review ${m.review} · back-translate ${m.backtranslate}`;
const stats = document.getElementById('stats');
for (const L of data.locales) {
  const s = L.stats, n = L.items.length || 1;
  stats.insertAdjacentHTML('beforeend', `<div class="card"><b>${esc(L.code)} <small>${esc(L.name)}</small></b>
    <small>${s.translated} translated · ${s.passed} passed · ${s.fixed} fixed · ${s.flagged} flagged · ${s.rejected + s.failed} not written · ${s.removed} removed</small>
    <small>${s.mean_confidence != null ? `confidence mean ${s.mean_confidence.toFixed(2)}, lowest ${s.min_confidence.toFixed(2)}` : ''}</small>
    ${L.error ? `<div class="err">${esc(L.error)}</div>` : ''}
    <div class="bar"><i style="width:${100*(s.passed+s.fixed)/n}%"></i></div></div>`);
  document.getElementById('locale').insertAdjacentHTML('beforeend', `<option>${esc(L.code)}</option>`);
}
let sortKey = 'locale', sortDir = 1;
const $ = id => document.getElementById(id);
function render() {
  const loc = $('locale').value, st = $('status').value, maxc = parseFloat($('conf').value), q = $('q').value.toLowerCase();
  $('confv').textContent = maxc.toFixed(2);
  let out = rows.filter(x => (!loc || x.locale === loc) && (!st || x.status === st)
    && (x.confidence == null || x.confidence <= maxc)
    && (!q || [x.key, x.source, x.final, x.back_translation, x.notes].join(' ').toLowerCase().includes(q)));
  out.sort((a, b) => {
    let va = a[sortKey], vb = b[sortKey];
    if (sortKey === 'scores') { va = a.scoreText; vb = b.scoreText; }
    if (va == null) return 1; if (vb == null) return -1;
    return (va > vb ? 1 : va < vb ? -1 : 0) * sortDir;
  });
  $('count').textContent = `${out.length} of ${rows.length} strings`;
  $('rows').innerHTML = out.map(x => `<tr>
    <td>${esc(x.locale)}</td><td class="k">${esc(x.key)}</td><td class="t">${esc(x.source)}</td>
    <td class="t" ${x.rtl ? 'dir="rtl"' : ''}>${x.reason === 'changed' && x.old ? `<span class="old">${esc(x.old)}</span>` : ''}${esc(x.final)}</td>
    <td class="t">${esc(x.back_translation)}</td>
    <td class="s ${x.status}">${esc(x.status)}</td><td>${x.confidence == null ? '' : x.confidence.toFixed(2)}</td>
    <td class="n">${esc(x.scoreText)}</td><td class="n">${esc(x.notes)}</td></tr>`).join('');
}
for (const id of ['locale', 'status', 'conf', 'q']) $(id).addEventListener('input', render);
document.querySelectorAll('th').forEach(th => th.addEventListener('click', () => {
  const k = th.dataset.k; sortDir = sortKey === k ? -sortDir : 1; sortKey = k; render();
}));
render();
</script>
</body>
</html>
"""


if __name__ == "__main__":
    sys.exit(main())
