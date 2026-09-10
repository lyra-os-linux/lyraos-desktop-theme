"""Check local shell references without running installers or touching the host."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class EntrypointTests(unittest.TestCase):
    def test_referenced_shell_entrypoints_exist_and_are_executable(self):
        # These are the literal checkout-relative forms used by this repository.
        # This is not a shell parser and does not resolve arbitrary computed paths.
        reference = re.compile(
            r'(?:\./|\$(?:root|ROOT|\{root\}|\{ROOT\})/)'
            r'([A-Za-z0-9_./-]+\.sh)\b'
        )
        sources = [ROOT / 'README.md', *ROOT.glob('*.sh'),
                   *ROOT.glob('scripts/*.sh'), *ROOT.glob('packaging/**/*.spec'),
                   *ROOT.glob('.github/workflows/*.yml')]
        checked = set()
        for source in sources:
            for target in reference.findall(source.read_text()):
                checked.add(target)
                with self.subTest(source=str(source.relative_to(ROOT)), target=target):
                    path = ROOT / target
                    self.assertTrue(path.is_file(), f'Missing local entrypoint: {target}')
                    self.assertTrue(path.stat().st_mode & 0o111,
                                    f'Local entrypoint is not executable: {target}')
        self.assertTrue(checked, 'No entrypoints found; check reference patterns')


if __name__ == '__main__':
    unittest.main()
