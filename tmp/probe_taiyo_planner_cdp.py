import asyncio
import base64
import json
import os
import pathlib
import subprocess
import time
import urllib.request
import urllib.parse

import requests
import websockets


ROOT = pathlib.Path(__file__).resolve().parents[1]
APP_URL = os.environ.get("APP_URL", "http://127.0.0.1:54320")
DEBUG_PORT = int(os.environ.get("CDP_PORT", "9223"))
USER_DATA_DIR = ROOT / "tmp" / "chrome-taiyo-probe-profile"
SCREENSHOT = ROOT / "tmp" / "taiyo-planner-cdp-probe.png"


def read_dotenv():
    values = {}
    env_path = ROOT / ".env"
    if not env_path.exists():
        return values
    for raw in env_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value
    return values


def sign_in():
    env = read_dotenv()
    supabase_url = env.get("SUPABASE_URL")
    anon_key = env.get("SUPABASE_ANON_KEY")
    email = os.environ.get("MEMBER_EMAIL")
    password = os.environ.get("MEMBER_PASSWORD")
    if not all([supabase_url, anon_key, email, password]):
        raise RuntimeError("missing required probe environment")
    response = requests.post(
        f"{supabase_url}/auth/v1/token?grant_type=password",
        headers={"apikey": anon_key, "Content-Type": "application/json"},
        json={"email": email, "password": password},
        timeout=30,
    )
    if response.status_code >= 400:
        raise RuntimeError(f"member sign-in failed: HTTP {response.status_code}")
    storage_key = (
        f"sb-{urllib.parse.urlparse(supabase_url).hostname.split('.')[0]}-auth-token"
    )
    return storage_key, response.json()


def launch_chrome():
    chrome_env = os.environ.get("CHROME_EXE", "").strip()
    chrome = pathlib.Path(chrome_env) if chrome_env else pathlib.Path("__missing__")
    if not chrome.exists() or chrome.is_dir():
        chrome = pathlib.Path(
            r"C:\Program Files\Google\Chrome\Application\chrome.exe"
        )
    if not chrome.exists():
        chrome = (
            pathlib.Path(os.environ.get("LOCALAPPDATA", ""))
            / "ms-playwright"
            / "chromium-1208"
            / "chrome-win64"
            / "chrome.exe"
        )
    if not chrome.exists():
        raise RuntimeError("chrome executable not found")
    USER_DATA_DIR.mkdir(parents=True, exist_ok=True)
    return subprocess.Popen(
        [
            str(chrome),
            f"--remote-debugging-port={DEBUG_PORT}",
            f"--user-data-dir={USER_DATA_DIR}",
            "--headless=new",
            "--disable-gpu",
            "--no-first-run",
            "--no-default-browser-check",
            "about:blank",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def wait_for_cdp():
    endpoint = f"http://127.0.0.1:{DEBUG_PORT}/json/version"
    deadline = time.time() + 20
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(endpoint, timeout=1) as response:
                return json.loads(response.read().decode("utf-8"))[
                    "webSocketDebuggerUrl"
                ]
        except Exception:
            time.sleep(0.25)
    raise RuntimeError("chrome devtools endpoint did not start")


class Cdp:
    def __init__(self, ws):
        self.ws = ws
        self.next_id = 1

    async def call(self, method, params=None):
        message_id = self.next_id
        self.next_id += 1
        await self.ws.send(
            json.dumps({"id": message_id, "method": method, "params": params or {}})
        )
        while True:
            raw = await self.ws.recv()
            data = json.loads(raw)
            if data.get("id") == message_id:
                if "error" in data:
                    raise RuntimeError(f"{method} failed: {data['error']}")
                return data.get("result", {})


async def run_probe(storage_key, session):
    browser_ws = wait_for_cdp()
    async with websockets.connect(browser_ws, max_size=20_000_000) as ws:
        browser = Cdp(ws)
        target = await browser.call("Target.createTarget", {"url": f"{APP_URL}/"})
        session_result = await browser.call(
            "Target.attachToTarget",
            {"targetId": target["targetId"], "flatten": True},
        )
        sid = session_result["sessionId"]

        async def call(method, params=None):
            message_id = browser.next_id
            browser.next_id += 1
            await ws.send(
                json.dumps(
                    {
                        "id": message_id,
                        "sessionId": sid,
                        "method": method,
                        "params": params or {},
                    }
                )
            )
            while True:
                raw = await ws.recv()
                data = json.loads(raw)
                if data.get("id") == message_id:
                    if "error" in data:
                        raise RuntimeError(f"{method} failed: {data['error']}")
                    return data.get("result", {})
                if data.get("sessionId") == sid and "method" in data:
                    event_log.append(
                        {
                            "method": data.get("method"),
                            "params": data.get("params", {}),
                        }
                    )

        event_log = []
        await call("Runtime.enable")
        await call("Log.enable")
        await call("Page.enable")
        await call(
            "Emulation.setDeviceMetricsOverride",
            {
                "width": 1000,
                "height": 1400,
                "deviceScaleFactor": 1,
                "mobile": False,
            },
        )
        await asyncio.sleep(3)
        await call(
            "Runtime.evaluate",
            {
                "expression": (
                    "window.localStorage.setItem("
                    + json.dumps(storage_key)
                    + ", "
                    + json.dumps(json.dumps(session))
                    + ");"
                ),
                "awaitPromise": True,
            },
        )
        await call("Page.navigate", {"url": f"{APP_URL}/"})
        await asyncio.sleep(10)
        route = os.environ.get("PROBE_ROUTE", "#/ai-planner-builder")
        await call("Page.navigate", {"url": f"{APP_URL}/{route}"})
        await asyncio.sleep(5)
        for point in parse_clicks(os.environ.get("PROBE_CLICKS", "")):
            await click(call, point[0], point[1])
            await asyncio.sleep(point[2])
        if os.environ.get("PROBE_CLICK_START") == "1":
            await click(
                call,
                int(os.environ.get("PROBE_START_X", "500")),
                int(os.environ.get("PROBE_START_Y", "320")),
            )
            await asyncio.sleep(3)
        next_count = int(os.environ.get("PROBE_NEXT_COUNT", "0"))
        next_x = int(os.environ.get("PROBE_NEXT_X", "560"))
        next_y = int(os.environ.get("PROBE_NEXT_Y", "453"))
        for _ in range(next_count):
            await click(call, next_x, next_y)
            await asyncio.sleep(1)
        text = await call(
            "Runtime.evaluate",
            {"expression": "document.body.innerText || ''", "returnByValue": True},
        )
        dom_info = await call(
            "Runtime.evaluate",
            {
                "expression": """
JSON.stringify({
  readyState: document.readyState,
  bodyLength: document.body ? document.body.innerHTML.length : 0,
  canvasCount: document.querySelectorAll('canvas').length,
  glassPaneCount: document.querySelectorAll('flt-glass-pane').length,
  scripts: Array.from(document.scripts).map(s => s.src || s.textContent.slice(0, 40)).slice(-5)
})
""",
                "returnByValue": True,
            },
        )
        screenshot = await call("Page.captureScreenshot", {"format": "png"})
        SCREENSHOT.write_bytes(base64.b64decode(screenshot["data"]))
        return {
            "signed_in": True,
            "url": (
                await call(
                    "Runtime.evaluate",
                    {"expression": "location.href", "returnByValue": True},
                )
            )["result"]["value"],
            "text_sample": text["result"].get("value", "")[:500],
            "dom": json.loads(dom_info["result"].get("value", "{}")),
            "events": summarize_events(event_log),
            "screenshot": str(SCREENSHOT.relative_to(ROOT)),
        }


async def click(call, x, y):
    await call(
        "Input.dispatchMouseEvent",
        {"type": "mousePressed", "x": x, "y": y, "button": "left", "clickCount": 1},
    )
    await call(
        "Input.dispatchMouseEvent",
        {"type": "mouseReleased", "x": x, "y": y, "button": "left", "clickCount": 1},
    )


def parse_clicks(raw):
    points = []
    for item in raw.split(";"):
        if not item.strip():
            continue
        parts = [part.strip() for part in item.split(",")]
        if len(parts) < 2:
            continue
        delay = float(parts[2]) if len(parts) > 2 else 2.0
        points.append((int(parts[0]), int(parts[1]), delay))
    return points


def summarize_events(events):
    summarized = []
    for event in events:
        method = event.get("method")
        params = event.get("params", {})
        if method == "Runtime.exceptionThrown":
            details = params.get("exceptionDetails", {})
            summarized.append(
                {
                    "method": method,
                    "text": str(details.get("text", ""))[:220],
                    "url": str(details.get("url", ""))[:120],
                }
            )
        elif method == "Log.entryAdded":
            entry = params.get("entry", {})
            summarized.append(
                {
                    "method": method,
                    "level": entry.get("level"),
                    "text": str(entry.get("text", ""))[:220],
                    "url": str(entry.get("url", ""))[:120],
                }
            )
    return summarized[-12:]


def main():
    storage_key, session = sign_in()
    proc = launch_chrome()
    try:
        result = asyncio.run(run_probe(storage_key, session))
        print(json.dumps(result))
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()


if __name__ == "__main__":
    main()
