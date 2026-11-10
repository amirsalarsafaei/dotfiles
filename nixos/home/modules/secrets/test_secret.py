import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class SecretTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        tool = Path(self.directory.name) / "secret-tool"
        tool.write_text(
            f"#!{sys.executable}\n"
            "import json, os, sys\n"
            "value = sys.stdin.read() if sys.argv[1] == 'store' else None\n"
            "print(json.dumps([sys.argv[1:], value]))\n"
            "sys.exit(int(os.environ.get('SECRET_TEST_STATUS', '0')))\n"
        )
        tool.chmod(0o700)
        self.env = os.environ | {
            "PATH": self.directory.name + os.pathsep + os.environ["PATH"]
        }
        self.bash = shutil.which("bash")
        self.script = Path(__file__).with_name("secret.sh")

    def run_secret(self, *args, value=None):
        return subprocess.run(
            [self.bash, "-euo", "pipefail", str(self.script), *args],
            input=value,
            capture_output=True,
            text=True,
            env=self.env,
            check=False,
        )

    def test_store_passes_value_only_on_stdin(self):
        result = self.run_secret("set", "api-key", "glm-claude", value="test-value")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(result.stdout),
            [
                [
                    "store",
                    "--label=glm-claude (api-key)",
                    "type",
                    "api-key",
                    "id",
                    "glm-claude",
                ],
                "test-value",
            ],
        )

    def test_lookup_and_delete_use_same_identity_for_every_type(self):
        for type_name in ("api-key", "token", "password"):
            for action, command in (("get", "lookup"), ("delete", "clear")):
                with self.subTest(type=type_name, action=action):
                    result = self.run_secret(action, type_name, "claude-2")
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(
                        json.loads(result.stdout),
                        [[command, "type", type_name, "id", "claude-2"], None],
                    )

    def test_rejects_bad_arguments_before_accessing_keyring(self):
        invalid = [
            (),
            ("get", "api-key"),
            ("get", "api-key", "claude", "extra"),
            ("list", "api-key", "claude"),
            ("get", "apikey", "claude"),
        ] + [
            ("get", "api-key", slug)
            for slug in (
                "",
                "Claude",
                "-claude",
                "claude-",
                "claude--work",
                "claude/key",
                "claude key",
            )
        ]
        for args in invalid:
            with self.subTest(args=args):
                result = self.run_secret(*args)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(result.stdout, "")

    def test_preserves_tool_failure_status(self):
        self.env["SECRET_TEST_STATUS"] = "1"
        result = self.run_secret("get", "api-key", "claude")
        self.assertEqual(result.returncode, 1)

    def test_help(self):
        result = self.run_secret("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("api-key, token, password", result.stdout)


if __name__ == "__main__":
    unittest.main()
