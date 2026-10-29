import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CliTests(unittest.TestCase):
    def call(self, *args):
        env = dict(os.environ, PYTHONPATH=str(ROOT / 'src'), PYTHONIOENCODING='utf-8')
        return subprocess.run([sys.executable, '-m', 'my_tool.main', *map(str, args)],
                              cwd=ROOT, env=env, capture_output=True, text=True, encoding='utf-8')

    def test_readme_check_command(self):
        result = self.call('check', 'data/claim.json', '--policies', 'config/policies.json')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['status'], 'READY_FOR_REVIEW')

    def test_duplicate_json_keys_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'bad.json'
            path.write_text('{"id":"one","id":"two"}', encoding='utf-8')
            result = self.call('check', path, '--policies', 'config/policies.json')
        self.assertEqual(result.returncode, 2)
        self.assertIn('error', json.loads(result.stderr))
        self.assertNotIn('Traceback', result.stderr)

    def test_metrics_does_not_create_missing_database(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'missing.db'
            result = self.call('metrics', 'DEMO-001', '--db', path)
            self.assertEqual(result.returncode, 2)
            self.assertFalse(path.exists())

    def test_import_and_query_persist_across_processes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'nested' / 'ledger.db'
            first = self.call('import-events', 'data/events.csv', '--db', path)
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(json.loads(first.stdout)['imported'], 5)
            second = self.call('import-events', 'data/events.csv', '--db', path)
            self.assertEqual(json.loads(second.stdout)['duplicates'], 5)
            result = self.call('metrics', 'DEMO-001', '--db', path)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)['review_hours'], 48)
            self.assertEqual(json.loads(result.stdout)['payment_hours'], 72)


if __name__ == '__main__':
    unittest.main()
