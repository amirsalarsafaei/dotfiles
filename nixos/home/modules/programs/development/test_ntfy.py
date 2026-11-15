import http.server
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest


class NtfyTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.script = Path(self.directory.name) / 'ntfy'
        source = Path(__file__).with_name('ntfy.nix').read_text()
        source = source.split("    text = ''\n", 1)[1].split("\n    '';", 1)[0]
        source = source.replace('${cfg.defaultTopic}', 'test')
        source = source.replace('${cfg.server}', 'http://127.0.0.1:1')
        source = source.replace('${sopsTokenFile}', '').replace("''${", '${')
        # Nix indented strings remove the common indentation, including heredocs.
        source = '\n'.join(line[6:] if line.startswith('      ') else line
                           for line in source.splitlines())
        self.script.write_text('set -euo pipefail\n' + source + '\n')
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith('NTFY_')}

    def test_token_and_body_reach_server_without_entering_curl_argv(self):
        received = threading.Event()
        release = threading.Event()
        request = {}

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                request['token'] = self.headers.get('Authorization')
                request['body'] = self.rfile.read(int(self.headers['Content-Length']))
                received.set()
                release.wait(5)
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'{}')

            def log_message(self, *args):
                pass

        with http.server.HTTPServer(('127.0.0.1', 0), Handler) as server:
            worker = threading.Thread(target=server.handle_request, daemon=True)
            worker.start()
            token = 'test-private-bearer-token'
            body = 'test-private-message'
            env = self.env | {'NTFY_TOKEN': token}
            with subprocess.Popen(
                ['bash', str(self.script), '--server',
                 f'http://127.0.0.1:{server.server_port}', '--verbose'],
                env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            ) as process:
                process.stdin.write(body.encode())
                process.stdin.close()
                process.stdin = None
                try:
                    self.assertTrue(received.wait(5), 'curl did not send the request')
                    argv = Path(f'/proc/{process.pid}/cmdline').read_bytes()
                    environment = Path(f'/proc/{process.pid}/environ').read_bytes()
                    self.assertNotIn(token.encode(), argv)
                    self.assertNotIn(body.encode(), argv)
                    self.assertNotIn(token.encode(), environment)
                finally:
                    release.set()
                    stdout, stderr = process.communicate(timeout=5)
                self.assertEqual(process.returncode, 0, stderr)
                self.assertNotIn(token.encode(), stdout + stderr)
                self.assertIn(b'HTTP 200', stdout)
            worker.join(timeout=5)
            self.assertEqual(request, {'token': f'Bearer {token}', 'body': body.encode()})

    def test_unsafe_token_argument_is_rejected_without_echoing_it(self):
        result = subprocess.run(
            ['bash', str(self.script), '--token', 'private-test-token', 'message'],
            env=self.env, capture_output=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(b'private-test-token', result.stdout + result.stderr)

    def test_missing_file_and_header_injection_fail_closed(self):
        for args, env in [
            (['--token-file', '/nonexistent/ntfy-token'], self.env),
            ([], self.env | {'NTFY_TOKEN': 'secret\r\nInjected: value'}),
        ]:
            with self.subTest(args=args):
                result = subprocess.run(
                    ['bash', str(self.script), *args, 'message'], env=env,
                    capture_output=True,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn(b'Injected', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
