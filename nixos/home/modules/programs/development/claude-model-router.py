import argparse
from datetime import datetime, timezone
import hashlib
import http.client
import json
import os
import secrets
import signal
import subprocess
import sys
import threading
import time
import uuid
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class ModelRouter(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, routes, token, log_path=None, provider_timeout=600):
        self.routes = routes
        self.log_path = log_path
        self.provider_timeout = provider_timeout
        self.log_lock = threading.Lock()
        self.attempts = {}
        self.progress_interval = 30
        self.token = token
        self.opener = urllib.request.build_opener(NoRedirect)
        super().__init__(("127.0.0.1", 0), RouterHandler)


    def event(self, event, **fields):
        if not self.log_path:
            return
        value = dict(event=event, timestamp=datetime.now(timezone.utc).isoformat(), **fields)
        with self.log_lock:
            fd = os.open(self.log_path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
            with os.fdopen(fd, "a") as out:
                out.write(json.dumps(value, sort_keys=True) + "\n")


class RouterHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def setup(self):
        super().setup()
        self.connection.settimeout(30)

    def fail(self, status, message):
        data = json.dumps(
            {
                "type": "error",
                "error": {
                    "type": "invalid_request_error",
                    "message": message,
                },
            }
        ).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        self.wfile.write(data)

    def do_POST(self):
        auth = self.headers.get("Authorization", "")
        key = self.headers.get("x-api-key", "")
        if not (
            secrets.compare_digest(
                auth.encode(), ("Bearer " + self.server.token).encode()
            )
            or secrets.compare_digest(key.encode(), self.server.token.encode())
        ):
            self.fail(401, "Invalid session token")
            return
        path = urlsplit(self.path)
        if path.path not in ("/v1/messages", "/v1/messages/count_tokens"):
            self.fail(404, "Unsupported API path")
            return
        if self.headers.get("Transfer-Encoding"):
            self.fail(400, "Content-Length required")
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            size = 0
        if not 0 < size <= 64 * 1024 * 1024:
            self.fail(413, "Request body must be between 1 byte and 64 MiB")
            return
        try:
            body = self.rfile.read(size)
            data = json.loads(body)
            model = data.get("model", "")
            if not isinstance(model, str):
                raise TypeError
        except (ValueError, TypeError, AttributeError):
            self.fail(400, "Expected a JSON object with a model name")
            return
        route = next(
            (
                value
                for prefix, value in self.server.routes.items()
                if model.startswith(prefix)
            ),
            None,
        )
        if route is None:
            self.fail(400, "No provider configured for this model")
            return
        base_url, auth_name, auth_value = route
        headers = {
            name: value
            for name, value in self.headers.items()
            if name.lower()
            in (
                "content-type",
                "anthropic-version",
                "anthropic-beta",
                "user-agent",
                "x-app",
            )
            or name.lower().startswith("x-stainless-")
        }
        headers[auth_name] = auth_value
        headers["Accept-Encoding"] = "identity"
        url = base_url.rstrip("/") + path.path
        if path.query:
            url += "?" + path.query
        request_id = uuid.uuid4().hex
        started = time.monotonic()
        fingerprint = hashlib.sha256(body).hexdigest()
        with self.server.log_lock:
            attempt = self.server.attempts.get(fingerprint, 0) + 1
            # Bound diagnostic bookkeeping over long sessions.
            if len(self.server.attempts) > 4096:
                self.server.attempts.clear()
            self.server.attempts[fingerprint] = attempt
        self.server.event("request", request_id=request_id, model=model[:128],
                          provider=urlsplit(base_url).hostname, attempt=attempt,
                          streaming=bool(data.get("stream")))
        request = urllib.request.Request(url, data=body, headers=headers, method="POST")
        try:
            try:
                response = self.server.opener.open(request, timeout=self.server.provider_timeout)
            except urllib.error.HTTPError as error:
                response = error
        except (urllib.error.URLError, OSError) as error:
            self.server.event("connection_error", request_id=request_id, error=type(error).__name__,
                              elapsed_ms=round((time.monotonic() - started) * 1000))
            self.fail(502, "Provider connection failed")
            return
        with response:
            self.server.event("provider_status", request_id=request_id, status=response.code,
                              elapsed_ms=round((time.monotonic() - started) * 1000))
            self.send_response(response.code)
            for name in (
                "Content-Type",
                "Content-Length",
                "Content-Encoding",
                "Retry-After",
                "Request-Id",
            ):
                if response.headers.get(name) is not None:
                    self.send_header(name, response.headers[name])
            self.send_header("Connection", "close")
            self.end_headers()
            self.close_connection = True
            sent = 0
            last_progress = time.monotonic()
            try:
                while chunk := response.read1(65536):
                    if not sent:
                        self.server.event("first_byte", request_id=request_id,
                                          elapsed_ms=round((time.monotonic() - started) * 1000))
                    sent += len(chunk)
                    self.wfile.write(chunk)
                    self.wfile.flush()
                    if time.monotonic() - last_progress >= self.server.progress_interval:
                        self.server.event("stream_progress", request_id=request_id, bytes=sent,
                                          elapsed_ms=round((time.monotonic() - started) * 1000))
                        last_progress = time.monotonic()
                self.server.event("stream_end", request_id=request_id, bytes=sent,
                                  elapsed_ms=round((time.monotonic() - started) * 1000))
            except (OSError, ValueError, http.client.HTTPException) as error:
                self.server.event("stream_abort", request_id=request_id, bytes=sent,
                                  error=type(error).__name__,
                                  elapsed_ms=round((time.monotonic() - started) * 1000))


def load_key(secret_tool, variant):
    for attributes in (
        ["type", "api-key", "id", variant],
        ["service", "claude", "variant", variant],
    ):
        try:
            result = subprocess.run(
                [secret_tool, "lookup", *attributes],
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            )
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout.strip()
        except (OSError, subprocess.TimeoutExpired):
            pass
    raise ValueError(
        f"{variant}: keyring item unavailable; unlock the keyring or "
        f"run secret set api-key {variant}"
    )


def run_session(routes, command, log_path=None, provider_timeout=600):
    token = secrets.token_urlsafe(32)
    with ModelRouter(routes, token, log_path, provider_timeout) as server:
        server.event("session_start", main_model=os.environ.get("ANTHROPIC_MODEL", ""),
                     subagent_model=os.environ.get("CLAUDE_CODE_SUBAGENT_MODEL", ""))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        env = os.environ.copy()
        for name in (
            "ANTHROPIC_API_KEY",
            "ANTHROPIC_AUTH_TOKEN",
            "DEEPSEEK_API_KEY",
            "ZAI_API_KEY",
        ):
            env.pop(name, None)
        env["ANTHROPIC_BASE_URL"] = f"http://127.0.0.1:{server.server_port}"
        env["ANTHROPIC_AUTH_TOKEN"] = token
        env["NO_PROXY"] = ",".join(
            filter(
                None,
                (
                    env.get("NO_PROXY", env.get("no_proxy", "")),
                    "127.0.0.1",
                    "localhost",
                ),
            )
        )
        env["no_proxy"] = env["NO_PROXY"]
        child = None

        def terminate(signum, frame):
            if child is not None:
                child.terminate()

        previous_int = signal.signal(signal.SIGINT, lambda signum, frame: None)
        previous_term = signal.signal(signal.SIGTERM, terminate)
        try:
            child = subprocess.Popen(command, env=env)
            status = child.wait()
            return status if status >= 0 else 128 - status
        finally:
            signal.signal(signal.SIGINT, previous_int)
            signal.signal(signal.SIGTERM, previous_term)
            server.shutdown()
            thread.join()


def main():
    parser = argparse.ArgumentParser(
        description="Run Claude with GLM and DeepSeek model routing"
    )
    parser.add_argument("--secret-tool", default="secret-tool")
    parser.add_argument("--provider", choices=("mixed", "deepseek"), default="mixed")
    parser.add_argument("--log", default=os.environ.get("ROUTER_LOG"))
    parser.add_argument("--provider-timeout", type=float, default=float(os.environ.get("ROUTER_TIMEOUT", 600)))
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command
    if command[:1] == ["--"]:
        command = command[1:]
    if not command:
        parser.error("a command is required after --")
    try:
        routes = {}
        if args.provider == "mixed":
            glm_key = load_key(args.secret_tool, "glm-claude")
            routes["glm-"] = (
                "https://api.z.ai/api/anthropic",
                "Authorization",
                f"Bearer {glm_key}",
            )
        deepseek_key = load_key(args.secret_tool, "deepseek-claude")
        routes["deepseek-"] = (
            "https://api.deepseek.com/anthropic",
            "x-api-key",
            deepseek_key,
        )
        if args.provider_timeout <= 0:
            raise ValueError("provider timeout must be positive")
        if args.log:
            Path(args.log).parent.mkdir(parents=True, exist_ok=True)
        return run_session(routes, command, args.log, args.provider_timeout)
    except (ValueError, OSError) as error:
        launcher = "hunt-deepseek" if args.provider == "deepseek" else "hunt-claude"
        print(f"{launcher}: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
