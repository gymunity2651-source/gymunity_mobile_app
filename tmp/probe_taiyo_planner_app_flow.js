const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

function readDotEnv(filePath) {
  const result = {};
  if (!fs.existsSync(filePath)) return result;
  for (const line of fs.readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const index = trimmed.indexOf('=');
    if (index <= 0) continue;
    result[trimmed.slice(0, index)] = trimmed.slice(index + 1);
  }
  return result;
}

async function signIn({ supabaseUrl, anonKey, email, password }) {
  const response = await fetch(
    `${supabaseUrl}/auth/v1/token?grant_type=password`,
    {
      method: 'POST',
      headers: {
        apikey: anonKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email, password }),
    },
  );
  if (!response.ok) {
    throw new Error(`member sign-in failed: HTTP ${response.status}`);
  }
  return response.json();
}

async function main() {
  const env = readDotEnv(path.join(process.cwd(), '.env'));
  const supabaseUrl = env.SUPABASE_URL;
  const anonKey = env.SUPABASE_ANON_KEY;
  const email = process.env.MEMBER_EMAIL;
  const password = process.env.MEMBER_PASSWORD;
  if (!supabaseUrl || !anonKey || !email || !password) {
    throw new Error('missing required probe environment');
  }

  const session = await signIn({ supabaseUrl, anonKey, email, password });
  const storageKey = `sb-${new URL(supabaseUrl).host.split('.')[0]}-auth-token`;
  const appUrl = process.env.APP_URL || 'http://127.0.0.1:54320';
  const functionCalls = [];

  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 1600 },
  });
  await context.addInitScript(
    ({ key, value }) => {
      window.localStorage.setItem(key, value);
    },
    { key: storageKey, value: JSON.stringify(session) },
  );
  const page = await context.newPage();
  page.on('response', async (response) => {
    const url = response.url();
    if (!url.includes('/functions/v1/taiyo-workout-planner')) return;
    let summary = null;
    try {
      const json = await response.json();
      summary = {
        status: json.status,
        request_type: json.request_type,
        draft_id_present: Boolean(json.metadata?.draft_id || json.draft_id),
        session_id_present: Boolean(
          json.metadata?.session_id || json.session_id,
        ),
        persisted: json.metadata?.persisted,
        activation_allowed: json.result?.activation_allowed,
        confidence: json.data_quality?.confidence,
      };
    } catch (_) {
      summary = { parse_error: true };
    }
    functionCalls.push({ status: response.status(), summary });
  });

  await page.goto(`${appUrl}/#/ai-planner-builder`, {
    waitUntil: 'networkidle',
    timeout: 60000,
  });
  await page.waitForTimeout(5000);
  await page.screenshot({
    path: path.join(process.cwd(), 'tmp', 'taiyo-planner-app-probe.png'),
    fullPage: true,
  });

  const text = await page.locator('body').innerText().catch(() => '');
  console.log(
    JSON.stringify({
      signed_in: true,
      url: page.url(),
      text_sample: text.slice(0, 500),
      function_calls: functionCalls,
      screenshot: 'tmp/taiyo-planner-app-probe.png',
    }),
  );

  await browser.close();
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
