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
EFFORT: dict[str, str] = {}
BATCH_OUTPUTS = WORKERS = MAX_TOKENS = EXAMPLES = 0
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
    g["EFFORT"] = dict(d.get("effort", {}))
    run = d.get("run", {})
    g["BATCH_OUTPUTS"] = int(run.get("batch_outputs", 120))
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


def _guide_sections() -> dict[str, str]:
    sections: dict[str, list[str]] = {}
    current = None
    for line in GUIDES.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^## (\S+)", line)
        if m:
            current = m.group(1)
            sections[current] = []
        elif current:
            sections[current].append(line)
    return {k: "\n".join(v).strip() for k, v in sections.items()}


def guide_common() -> str:
    return _guide_sections().get("common", "")


def guide_locale(code: str) -> str:
    own = _guide_sections().get(code, "")
    if not own:
        log(f"warning: guides.md has no '## {code}' section")
    return own


def load_guide(code: str) -> str:
    """The 'common' section of guides.md followed by the locale's own section."""
    return f"{guide_common()}\n\n{guide_locale(code)}".strip()


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

    def tool_call(self, role: str, system: str, user: str, tool: dict, cached: bool = True) -> dict:
        """One structured-output request; `tool` supplies the JSON schema the reply must match.
        Caching the system prompt costs 25% extra on the write, so it is only on when the
        same prompt is reused by another call in this run."""
        model = MODELS[role]
        block = {"type": "text", "text": system}
        if cached:
            block["cache_control"] = {"type": "ephemeral"}
        resp = self.client.messages.create(
            model=model,
            max_tokens=MAX_TOKENS,
            system=[block],
            output_config={
                "effort": EFFORT.get(role, "medium"),
                "format": {"type": "json_schema", "schema": tool["input_schema"]},
            },
            messages=[{"role": "user", "content": user}],
        )
        self._account(model, resp.usage)
        if resp.stop_reason == "max_tokens":
            raise TruncatedResponse(model)
        if resp.stop_reason == "refusal":
            detail = getattr(resp, "stop_details", None)
            raise RuntimeError(f"{model} declined the request ({getattr(detail, 'category', 'unknown')})")
        text = next((b.text for b in resp.content if b.type == "text"), "")
        try:
            return json.loads(text)
        except json.JSONDecodeError as e:
            raise RuntimeError(f"{model} returned invalid JSON: {e}") from e

    def batched(self, items: list, fn) -> list:
        """Run fn on chunks of items, halving a chunk that overflows max_tokens."""
        results = []
        queue = [list(items)]
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
                "type": "object", "properties": item, "required": required, "additionalProperties": False}}},
            "required": [list_key],
            "additionalProperties": False,
        },
    }


TRANSLATE_TOOL = _tool(
    "submit_translations", "Submit the final UI translations, one entry per locale and key.",
    {"locale": {"type": "string"}, "key": {"type": "string"},
     "text": {"type": "string", "description": "The translated UI string only."},
     "note": {"type": "string", "description": "One short sentence when a choice was not obvious, else empty."}},
    ["locale", "key", "text", "note"], "translations")

BACK_TOOL = _tool(
    "submit_back_translations", "Submit a literal English rendering of each string.",
    {"locale": {"type": "string"}, "key": {"type": "string"}, "english": {"type": "string"}},
    ["locale", "key", "english"], "items")

SCORE = {"type": "integer", "description": "1 to 5"}
REVIEW_TOOL = _tool(
    "submit_review", "Submit the review verdict for every string.",
    {"locale": {"type": "string"}, "key": {"type": "string"},
     "verdict": {"type": "string", "enum": ["pass", "fix", "flag"]},
     "confidence": {"type": "number", "description": "0 to 1"},
     "fix": {"type": "string", "description": "Corrected UI string when verdict is fix, else empty."},
     "note": {"type": "string", "description": "One sentence, empty on a clean pass."},
     "scores": {"type": "object",
                "properties": {k: SCORE for k in ("accuracy", "naturalness", "register", "terminology", "ui_fit")},
                "required": ["accuracy", "naturalness", "register", "terminology", "ui_fit"],
                "additionalProperties": False}},
    ["locale", "key", "verdict", "confidence", "fix", "note", "scores"], "reviews")


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


@dataclass
class Batch:
    """One model call's worth of work: these keys, into these locales."""
    locales: tuple[str, ...]
    keys: list[str]
    cached: bool  # the group has several batches, so caching the system prompt pays off


def plan_batches(work: dict[str, Work]) -> list[Batch]:
    """Group pending keys by the exact set of locales that need them, then split each
    group so one call returns at most BATCH_OUTPUTS translations."""
    by_key: dict[str, set[str]] = {}
    for code, w in work.items():
        for k in w.translate:
            by_key.setdefault(k, set()).add(code)
    groups: dict[tuple[str, ...], list[str]] = {}
    for k, codes in by_key.items():
        groups.setdefault(tuple(sorted(codes)), []).append(k)
    batches = []
    for locales, keys in groups.items():
        per_call = max(1, BATCH_OUTPUTS // len(locales))
        chunks = [keys[i:i + per_call] for i in range(0, len(keys), per_call)]
        for chunk in chunks:
            batches.append(Batch(locales, chunk, cached=len(chunks) > 1))
    return batches


def locale_block(codes: tuple[str, ...]) -> str:
    """Shared guide once, then each locale's own section."""
    parts = [guide_common()]
    for c in codes:
        parts.append(f"### {meta_for(c).name} ({c})\n\n{guide_locale(c)}")
    aliases = [f"{c}: {', '.join(f'{k} is written {v}' for k, v in ALIASES[c].items())}" for c in codes if c in ALIASES]
    glossary = "Keep these product and platform names exactly as written, in Latin script: " + ", ".join(KEEP)
    if aliases:
        glossary += ". Locale exceptions: " + "; ".join(aliases)
    return "\n\n".join(parts) + "\n\n" + glossary


def translator_system(codes: tuple[str, ...]) -> str:
    names = ", ".join(f"{meta_for(c).name} ({c})" for c in codes)
    return f"""You are the localization lead for Lantern, a VPN and censorship-circumvention app. You translate its user interface from English into: {names}.

{locale_block(codes)}

Output rules:
- Reply with one JSON object matching the schema: a "translations" array with exactly one entry per (locale, key) pair you were given, {len(codes)} entries per key.
- "text" is the final UI string and nothing else: no quotes around it, no explanations, no alternatives.
- "note" is one short English sentence only when you made a choice a reviewer should know about; otherwise an empty string."""


def back_system(codes: tuple[str, ...]) -> str:
    names = ", ".join(f"{meta_for(c).name} ({c})" for c in codes)
    return f"""You render app UI strings back into literal English so a reviewer who does not read the language can judge their meaning. Each item names its locale; the languages are: {names}.
Translate what the text actually says, including any awkwardness or errors. Do not improve it, do not guess the intended meaning, keep placeholders like %s and %d and \\n where they appear.
Reply with one JSON object matching the schema: an "items" array with one entry per (locale, key) pair."""


def reviewer_system(codes: tuple[str, ...]) -> str:
    names = ", ".join(f"{meta_for(c).name} ({c})" for c in codes)
    return f"""You are an independent senior localization reviewer for Lantern, a VPN and censorship-circumvention app, covering: {names}. You did not write these translations. Judge each one against the style guide for its locale below.

{locale_block(codes)}

For each item you get the locale, the English source, developer context, the translation, a literal back-translation produced by a model that did not see the English, and any automated check notes.

Verdicts:
- pass: ship as is.
- fix: there is a real problem and you supply the corrected UI string in "fix". Keep placeholders identical in count and order.
- flag: a problem you cannot fix confidently, or a judgment call that should be visible in the report.

"confidence" (0 to 1) is how sure you are that the final string (your fix when verdict is fix, otherwise the translation) is correct, natural, and right for the UI.
Score accuracy, naturalness, register, terminology, and ui_fit from 1 to 5.
Be strict about meaning, placeholders, register, and script. Do not rewrite acceptable translations for taste alone.
Reply with one JSON object matching the schema: a "reviews" array with one entry per (locale, key) pair."""


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


def run_batch(batch: Batch, en: PoFile, targets: dict[str, PoFile], items: dict[tuple[str, str], Item],
              claude: Claude, args) -> None:
    """Translate, back-translate and review one batch; results land on the shared Item objects."""
    codes = batch.locales
    mine = {(c, k): items[(c, k)] for c in codes for k in batch.keys}
    strings = [{"key": k, "source": en.get(k) or "", "context": en.comment(k)} for k in batch.keys]
    locales = [{"code": c, "name": meta_for(c).name,
                "existing_translations_for_style": pick_examples(en, targets[c], batch.keys, EXAMPLES)} for c in codes]

    def translate(keys: list[str]) -> list[dict]:
        user = json.dumps({
            "instructions": f"Translate each string into every locale listed, {len(codes)} translations per key. "
                            "'context' is the developer's note about where the string appears; the key hints at the screen and role.",
            "locales": locales,
            "strings": [s for s in strings if s["key"] in keys],
        }, ensure_ascii=False, indent=1)
        return claude.tool_call("translate", translator_system(codes), user, TRANSLATE_TOOL, batch.cached).get("translations", [])

    def absorb(rows: list[dict]) -> None:
        for t in rows:
            it = mine.get((t.get("locale"), t.get("key")))
            if it is not None and not it.translation:
                it.translation = str(t.get("text", "")).strip()
                it.translator_note = str(t.get("note", "")).strip()

    need = sorted({k for (c, k), it in mine.items() if not it.translation})
    if need:
        absorb(claude.batched(need, translate))
    missing_keys = sorted({k for (c, k), it in mine.items() if not it.translation})
    if missing_keys:
        log(f"retrying {len(missing_keys)} keys the translator skipped for {len(codes)} locales")
        absorb(claude.batched(missing_keys, translate))
    for it in mine.values():
        if not it.translation:
            it.status, it.reviewer_note = "failed", "translator returned nothing for this key"
    live = [(c, k) for (c, k), it in mine.items() if it.status == "pending"]
    for c, k in live:
        it = mine[(c, k)]
        it.hard_issues, it.soft_issues = check(it.source, it.translation, meta_for(c))
    if not live or args.skip_review:
        return

    def back(pairs: list[tuple[str, str]]) -> list[dict]:
        user = json.dumps({"strings": [{"locale": c, "key": k, "text": mine[(c, k)].translation} for c, k in pairs]},
                          ensure_ascii=False, indent=1)
        return claude.tool_call("backtranslate", back_system(codes), user, BACK_TOOL, False).get("items", [])

    need_back = [(c, k) for c, k in live if not mine[(c, k)].back_translation]
    for b in (claude.batched(need_back, back) if need_back else []):
        it = mine.get((b.get("locale"), b.get("key")))
        if it is not None:
            it.back_translation = str(b.get("english", "")).strip()

    def review(pairs: list[tuple[str, str]]) -> list[dict]:
        user = json.dumps({"strings": [{
            "locale": c, "key": k, "source": mine[(c, k)].source, "context": mine[(c, k)].context,
            "translation": mine[(c, k)].translation, "back_translation": mine[(c, k)].back_translation,
            "check_notes": mine[(c, k)].hard_issues + mine[(c, k)].soft_issues,
        } for c, k in pairs]}, ensure_ascii=False, indent=1)
        return claude.tool_call("review", reviewer_system(codes), user, REVIEW_TOOL, batch.cached).get("reviews", [])

    for r in claude.batched(live, review):
        it = mine.get((r.get("locale"), r.get("key")))
        if it is None:
            continue
        it.verdict = str(r.get("verdict", "")).strip()
        try:
            it.confidence = max(0.0, min(1.0, float(r.get("confidence"))))
        except (TypeError, ValueError):
            it.confidence = None
        it.scores = {k: max(1, min(5, int(v))) for k, v in (r.get("scores") or {}).items() if isinstance(v, (int, float))}
        it.reviewer_note = str(r.get("note", "")).strip()
        fix = str(r.get("fix", "")).strip()
        if it.verdict == "fix" and fix:
            if (it.confidence or 0) >= FIX_MIN_CONFIDENCE:
                fh, fs = check(it.source, fix, meta_for(r.get("locale")))
                if not fh:
                    it.final, it.hard_issues, it.soft_issues, it.status = fix, fh, fs, "fixed"
                    continue
                it.reviewer_note = (it.reviewer_note + " Fix rejected by checks: " + "; ".join(fh)).strip()
            else:
                it.reviewer_note = (it.reviewer_note + f" Suggested: {fix}").strip()


def decide(it: Item, skip_review: bool) -> None:
    if it.status != "pending":
        return
    it.final = it.translation
    if it.hard_issues:
        it.status = "rejected"
    elif skip_review:
        it.status = "flagged" if it.soft_issues else "passed"
    elif it.verdict == "pass" and not it.soft_issues and (it.confidence or 0) >= LOW_CONFIDENCE:
        it.status = "passed"
    else:
        it.status = "flagged"
        if not it.verdict:
            it.reviewer_note = (it.reviewer_note + " Reviewer returned no verdict.").strip()


def load_previous(path: Path, items: dict[tuple[str, str], Item]) -> int:
    """Carry translations and back-translations over from an earlier results.json so a
    rerun only pays for the stages that did not finish."""
    d = json.loads(path.read_text(encoding="utf-8"))
    n = 0
    for L in d.get("locales", []):
        for prev in L.get("items", []):
            it = items.get((L["code"], prev["key"]))
            if it is None or it.source != prev.get("source") or not prev.get("translation"):
                continue
            it.translation = prev["translation"]
            it.translator_note = prev.get("translator_note", "")
            it.back_translation = prev.get("back_translation", "")
            n += 1
    return n


def run_all(work: dict[str, Work], en: PoFile, targets: dict[str, PoFile], claude: Claude | None, args) -> list[LocaleResult]:
    items: dict[tuple[str, str], Item] = {
        (c, k): Item(k, en.get(k) or "", en.comment(k), w.reasons[k], old)
        for c, w in work.items() for k, old in w.translate.items()
    }
    if getattr(args, "resume", ""):
        log(f"resumed {load_previous(Path(args.resume), items)} translations from {args.resume}")
    errors: dict[str, str] = {}
    if claude is not None and items:
        batches = plan_batches(work)
        log(f"{len(batches)} model call groups ({', '.join(f'{len(b.keys)} keys x {len(b.locales)} locales' for b in batches[:6])}"
            + (", ..." if len(batches) > 6 else ")"))

        def one(b: Batch) -> None:
            try:
                run_batch(b, en, targets, items, claude, args)
            except Exception as e:  # keep the other batches going, surface this one in the report
                log(f"batch {len(b.keys)}x{len(b.locales)} failed: {e}")
                for c in b.locales:
                    errors[c] = f"{type(e).__name__}: {e}"
                    for k in b.keys:
                        it = items[(c, k)]
                        if it.status == "pending":
                            it.status, it.reviewer_note = "failed", f"model call failed: {e}"

        with concurrent.futures.ThreadPoolExecutor(max_workers=WORKERS) as pool:
            list(pool.map(one, batches))
    for it in items.values():
        decide(it, args.skip_review)
    results = []
    for code, w in work.items():
        m = meta_for(code)
        results.append(LocaleResult(code, m.name, m.rtl, [items[(code, k)] for k in w.translate], w.remove, errors.get(code, "")))
    return results


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


def results_dict(results: list[LocaleResult], run: dict) -> dict:
    return {"run": run, "models": MODELS, "locales": [
        {"code": r.code, "name": r.name, "rtl": r.rtl, "removed": r.removed, "error": r.error,
         "stats": r.stats(), "items": [asdict(i) for i in r.items]} for r in results]}


def html_report(data: dict) -> str:
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


def apply_results(data: dict, en: PoFile, targets: dict[str, PoFile]) -> list[list]:
    """Write a saved run's translations into the locale files without any model call.
    A string is skipped when its English text has changed since the run."""
    rows = []
    for L in data.get("locales", []):
        po = targets.get(L["code"])
        if po is None:
            continue
        written = skipped = 0
        changed = ensure_charset(po)
        for k in L.get("removed", []):
            if po.has(k) and not en.has(k):
                po.remove(k)
                changed = True
        for it in L.get("items", []):
            text = it.get("final") or ""
            if it.get("status") not in ("passed", "fixed", "flagged") or not text:
                continue
            if en.get(it["key"]) != it.get("source"):
                skipped += 1
                continue
            if po.get(it["key"]) != text:
                po.set(it["key"], text)
                changed = True
            written += 1
        if changed:
            po.write()
            validate_po(po.path, len(po.keys()))
        rows.append([L["code"], written, skipped, len(L.get("removed", []))])
    return rows


# --------------------------------------------------------------------------- main


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", default="", help="commit to diff en.po against for changed strings")
    ap.add_argument("--locales", default="", help="comma-separated locale codes; default all")
    ap.add_argument("--limit", type=int, default=0, help="cap strings per locale (for test runs)")
    ap.add_argument("--dry-run", action="store_true", help="write reports only, leave .po files untouched")
    ap.add_argument("--skip-review", action="store_true", help="skip back-translation and review (cheap test)")
    ap.add_argument("--out", default=str(ROOT / "build" / "translate"), help="report directory")
    ap.add_argument("--apply", default="", help="write the translations saved in this results.json into the locale files; no API calls")
    ap.add_argument("--render", default="", help="rebuild report.html in --out from this results.json and exit; no API calls")
    ap.add_argument("--resume", default="", help="results.json from an earlier run; reuse its translations and only run the missing stages")
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
    if args.render:
        (out / "report.html").write_text(html_report(json.loads(Path(args.render).read_text(encoding="utf-8"))), encoding="utf-8")
        log(f"report rebuilt at {out / 'report.html'}")
        return 0
    en = PoFile(LOCALES_DIR / f"{SOURCE}.po")
    wanted = {c.strip() for c in args.locales.split(",") if c.strip()}
    targets = {p.stem: PoFile(p) for p in sorted(LOCALES_DIR.glob("*.po"))
               if p.stem != SOURCE and (not wanted or p.stem in wanted)}
    unknown = wanted - set(targets)
    if unknown:
        log(f"error: no .po file for {', '.join(sorted(unknown))}")
        return 1
    if args.apply:
        rows = apply_results(json.loads(Path(args.apply).read_text(encoding="utf-8")), en, targets)
        rows.append(["total", sum(r[1] for r in rows), sum(r[2] for r in rows), sum(r[3] for r in rows)])
        print(text_table(["Locale", "Written", "Skipped (English changed)", "Removed"], rows))
        return 0

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

    results = run_all(work, en, targets, claude, args)
    for r in results:
        st = r.stats()
        log(f"  {r.code:<8} done: {st['translated']:>4} written, {st['flagged']:>3} flagged, "
            f"{st['rejected'] + st['failed']:>3} not written, {st['removed']:>3} removed"
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
    data = results_dict(results, run)
    (out / "results.json").write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    summary = summary_markdown(results, run)
    (out / "summary.md").write_text(summary, encoding="utf-8")
    (out / "commit_message.txt").write_text(commit_message(results, run), encoding="utf-8")
    (out / "report.html").write_text(html_report(data), encoding="utf-8")
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
  :root { --bg:#fff; --fg:#1f2328; --muted:#656d76; --line:#d0d7de; --row:#f6f8fa; --card:#fff; --pass:#1a7f37; --fix:#0969da; --flag:#9a6700; --bad:#cf222e; --sel:#ddf4ff; }
  @media (prefers-color-scheme: dark) { :root { --bg:#0d1117; --fg:#e6edf3; --muted:#8d96a0; --line:#30363d; --row:#161b22; --card:#161b22; --pass:#3fb950; --fix:#58a6ff; --flag:#d29922; --bad:#f85149; --sel:#1f3a5a; } }
  body { margin:0; padding:20px; font:14px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; background:var(--bg); color:var(--fg); }
  h1 { font-size:22px; margin:0 0 2px; } h2 { font-size:16px; margin:26px 0 10px; }
  .meta { color:var(--muted); font-size:13px; }
  .headline { display:grid; grid-template-columns:repeat(auto-fit, minmax(130px,1fr)); gap:10px; margin:18px 0 6px; }
  .big { border:1px solid var(--line); border-radius:10px; padding:12px 14px; background:var(--card); }
  .big b { display:block; font-size:28px; line-height:1.1; font-variant-numeric:tabular-nums; } .big span { color:var(--muted); font-size:12px; }
  .big.pass b{color:var(--pass)} .big.fix b{color:var(--fix)} .big.flag b{color:var(--flag)} .big.bad b{color:var(--bad)}
  .cards { display:grid; grid-template-columns:repeat(auto-fill, minmax(118px,1fr)); gap:6px; }
  .card { border:1px solid var(--line); border-radius:6px; padding:5px 8px; background:var(--card); cursor:pointer; font-variant-numeric:tabular-nums; font-size:12px; line-height:1.3; }
  .card:hover { border-color:var(--fix); } .card.on { background:var(--sel); border-color:var(--fix); }
  .card .code { font-weight:700; font-size:13px; }
  .card .row { display:flex; justify-content:space-between; gap:6px; color:var(--muted); }
  .card .row b { color:var(--fg); font-weight:600; }
  .card .warn { color:var(--flag); } .card .bad { color:var(--bad); } .card .fixn { color:var(--fix); }
  .bar { height:3px; background:var(--line); border-radius:2px; margin-top:4px; overflow:hidden; } .bar i { display:block; height:100%; background:var(--pass); }
  .controls { display:flex; flex-wrap:wrap; gap:10px; align-items:center; margin:10px 0; }
  .controls label { display:flex; gap:4px; align-items:center; font-size:13px; }
  input[type=text], select { padding:4px 6px; border:1px solid var(--line); border-radius:6px; background:var(--bg); color:var(--fg); }
  table { border-collapse:collapse; width:100%; }
  th, td { border-bottom:1px solid var(--line); padding:6px 8px; vertical-align:top; text-align:left; }
  th { position:sticky; top:0; background:var(--bg); cursor:pointer; white-space:nowrap; user-select:none; font-size:12px; }
  tbody tr:nth-child(odd) { background:var(--row); }
  td.k { font-family:ui-monospace, SFMono-Regular, Menlo, monospace; font-size:12px; white-space:nowrap; }
  td.t { max-width:320px; } td.n { color:var(--muted); font-size:12px; max-width:300px; }
  .old { text-decoration:line-through; color:var(--muted); display:block; }
  .s { font-weight:600; } .passed{color:var(--pass)} .fixed{color:var(--fix)} .flagged{color:var(--flag)} .rejected,.failed{color:var(--bad)}
  .err { color:var(--bad); font-size:12px; }
  .clamp { display:-webkit-box; -webkit-line-clamp:2; -webkit-box-orient:vertical; overflow:hidden; cursor:pointer; }
  .clamp.open { display:block; -webkit-line-clamp:unset; overflow:visible; }
  td.t { max-width:320px; }
</style>
</head>
<body>
<h1>Translation report</h1>
<div class="meta" id="meta"></div>
<div class="headline" id="headline"></div>
<div class="meta" id="tokens"></div>

<h2>Per locale <span class="meta">(click a card to filter the table)</span></h2>
<div class="cards" id="cards"></div>

<h2 id="tableTitle">All strings</h2>
<div class="controls">
  <label>Locale <select id="locale"><option value="">all</option></select></label>
  <label>Status <select id="status"><option value="">all</option><option value="attention">needs attention</option><option>passed</option><option>fixed</option><option>flagged</option><option>rejected</option><option>failed</option></select></label>
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
const $ = id => document.getElementById(id);
const rows = [];
for (const L of data.locales) for (const it of L.items) rows.push({
  locale: L.code, rtl: L.rtl, ...it, final: it.final || it.translation,
  notes: [it.reviewer_note, it.translator_note, ...(it.hard_issues||[]), ...(it.soft_issues||[])].filter(Boolean).join(' · '),
  scoreText: it.scores && Object.keys(it.scores).length ? Object.entries(it.scores).map(([k,v]) => k.slice(0,3)+' '+v).join(' ') : ''
});
const LANG = {"es-cu": "es-CU", "fr-ca": "fr-CA", "ur-in": "ur-IN", "pt_BR": "pt-BR", "zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant"};
const langOf = code => LANG[code] || code;
const r = data.run, m = data.models;
$('meta').textContent = `${r.timestamp} · ${r.mode} · base ${r.base || 'none (filled gaps)'} · translate ${m.translate} · review ${m.review} · back-translate ${m.backtranslate}`;

// headline numbers
const sum = k => data.locales.reduce((a, L) => a + (L.stats[k] || 0), 0);
const confs = rows.map(x => x.confidence).filter(c => c != null);
const mean = confs.length ? (confs.reduce((a,b)=>a+b,0)/confs.length) : null;
const low = confs.length ? Math.min(...confs) : null;
const notWritten = sum('rejected') + sum('failed');
const activeLocales = data.locales.filter(L => L.items.length || L.removed.length).length;
$('headline').innerHTML = [
  ['', sum('translated'), 'strings translated'],
  ['', activeLocales, `locale${activeLocales === 1 ? '' : 's'}`],
  ['pass', sum('passed'), 'passed review'],
  ['fix', sum('fixed'), 'fixed by review'],
  ['flag', sum('flagged'), 'flagged for a look'],
  ['bad', notWritten, 'not written'],
  ['', sum('removed'), 'stale entries removed'],
  ['', mean == null ? '–' : mean.toFixed(2), 'mean confidence'],
  ['', low == null ? '–' : low.toFixed(2), 'lowest confidence'],
].map(([cls, n, label]) => `<div class="big ${cls}"><b>${n}</b><span>${label}</span></div>`).join('');
if (r.usage && Object.keys(r.usage).length) {
  $('tokens').textContent = 'Tokens: ' + Object.entries(r.usage).map(([mm, u]) =>
    `${mm}: in ${u.input.toLocaleString()} (+${u.cache_read.toLocaleString()} cached), out ${u.output.toLocaleString()}`).join(' · ');
}

// per-locale cards
let selected = '';
const cards = $('cards');
for (const L of data.locales) {
  const s = L.stats, n = L.items.length || 1;
  const conf = s.mean_confidence != null ? `<b>${s.mean_confidence.toFixed(2)}</b> / ${s.min_confidence.toFixed(2)}` : 'no review';
  const marks = [s.fixed ? `<span class="fixn">${s.fixed} fixed</span>` : '', s.flagged ? `<span class="warn">${s.flagged} flagged</span>` : '',
                 s.rejected + s.failed ? `<span class="bad">${s.rejected + s.failed} not written</span>` : ''].filter(Boolean).join(' · ');
  cards.insertAdjacentHTML('beforeend', `<div class="card" data-code="${esc(L.code)}" title="${esc(L.name)}">
    <div class="row"><span class="code">${esc(L.code)}</span><span><b>${s.translated}</b> strings</span></div>
    <div class="row"><span>conf</span><span>${conf}</span></div>
    ${marks ? `<div class="row"><span>${marks}</span></div>` : ''}
    ${L.error ? `<div class="err">${esc(L.error)}</div>` : ''}
    <div class="bar"><i style="width:${100*(s.passed+s.fixed)/n}%"></i></div></div>`);
  $('locale').insertAdjacentHTML('beforeend', `<option>${esc(L.code)}</option>`);
}
cards.addEventListener('click', e => {
  const card = e.target.closest('.card'); if (!card) return;
  selected = selected === card.dataset.code ? '' : card.dataset.code;
  $('locale').value = selected; render();
});

// table
let sortKey = 'locale', sortDir = 1;
function render() {
  const loc = $('locale').value, st = $('status').value, maxc = parseFloat($('conf').value), q = $('q').value.toLowerCase();
  document.querySelectorAll('.card').forEach(c => c.classList.toggle('on', c.dataset.code === loc));
  $('confv').textContent = maxc.toFixed(2);
  let out = rows.filter(x => (!loc || x.locale === loc) && (!st || (st === 'attention' ? x.status !== 'passed' : x.status === st))
    && (x.confidence == null || x.confidence <= maxc)
    && (!q || [x.key, x.source, x.final, x.back_translation, x.notes].join(' ').toLowerCase().includes(q)));
  out.sort((a, b) => {
    let va = a[sortKey], vb = b[sortKey];
    if (sortKey === 'scores') { va = a.scoreText; vb = b.scoreText; }
    if (va == null) return 1; if (vb == null) return -1;
    return (va > vb ? 1 : va < vb ? -1 : 0) * sortDir;
  });
  $('tableTitle').textContent = loc ? `Strings for ${loc} (${out.length})` : `All strings (${out.length} of ${rows.length})`;
  $('count').textContent = `${out.length} shown`;
  $('rows').innerHTML = out.map(x => `<tr>
    <td>${esc(x.locale)}</td><td class="k">${esc(x.key)}</td><td class="t"><div class="clamp" lang="en">${esc(x.source)}</div></td>
    <td class="t"><div class="clamp" lang="${langOf(x.locale)}" ${x.rtl ? 'dir="rtl"' : ''}>${x.reason === 'changed' && x.old ? `<span class="old">${esc(x.old)}</span>` : ''}${x.status === 'fixed' && x.translation !== x.final ? `<span class="old">${esc(x.translation)}</span>` : ''}${esc(x.final)}</div></td>
    <td class="t"><div class="clamp" lang="en">${esc(x.back_translation)}</div></td>
    <td class="s ${x.status}">${esc(x.status)}</td><td>${x.confidence == null ? '' : x.confidence.toFixed(2)}</td>
    <td class="n">${esc(x.scoreText)}</td><td class="n"><div class="clamp" lang="en">${esc(x.notes)}</div></td></tr>`).join('');
}
for (const id of ['locale', 'status', 'conf', 'q']) $(id).addEventListener('input', () => { selected = $('locale').value; render(); });
// long cells show two lines; click to expand or collapse
$('rows').addEventListener('click', e => { const c = e.target.closest('.clamp'); if (c) c.classList.toggle('open'); });
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
