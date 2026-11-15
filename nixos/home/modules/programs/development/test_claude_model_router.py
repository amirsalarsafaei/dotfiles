import concurrent.futures
import importlib.util
import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "claude_model_router", Path(__file__).with_name("claude-model-router.py")
)
router = importlib.util.module_from_spec(spec)
spec.loader.exec_module(router)


class ProviderHandler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        data = self.rfile.read(int(self.headers["Content-Length"]))
        self.server.calls.append((self.path, dict(self.headers), data))
        payload = json.loads(data)
        if payload.get("stream"):
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.end_headers()
            self.wfile.write(b"data: first\n\n")
            self.wfile.flush()
            if self.server.release.wait(5):
                self.wfile.write(b"data: second\n\n")
            return
        body = json.dumps({"model": payload["model"]}).encode()
        self.send_response(payload.get("status", 200))
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Retry-After", "3")
        self.end_headers()
        self.wfile.write(body)


class RouterTests(unittest.TestCase):
    def setUp(self):
        self.provider = ThreadingHTTPServer(("127.0.0.1", 0), ProviderHandler)
        self.provider.calls = []
        self.provider.release = threading.Event()
        base = f"http://127.0.0.1:{self.provider.server_port}"
        self.routes = {
            "glm-": (base + "/glm", "Authorization", "Bearer glm-secret"),
            "deepseek-": (base + "/deepseek", "x-api-key", "deepseek-secret"),
        }
        self.server = router.ModelRouter(self.routes, "session-secret")
        self.threads = []
        for server in (self.provider, self.server):
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            self.threads.append(thread)
        self.base = f"http://127.0.0.1:{self.server.server_port}"
        self.client = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    def tearDown(self):
        self.provider.release.set()
        for server in (self.server, self.provider):
            server.shutdown()
            server.server_close()
        for thread in self.threads:
            thread.join()

    def request(self, payload, path="/v1/messages", token="session-secret"):
        request = urllib.request.Request(
            self.base + path,
            data=json.dumps(payload).encode(),
            headers={
                "Authorization": "Bearer " + token,
                "x-api-key": "client-key-must-not-leak",
                "Content-Type": "application/json",
                "anthropic-version": "2023-06-01",
                "User-Agent": "claude-cli/test",
            },
        )
        try:
            return self.client.open(request, timeout=3)
        except urllib.error.HTTPError as error:
            return error

    def test_concurrent_models_use_separate_credentials_and_preserve_payloads(self):
        payloads = [
            {"model": model, "messages": [{"role": "user", "content": str(i)}]}
            for i, model in enumerate(["glm-5.3", "deepseek-flash"] * 4)
        ]

        def call(payload):
            with self.request(payload) as response:
                self.assertEqual(json.load(response)["model"], payload["model"])

        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(call, payloads))
        self.assertEqual(len(self.provider.calls), 8)
        for path, headers, data in self.provider.calls:
            self.assertEqual(headers["User-Agent"], "claude-cli/test")
            payload = json.loads(data)
            self.assertIn(payload, payloads)
            if path.startswith("/glm/"):
                self.assertEqual(headers["Authorization"], "Bearer glm-secret")
                self.assertNotIn("X-Api-Key", headers)
            else:
                self.assertEqual(headers["X-Api-Key"], "deepseek-secret")
                self.assertNotIn("Authorization", headers)

    def test_invalid_session_and_unknown_model_never_reach_provider(self):
        for payload, token, status in [
            ({"model": "glm-5.3"}, "wrong", 401),
            ({"model": "unconfigured-model"}, "session-secret", 400),
        ]:
            with self.request(payload, token=token) as response:
                self.assertEqual(response.code, status)
                response.read()
        self.assertEqual(self.provider.calls, [])

    def test_deepseek_only_route_rejects_glm_and_accepts_deepseek(self):
        del self.server.routes["glm-"]
        with self.request({"model": "glm-5.3"}) as response:
            self.assertEqual(response.code, 400)
            response.read()
        self.assertEqual(self.provider.calls, [])
        with self.request({"model": "deepseek-chat"}) as response:
            self.assertEqual(json.load(response)["model"], "deepseek-chat")
        self.assertEqual(len(self.provider.calls), 1)
        self.assertEqual(self.provider.calls[0][1]["X-Api-Key"], "deepseek-secret")

    def test_token_count_path_and_query_are_forwarded(self):
        with self.request(
            {"model": "deepseek-flash"}, "/v1/messages/count_tokens?beta=true"
        ) as response:
            response.read()
        self.assertEqual(
            self.provider.calls[0][0], "/deepseek/v1/messages/count_tokens?beta=true"
        )

    def test_provider_errors_and_retry_headers_reach_client(self):
        with self.request({"model": "glm-5.3", "status": 429}) as response:
            self.assertEqual(response.code, 429)
            self.assertEqual(response.headers["Retry-After"], "3")
            self.assertEqual(json.load(response), {"model": "glm-5.3"})

    def test_stream_is_delivered_before_provider_finishes(self):
        with self.request({"model": "deepseek-flash", "stream": True}) as response:
            self.assertEqual(response.readline(), b"data: first\n")
            self.assertFalse(self.provider.release.is_set())
            self.provider.release.set()
            self.assertEqual(response.read(), b"\ndata: second\n\n")

    def test_diagnostics_log_status_timing_retries_and_never_bodies_or_credentials(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "router.jsonl"
            self.server.log_path = str(path)
            self.server.progress_interval = 0
            payload = {"model": "glm-5.3", "status": 401, "messages": ["sensitive-body"]}
            for _ in range(2):
                with self.request(payload) as response:
                    response.read()
            # The server may still be flushing its final metadata after the client reads EOF.
            import time
            for _ in range(100):
                if path.exists() and path.read_text().count('"stream_end"') >= 2:
                    break
                time.sleep(.01)
            text = path.read_text()
            values = [json.loads(line) for line in text.splitlines()]
            self.assertEqual([v["attempt"] for v in values if v["event"] == "request"], [1, 2])
            self.assertTrue(any(v.get("status") == 401 for v in values))
            self.assertTrue(any(v["event"] == "first_byte" for v in values))
            self.assertTrue(any(v["event"] == "stream_progress" for v in values))
            for secret in ("sensitive-body", "glm-secret", "session-secret", "client-key-must-not-leak"):
                self.assertNotIn(secret, text)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_session_hides_provider_keys_preserves_exit_code_and_closes_listener(self):
        code = """
import os, sys
from pathlib import Path
from urllib.parse import urlsplit
assert 'ANTHROPIC_API_KEY' not in os.environ
assert 'DEEPSEEK_API_KEY' not in os.environ
assert os.environ['ANTHROPIC_AUTH_TOKEN'] != 'provider-secret'
Path(sys.argv[1]).write_text(str(urlsplit(os.environ['ANTHROPIC_BASE_URL']).port))
sys.exit(17)
"""
        with tempfile.TemporaryDirectory() as directory:
            port_file = Path(directory) / "port"
            with patch.dict(
                os.environ,
                {
                    "ANTHROPIC_API_KEY": "provider-secret",
                    "DEEPSEEK_API_KEY": "provider-secret",
                },
            ):
                status = router.run_session(
                    self.routes, [sys.executable, "-c", code, str(port_file)]
                )
            self.assertEqual(status, 17)
            with self.assertRaises(OSError):
                socket.create_connection(
                    ("127.0.0.1", int(port_file.read_text())), timeout=1
                )


class ProviderSelectionTests(unittest.TestCase):
    def test_deepseek_launch_never_loads_glm_credentials(self):
        with patch("sys.argv", ["router", "--provider", "deepseek", "--log", "", "--", "claude", "-p", "task"]), \
                patch.object(router, "load_key", return_value="deepseek-secret") as key, \
                patch.object(router, "run_session", return_value=17) as session:
            self.assertEqual(router.main(), 17)
        key.assert_called_once_with("secret-tool", "deepseek-claude")
        routes, command, _, _ = session.call_args.args
        self.assertEqual(list(routes), ["deepseek-"])
        self.assertEqual(command, ["claude", "-p", "task"])

    def test_default_launch_keeps_both_providers(self):
        with patch("sys.argv", ["router", "--log", "", "--", "claude"]), \
                patch.object(router, "load_key", side_effect=["glm-secret", "deepseek-secret"]), \
                patch.object(router, "run_session", return_value=0) as session:
            self.assertEqual(router.main(), 0)
        routes = session.call_args.args[0]
        self.assertEqual(routes["glm-"][2], "Bearer glm-secret")
        self.assertEqual(routes["deepseek-"][2], "deepseek-secret")


class KeyTests(unittest.TestCase):
    def test_standard_key_takes_precedence(self):
        with patch.object(router.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess([], 0, "standard-key\n")
            self.assertEqual(
                router.load_key("secret-tool", "glm-claude"), "standard-key"
            )
            run.assert_called_once_with(
                ["secret-tool", "lookup", "type", "api-key", "id", "glm-claude"],
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            )

    def test_legacy_keyring_fallback(self):
        with patch.object(router.subprocess, "run") as run:
            run.side_effect = [
                subprocess.CompletedProcess([], 1, ""),
                subprocess.CompletedProcess([], 0, "legacy-key\n"),
            ]
            self.assertEqual(
                router.load_key("secret-tool", "glm-claude"), "legacy-key"
            )
            self.assertEqual(
                run.call_args.args[0],
                ["secret-tool", "lookup", "service", "claude", "variant", "glm-claude"],
            )

    def test_keyring_failure_never_falls_back_to_existing_file(self):
        for failure in (OSError(), subprocess.TimeoutExpired("secret-tool", 5)):
            with self.subTest(failure=type(failure).__name__):
                with tempfile.TemporaryDirectory() as directory:
                    (Path(directory) / "glm-key").write_text("file-key\n")
                    with patch.object(router.subprocess, "run", side_effect=failure):
                        with patch.object(
                            router.Path, "home", return_value=Path(directory)
                        ):
                            with patch.object(router.Path, "read_text") as read_file:
                                with self.assertRaisesRegex(ValueError, "keyring item unavailable"):
                                    router.load_key("secret-tool", "glm-claude")
                                read_file.assert_not_called()

    def test_missing_key_reports_store_command(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(router.subprocess, "run") as run:
                run.return_value = subprocess.CompletedProcess([], 1, "")
                with patch.object(router.Path, "home", return_value=Path(directory)):
                    with self.assertRaisesRegex(
                        ValueError, "secret set api-key glm-claude"
                    ):
                        router.load_key("secret-tool", "glm-claude")


if __name__ == "__main__":
    unittest.main()
