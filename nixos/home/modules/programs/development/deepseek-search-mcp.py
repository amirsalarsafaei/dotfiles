import json
import os
import sys
import urllib.error
import urllib.request

SERVER_NAME = "deepseek-search"
SERVER_VERSION = "1.0.0"
DEFAULT_SEARCH_URL = "https://api.deepseek.com/v1/tools/search"
DEFAULT_FETCH_URL = "https://api.deepseek.com/v1/tools/fetch"
SEARCH_CONTENT_LIMIT = 20000
FETCH_CONTENT_LIMIT = 100000

TOOLS = [
    {
        "name": "search",
        "description": (
            "Search the web through DeepSeek's search API. Returns ranked results with title, "
            "URL, snippet, a longer model-oriented summary, site name, publication date, "
            "authority (0-4) and relevance (0-3). Query operators: site:, -site:, -term, "
            '"exact phrase", lang:, after:, before:.'
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Search query, 1-128 Unicode characters.",
                },
                "count": {
                    "type": "integer",
                    "minimum": 1,
                    "maximum": 50,
                    "default": 10,
                    "description": "Number of results to return.",
                },
                "need_content": {
                    "type": "boolean",
                    "default": False,
                    "description": "Include extracted page content for each result.",
                },
                "ori_question": {
                    "type": "string",
                    "description": "Original user question, 1-128 characters, to improve query understanding.",
                },
                "localization": {
                    "type": "string",
                    "description": "IP address used to localize results.",
                },
            },
            "required": ["query"],
            "additionalProperties": False,
        },
    },
    {
        "name": "fetch",
        "description": (
            "Fetch a web page through DeepSeek's fetch API and return its title and Markdown content."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "url": {
                    "type": "string",
                    "description": "Absolute HTTP or HTTPS URL, at most 8192 characters.",
                }
            },
            "required": ["url"],
            "additionalProperties": False,
        },
    },
]


def api_key():
    key = os.environ.get("DEEPSEEK_API_KEY") or os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        raise RuntimeError("DeepSeek API key not set (DEEPSEEK_API_KEY or ANTHROPIC_API_KEY)")
    return key


def endpoint(env_name, default):
    return os.environ.get(env_name) or default


def post(url, payload, timeout):
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
    )
    request.add_header("Authorization", "Bearer " + api_key())
    request.add_header("Content-Type", "application/json")
    request.add_header("User-Agent", "claude-code-deepseek-search/" + SERVER_VERSION)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")
        raise RuntimeError(f"DeepSeek API returned HTTP {error.code}: {detail}") from None
    except urllib.error.URLError as error:
        raise RuntimeError(f"DeepSeek API request failed: {error.reason}") from None
    try:
        return json.loads(body)
    except json.JSONDecodeError:
        raise RuntimeError(f"DeepSeek API returned invalid JSON: {body[:500]}") from None


def search(args):
    query = args.get("query")
    if not isinstance(query, str) or not query.strip():
        raise RuntimeError("query is required")
    payload: dict[str, object] = {"query": query}
    count = args.get("count")
    if count is not None:
        payload["count"] = count
    for field in ("ori_question", "localization"):
        value = args.get(field)
        if value:
            payload[field] = value
    if args.get("need_content"):
        payload["need_content"] = True

    data = post(endpoint("DEEPSEEK_SEARCH_URL", DEFAULT_SEARCH_URL), payload, 30)
    results = data.get("results") if isinstance(data, dict) else None
    if not isinstance(results, list):
        raise RuntimeError(f"unexpected search response: {json.dumps(data)[:500]}")
    if not results:
        return "No results."

    lines = []
    for index, result in enumerate(results, 1):
        if not isinstance(result, dict):
            continue
        lines.append(f"{index}. {result.get('title') or '(untitled)'}")
        lines.append(f"   URL: {result.get('url') or ''}")
        meta = []
        if result.get("site_name"):
            meta.append(str(result["site_name"]))
        if result.get("date"):
            meta.append(str(result["date"]))
        if result.get("authority") is not None:
            meta.append(f"authority {result['authority']}")
        if result.get("rerank_score") is not None:
            meta.append(f"relevance {result['rerank_score']}")
        if meta:
            lines.append("   " + " | ".join(meta))
        summary = result.get("summary") or result.get("snippet")
        if summary:
            lines.append("   " + str(summary).replace("\n", " ").strip())
        content = result.get("content")
        if content:
            text = str(content)
            if len(text) > SEARCH_CONTENT_LIMIT:
                text = text[:SEARCH_CONTENT_LIMIT] + f"\n[truncated at {SEARCH_CONTENT_LIMIT} characters]"
            lines.append("   Content:")
            lines.extend("   " + line for line in text.splitlines())
        lines.append("")
    return "\n".join(lines).rstrip()


def fetch(args):
    url = args.get("url")
    if not isinstance(url, str) or not url.strip():
        raise RuntimeError("url is required")
    data = post(endpoint("DEEPSEEK_FETCH_URL", DEFAULT_FETCH_URL), {"url": url}, 60)
    if not isinstance(data, dict):
        raise RuntimeError(f"unexpected fetch response: {json.dumps(data)[:500]}")
    content = data.get("content")
    if not isinstance(content, str) or not content:
        raise RuntimeError("DeepSeek fetch returned no content")
    if len(content) > FETCH_CONTENT_LIMIT:
        content = content[:FETCH_CONTENT_LIMIT] + f"\n[truncated at {FETCH_CONTENT_LIMIT} characters]"
    title = data.get("title") or ""
    return (f"# {title}\n\n" if title else "") + content


def respond(message_id, result=None, error=None):
    response = {"jsonrpc": "2.0", "id": message_id}
    if error is not None:
        response["error"] = error
    else:
        response["result"] = result
    sys.stdout.write(json.dumps(response, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def handle(request):
    method = request.get("method")
    message_id = request.get("id")
    if method == "initialize":
        params = request.get("params") or {}
        respond(
            message_id,
            {
                "protocolVersion": params.get("protocolVersion") or "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
            },
        )
    elif method == "notifications/initialized":
        return
    elif method == "ping":
        respond(message_id, {})
    elif method == "tools/list":
        respond(message_id, {"tools": TOOLS})
    elif method == "tools/call":
        params = request.get("params") or {}
        name = params.get("name")
        args = params.get("arguments") or {}
        try:
            if name == "search":
                text = search(args)
            elif name == "fetch":
                text = fetch(args)
            else:
                raise RuntimeError(f"unknown tool: {name}")
            respond(message_id, {"content": [{"type": "text", "text": text}]})
        except Exception as error:
            respond(message_id, {"content": [{"type": "text", "text": str(error)}], "isError": True})
    elif message_id is not None:
        respond(message_id, error={"code": -32601, "message": f"method not found: {method}"})


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
        except json.JSONDecodeError:
            sys.stderr.write("deepseek-search-mcp: ignoring invalid JSON\n")
            continue
        if not isinstance(request, dict):
            continue
        try:
            handle(request)
        except Exception as error:
            sys.stderr.write(f"deepseek-search-mcp: {error}\n")
            message_id = request.get("id")
            if message_id is not None:
                respond(message_id, error={"code": -32603, "message": str(error)})


if __name__ == "__main__":
    main()
