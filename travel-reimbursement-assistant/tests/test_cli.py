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

    def call_with_legacy_encoding(self, *args, demo=False):
        # Force the Windows CI encoding even on UTF-8 developer machines.
        env = dict(os.environ, PYTHONPATH=str(ROOT / 'src'),
                   PYTHONIOENCODING='cp1252', PYTHONUTF8='0')
        command = [sys.executable, str(ROOT / 'examples' / 'demo.py')] if demo else [
            sys.executable, '-m', 'my_tool.main', *map(str, args)]
        # Capture bytes: the child's UTF-8 output is the public contract here.
        return subprocess.run(command, cwd=ROOT, env=env, capture_output=True)

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

    def test_help_is_utf8_when_parent_requests_cp1252(self):
        result = self.call_with_legacy_encoding('--help')
        self.assertEqual(result.returncode, 0, result.stderr.decode('utf-8'))
        self.assertIn('差旅报销教学原型', result.stdout.decode('utf-8'))
        self.assertEqual(result.stderr, b'')

    def test_success_json_is_utf8_when_parent_requests_cp1252(self):
        result = self.call_with_legacy_encoding(
            'check', 'data/claim.json', '--policies', 'config/policies.json')
        self.assertEqual(result.returncode, 0, result.stderr.decode('utf-8'))
        payload = json.loads(result.stdout.decode('utf-8'))
        self.assertEqual(payload['status'], 'READY_FOR_REVIEW')
        self.assertIn('教学规则', payload['policy']['clause'])
        self.assertEqual(result.stderr, b'')

    def test_error_json_is_utf8_when_parent_requests_cp1252(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'missing.db'
            result = self.call_with_legacy_encoding('metrics', 'DEMO-001', '--db', path)
            self.assertFalse(path.exists())
        self.assertEqual(result.returncode, 2)
        payload = json.loads(result.stderr.decode('utf-8'))
        self.assertIn('本地台账不存在', payload['error'])
        self.assertEqual(result.stdout, b'')

    def test_demo_json_is_utf8_when_parent_requests_cp1252(self):
        result = self.call_with_legacy_encoding(demo=True)
        self.assertEqual(result.returncode, 0, result.stderr.decode('utf-8'))
        payload = json.loads(result.stdout.decode('utf-8'))
        self.assertIn('合成演示', payload['说明'])
        self.assertEqual(payload['正常预检']['status'], 'READY_FOR_REVIEW')
        self.assertEqual(payload['制度版本冲突']['status'], 'NEEDS_MANUAL_REVIEW')
        self.assertEqual(payload['时长']['review_hours'], 48)
        self.assertEqual(result.stderr, b'')


if __name__ == '__main__':
    unittest.main()
