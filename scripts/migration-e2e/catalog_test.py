import bz2
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import bundle_test
import catalog


class CatalogTest(unittest.TestCase):
    setUp = bundle_test.BundleTest.setUp
    validate = bundle_test.BundleTest.validate

    def test_assembly_preserves_exact_signed_bytes(self):
        self.validate()
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / 'fresh'
            with patch('bundle.verify_binary_builds'):
                catalog.assemble(self.root, catalog.bundle.sha256(self.root / 'manifest.json'), output)
            self.assertEqual(bz2.decompress((output / 'v7.9.6/update_windows_386_7.9.6.bz2').read_bytes()),
                             (self.root / 'bridge.exe').read_bytes())
            self.assertEqual((output / 'v10.2.0/lantern-installer.exe').read_bytes(),
                             (self.root / 'installer.exe').read_bytes())
            with patch('bundle.verify_binary_builds'), self.assertRaises(FileExistsError):
                catalog.assemble(self.root, catalog.bundle.sha256(self.root / 'manifest.json'), output)


if __name__ == '__main__':
    unittest.main()
