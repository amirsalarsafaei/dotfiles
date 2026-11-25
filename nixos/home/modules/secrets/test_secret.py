import json
import os
import pty
import select
import shutil
import subprocess
import sys
import tempfile
import time
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

    def test_store_trims_surrounding_line_breaks(self):
        for type_name in ("api-key", "token"):
            for value in ("\nkey\n", "\r\n\r\nkey\r\n", "key\n\n", "\rkey\r"):
                with self.subTest(type=type_name, value=value):
                    result = self.run_secret("set", type_name, "orca-claude", value=value)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(json.loads(result.stdout)[1], "key")

    def test_store_rejects_empty_or_multiline_keys_before_accessing_keyring(self):
        for type_name in ("api-key", "token"):
            for value in ("", "\r\n", "first\nsecond", "first\rsecond", "key\0tail"):
                with self.subTest(type=type_name, value=value):
                    result = self.run_secret("set", type_name, "orca-claude", value=value)
                    self.assertEqual(result.returncode, 2)
                    self.assertEqual(result.stdout, "")
                    self.assertNotIn("first", result.stderr)
                    self.assertNotIn("tail", result.stderr)

    def test_password_stdin_is_preserved(self):
        value = "\n password\\with spaces \n\n"
        result = self.run_secret("set", "password", "example", value=value)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)[1], value)

    def read_prompt(self, process, marker):
        output = b""
        deadline = time.monotonic() + 5
        while marker not in output:
            remaining = deadline - time.monotonic()
            self.assertGreater(remaining, 0, "Prompt did not appear")
            ready, _, _ = select.select([process.stderr], [], [], remaining)
            self.assertTrue(ready, "Prompt did not appear")
            chunk = os.read(process.stderr.fileno(), 4096)
            self.assertTrue(chunk, "Process exited before the prompt")
            output += chunk
        return output

    def run_interactive(self, value, confirmation=b"\n", type_name="api-key"):
        master, slave = pty.openpty()
        self.addCleanup(os.close, master)
        self.addCleanup(os.close, slave)
        with subprocess.Popen(
            [self.bash, "-euo", "pipefail", str(self.script), "set", type_name, "orca-claude"],
            stdin=slave,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=self.env,
        ) as process:
            try:
                prompt = self.read_prompt(process, b"Value for orca-claude: ")
                os.write(master, value + b"\n")
                prompt += self.read_prompt(process, b"Press Enter to save, or type n to cancel: ")
                ready, _, _ = select.select([process.stdout], [], [], 0)
                self.assertFalse(ready, "Keyring accessed before confirmation")
                os.write(master, confirmation)
                stdout, stderr = process.communicate(timeout=5)
                terminal = b""
                ready, _, _ = select.select([master], [], [], 0)
                if ready:
                    terminal = os.read(master, 4096)
                self.assertNotIn(value.strip(b"\r\n"), prompt + stderr + terminal)
                return process.returncode, stdout, prompt + stderr
            finally:
                if process.poll() is None:
                    process.kill()
                    process.communicate()

    def test_interactive_prompt_skips_leading_blank_lines_without_echo(self):
        status, stdout, stderr = self.run_interactive(b"\n\ntest-key\\literal")
        self.assertEqual(status, 0, stderr)
        self.assertEqual(json.loads(stdout)[1], "test-key\\literal")

    def test_interactive_preview_exposes_less_than_twenty_percent(self):
        for type_name in ("api-key", "token"):
            for length, visible in ((19, 0), (20, 0), (21, 4), (24, 4), (25, 4), (26, 5), (40, 5)):
                with self.subTest(type=type_name, length=length):
                    value = b"abcde" + b"x" * (length - 5)
                    status, stdout, stderr = self.run_interactive(value, type_name=type_name)
                    self.assertEqual(status, 0, stderr)
                    self.assertEqual(json.loads(stdout)[1], value.decode())
                    preview = value[:visible] + b"*" * (length - visible)
                    self.assertIn(b"Preview: " + preview + b"\n", stderr)
                    self.assertLess(visible / length, 0.2)

    def test_interactive_cancellation_does_not_access_keyring(self):
        for confirmation in (b"n\n", b"unexpected\n", b"\x04"):
            with self.subTest(confirmation=confirmation):
                status, stdout, _ = self.run_interactive(b"test-key", confirmation)
                self.assertEqual(status, 1)
                self.assertEqual(stdout, b"")

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
        for action in ("get", "set"):
            result = self.run_secret(action, "api-key", "claude", value="key")
            self.assertEqual(result.returncode, 1)

    def test_help(self):
        result = self.run_secret("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("api-key, token, password", result.stdout)


if __name__ == "__main__":
    unittest.main()
