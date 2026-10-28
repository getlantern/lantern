"""Tests for translate.py. Run: cd tools/localization && python3 -m unittest test_translate -v"""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import translate as t


class PoRoundTrip(unittest.TestCase):
    def test_every_locale_round_trips_byte_for_byte(self):
        for p in sorted(t.LOCALES_DIR.glob("*.po")):
            with self.subTest(p.name):
                original = p.read_text(encoding="utf-8")
                self.assertEqual(t.PoFile(p).text(), original.rstrip("\n") + "\n")

    @unittest.skipUnless(shutil.which("msgfmt"), "gettext not installed")
    def test_en_parses_every_entry(self):
        en = t.PoFile(t.LOCALES_DIR / "en.po")
        self.assertEqual(sum(1 for e in en.entries if e.key == ""), 1)  # the header
        stat = subprocess.run(["msgfmt", "--statistics", "-o", "/dev/null", str(en.path)],
                              capture_output=True, text=True).stderr
        self.assertEqual(len(en.keys()), int(stat.split()[0]))

    def test_wrapped_msgstr_is_joined(self):
        ar = t.PoFile(t.LOCALES_DIR / "ar.po")
        v = ar.get("referral_converted_message")
        self.assertIsNotNone(v)
        self.assertEqual(v.count("%s"), 2)
        self.assertNotIn('"', v)

    def test_comments_are_captured(self):
        en = t.PoFile(t.LOCALES_DIR / "en.po")
        self.assertTrue([k for k in en.keys() if en.comment(k)])


class PoEdits(unittest.TestCase):
    SAMPLE = ('msgid ""\nmsgstr ""\n"Content-Type: text/plain; charset=UTF-8\\n"\n\n'
              '# where it shows\nmsgid "a"\nmsgstr "A"\n\n'
              'msgid "b"\nmsgstr ""\n"long first part "\n"second part"\n\n'
              'msgid "c"\nmsgstr "C"\n')

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.p = self.dir / "x.po"
        self.p.write_text(self.SAMPLE, encoding="utf-8")

    def tearDown(self):
        shutil.rmtree(self.dir)

    def test_set_replaces_wrapped_block_with_single_line(self):
        po = t.PoFile(self.p)
        po.set("b", 'new "quoted"\nline')
        text = po.text()
        self.assertIn('msgid "b"\nmsgstr "new \\"quoted\\"\\nline"\n\nmsgid "c"', text)
        self.assertNotIn("long first part", text)

    def test_set_keeps_comments_and_other_entries(self):
        po = t.PoFile(self.p)
        po.set("a", "AA")
        text = po.text()
        self.assertIn('# where it shows\nmsgid "a"\nmsgstr "AA"\n', text)
        self.assertIn('msgid "c"\nmsgstr "C"\n', text)

    def test_add_appends_with_separator(self):
        po = t.PoFile(self.p)
        po.set("d", "D")
        po.set("e", "E")
        self.assertTrue(po.text().endswith('msgstr "C"\n\nmsgid "d"\nmsgstr "D"\n\nmsgid "e"\nmsgstr "E"\n'))

    def test_remove_drops_block_and_file_stays_valid(self):
        po = t.PoFile(self.p)
        po.remove("b")
        po.remove("c")
        text = po.text()
        self.assertNotIn('msgid "b"', text)
        self.assertTrue(text.endswith('msgstr "A"\n'))
        po.write()
        t.validate_po(self.p, 1)

    def test_reparse_after_edit(self):
        po = t.PoFile(self.p)
        po.set("b", "tab\there")
        po.write()
        again = t.PoFile(self.p)
        self.assertEqual(again.get("b"), "tab\there")
        self.assertEqual(again.get("a"), "A")

    def test_tolerates_extra_spaces_and_trailing_whitespace(self):
        self.p.write_text('msgid ""\nmsgstr ""\n\nmsgid "a" \nmsgstr  "A"\n', encoding="utf-8")
        self.assertEqual(t.PoFile(self.p).get("a"), "A")


class Escaping(unittest.TestCase):
    def test_round_trip(self):
        for s in ["plain", 'with "quotes"', "new\nline", "back\\slash", "tab\t", "%s and %d"]:
            self.assertEqual(t.po_unescape(t.po_escape(s)), s)


class Checks(unittest.TestCase):
    es = t.meta_for("es")

    def test_placeholder_mismatch_is_hard(self):
        hard, _ = t.check("You earned %s of %s", "Ganaste %s", self.es)
        self.assertTrue(any("placeholders" in h for h in hard))

    def test_placeholder_order_matters(self):
        hard, _ = t.check("%s of %d", "%d de %s", self.es)
        self.assertTrue(hard)

    def test_newline_count_is_hard(self):
        hard, _ = t.check("a\nb", "ab", self.es)
        self.assertIn("line break count differs", hard)

    def test_identical_is_soft_unless_allowed(self):
        _, soft = t.check("Settings", "Settings", self.es)
        self.assertTrue(any("identical" in s for s in soft))
        _, soft = t.check("VPN", "VPN", self.es)
        self.assertFalse(soft)

    def test_glossary_term_missing_is_soft(self):
        _, soft = t.check("Open Lantern settings", "Abrir ajustes", self.es)
        self.assertTrue(any("Lantern" in s for s in soft))

    def test_glossary_alias_is_accepted(self):
        _, soft = t.check("Open Lantern settings", "打开蓝灯设置", t.meta_for("zh-Hans"))
        self.assertFalse([s for s in soft if "Lantern" in s])
        _, soft = t.check("VPN Settings", "ভিপিএন সেটিংস", t.meta_for("bn"))
        self.assertFalse([s for s in soft if "VPN" in s])

    def test_clean_translation_passes(self):
        self.assertEqual(t.check("Connect to %s now", "Conéctate a %s ahora", self.es), ([], []))


class Detection(unittest.TestCase):
    def test_gaps_and_stale_keys(self):
        d = Path(tempfile.mkdtemp())
        try:
            (d / "en.po").write_text('msgid ""\nmsgstr ""\n\nmsgid "a"\nmsgstr "A"\n\nmsgid "b"\nmsgstr "B"\n', encoding="utf-8")
            (d / "xx.po").write_text('msgid ""\nmsgstr ""\n\nmsgid "a"\nmsgstr "AA"\n\nmsgid "old"\nmsgstr "gone"\n', encoding="utf-8")
            work = t.detect(t.PoFile(d / "en.po"), {"xx": t.PoFile(d / "xx.po")}, base="", limit=0)["xx"]
            self.assertEqual(list(work.translate), ["b"])
            self.assertEqual(work.reasons["b"], "gap")
            self.assertEqual(work.remove, ["old"])
        finally:
            shutil.rmtree(d)

    def test_limit_caps_work(self):
        en = t.PoFile(t.LOCALES_DIR / "en.po")
        d = Path(tempfile.mkdtemp())
        try:
            (d / "xx.po").write_text('msgid ""\nmsgstr ""\n', encoding="utf-8")
            work = t.detect(en, {"xx": t.PoFile(d / "xx.po")}, base="", limit=3)["xx"]
            self.assertEqual(len(work.translate), 3)
        finally:
            shutil.rmtree(d)


class Guides(unittest.TestCase):
    def test_every_locale_has_a_guide_section_and_metadata(self):
        common = t.load_guide("__none__")
        self.assertIn("Placeholders", common)
        for p in sorted(t.LOCALES_DIR.glob("*.po")):
            if p.stem == "en":
                continue
            with self.subTest(p.stem):
                self.assertIn(p.stem, t.LOCALES, f"missing LOCALES entry for {p.stem}")
                own = t.load_guide(p.stem)
                self.assertGreater(len(own), len(common) + 200, f"guides.md has no real '## {p.stem}' section")



class Audit(unittest.TestCase):
    def test_dynamic_keys_are_not_reported(self):
        d = Path(tempfile.mkdtemp())
        try:
            (d / "a.dart").write_text("x('used_key'); y('continue_with_${p.value}'.i18n); z('${k}_title'.i18n);", encoding="utf-8")
            literals, dynamic = t.source_literals([d])
            self.assertIn("used_key", literals)
            self.assertIn(("continue_with_", ""), dynamic)
            self.assertIn(("", "_title"), dynamic)
            self.assertTrue(t.dynamically_referenced("continue_with_gcp", dynamic, []))
            self.assertTrue(t.dynamically_referenced("anything_title", dynamic, []))
            self.assertFalse(t.dynamically_referenced("plain_key", dynamic, []))
            self.assertTrue(t.dynamically_referenced("loc_x", dynamic, ["loc_"]))
            self.assertEqual(t.i18n_literals([d]), set())
        finally:
            shutil.rmtree(d)


class AllLocalesAreTargets(unittest.TestCase):
    def test_every_po_file_is_translated_including_fr_ca_pt_br_ur(self):
        """No locale is special-cased: the target set is exactly the .po files on disk."""
        en = t.PoFile(t.LOCALES_DIR / "en.po")
        stems = sorted(p.stem for p in t.LOCALES_DIR.glob("*.po") if p.stem != "en")
        targets = {s: t.PoFile(t.LOCALES_DIR / f"{s}.po") for s in stems}
        work = t.detect(en, targets, base="", limit=0)
        self.assertEqual(sorted(work), stems)
        for must in ("fr-ca", "pt_BR", "ur", "ur-in", "ar", "zh-Hans"):
            self.assertIn(must, work)
            self.assertIn(must, t.LOCALES)
            self.assertGreater(len(t.load_guide(must)), 0)
        # every locale gets every English key that it lacks, nothing is skipped
        for code, w in work.items():
            gaps = {k for k in en.keys() if en.get(k) and not targets[code].get(k)}
            self.assertEqual(set(w.translate), gaps, code)


class Cleanup(unittest.TestCase):
    def test_code_references_is_a_word_search_over_the_source_dirs(self):
        d = Path(tempfile.mkdtemp())
        try:
            (d / "lib").mkdir(); (d / "docs").mkdir()
            (d / "lib" / "a.dart").write_text("final k = Key('auth.confirm_password');\n", encoding="utf-8")
            (d / "lib" / "b.dart").write_text("const x = 'prefix_only_sub_suffix';\n", encoding="utf-8")
            (d / "docs" / "n.md").write_text("mentions only_in_docs", encoding="utf-8")
            hits = t.code_references(["confirm_password", "only_sub", "only_in_docs", "truly_dead"], [d / "lib"])
            self.assertTrue(hits["confirm_password"].endswith("a.dart"))  # inside a longer literal
            self.assertNotIn("only_sub", hits)        # joined by underscores is a different identifier
            self.assertNotIn("only_in_docs", hits)    # docs are not scanned
            self.assertNotIn("truly_dead", hits)
        finally:
            shutil.rmtree(d)

    def test_ensure_charset_adds_header_once(self):
        d = Path(tempfile.mkdtemp())
        try:
            p = d / "x.po"
            p.write_text('msgid ""\nmsgstr ""\n"Language: xx\\n"\n\nmsgid "a"\nmsgstr "A"\n', encoding="utf-8")
            po = t.PoFile(p)
            self.assertTrue(t.ensure_charset(po))
            self.assertFalse(t.ensure_charset(po))
            po.write()
            t.validate_po(p, 1)
            self.assertIn("charset=UTF-8", t.PoFile(p).get(""))
        finally:
            shutil.rmtree(d)


if __name__ == "__main__":
    unittest.main()
