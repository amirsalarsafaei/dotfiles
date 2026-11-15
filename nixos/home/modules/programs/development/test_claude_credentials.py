import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SOURCE = Path(__file__).with_name('claude-code.nix').read_text()
spec = importlib.util.spec_from_file_location(
    'glm_quota', Path(__file__).with_name('glm-quota.py'))
quota = importlib.util.module_from_spec(spec)
spec.loader.exec_module(quota)


class ClaudeCredentialTests(unittest.TestCase):
    def launcher(self, directory, lookup):
        tool = Path(directory) / 'secret-tool'
        tool.write_text('#!/usr/bin/env bash\n' + lookup + '\n')
        tool.chmod(0o700)
        auth = SOURCE.split('  mkKeyAuth =', 1)[1].split("    ''\n", 1)[1]
        auth = auth.split("\n    '';", 1)[0]
        auth = auth.replace('${lib.getExe\' pkgs.libsecret "secret-tool"}', str(tool))
        auth = auth.replace('${name}', 'glm-claude').replace('${authVar}', 'ANTHROPIC_AUTH_TOKEN')
        return auth

    def test_missing_keyring_fails_even_with_old_file_and_inherited_keys(self):
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / 'glm-key').write_text('obsolete-file-secret')
            auth = self.launcher(directory, 'exit 1')
            result = subprocess.run(['bash', '-eu', '-c', auth], capture_output=True,
                                    env=os.environ | {'HOME': directory,
                                                      'ANTHROPIC_AUTH_TOKEN': 'inherited'})
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b'secret set api-key glm-claude', result.stderr)
            self.assertNotIn(b'obsolete-file-secret', result.stdout + result.stderr)

    def test_keyring_key_replaces_inherited_auth_and_stays_out_of_output(self):
        with tempfile.TemporaryDirectory() as directory:
            auth = self.launcher(directory, 'printf "%s" "keyring-test-secret"')
            auth += '\n[[ "$ANTHROPIC_AUTH_TOKEN" == keyring-test-secret ]]\n'
            auth += '[[ ! -v ANTHROPIC_API_KEY && ! -v key ]]\n'
            result = subprocess.run(['bash', '-eu', '-c', auth], capture_output=True,
                                    env=os.environ | {'ANTHROPIC_API_KEY': 'inherited'})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout + result.stderr, b'')

    def test_legacy_paths_still_masked_in_both_sandboxes(self):
        denied = SOURCE.split('  sandboxSecretDenyPaths = [', 1)[1].split('  ];', 1)[0]
        for name in ['glm-key', 'gapgpt-key', 'deepseek-key', 'kimi-key', 'orca-key',
                     'personal-deepseek', 'divar-glm', 'divar-deepseek']:
            self.assertIn(f'/{name}"', denied)
        work = Path(__file__).parents[4] / 'modules/work.nix'
        self.assertIn('config.custom.claudeCode.sandbox.denyPaths', work.read_text())

    def test_quota_ignores_legacy_file_even_when_present(self):
        with tempfile.TemporaryDirectory() as directory:
            key = Path(directory) / 'glm-key'
            key.write_text('obsolete-file-secret')
            with patch.dict(os.environ, {'HOME': directory, 'GLM_KEY_FILE': str(key)}, clear=True):
                self.assertEqual(quota.auth_token(), '')
                os.environ['ANTHROPIC_AUTH_TOKEN'] = 'injected-keyring-key'
                self.assertEqual(quota.auth_token(), 'injected-keyring-key')


if __name__ == '__main__':
    unittest.main()
