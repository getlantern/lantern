import { writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

import { chromium } from 'playwright-core';

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const maxDiagnosticEvents = 1000;

class StripeE2EError extends Error {
  constructor(code) {
    super(code);
    this.name = 'StripeE2EError';
    this.code = code;
  }
}

export function sanitizedOrigin(rawURL) {
  try {
    const url = new URL(rawURL);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') {
      return '<opaque>';
    }
    return url.origin;
  } catch {
    return '<invalid>';
  }
}

function parseDecimalInteger(value, fallback = '') {
  const rawValue = value ?? fallback;
  return /^\d+$/.test(rawValue) ? Number(rawValue) : Number.NaN;
}

export function parseArguments(argv) {
  const allowed = new Set([
    '--port',
    '--timeout-seconds',
    '--run-id',
    '--email',
    '--output',
  ]);
  const values = new Map();
  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index];
    const value = argv[index + 1];
    if (!allowed.has(key) || value === undefined) {
      throw new StripeE2EError('invalid_arguments');
    }
    if (values.has(key)) {
      throw new StripeE2EError('duplicate_argument');
    }
    values.set(key, value);
  }

  const port = parseDecimalInteger(values.get('--port'));
  const timeoutSeconds = parseDecimalInteger(
    values.get('--timeout-seconds'),
    '180',
  );
  const runID = values.get('--run-id') ?? '';
  const email = values.get('--email') ?? '';
  const output = values.get('--output') ?? '';
  if (
    !Number.isInteger(port) ||
    port < 1024 ||
    port > 65535 ||
    !Number.isInteger(timeoutSeconds) ||
    timeoutSeconds < 30 ||
    timeoutSeconds > 300 ||
    !uuidPattern.test(runID) ||
    email.toLowerCase() !== `e2e+${runID.toLowerCase()}@getlantern.org` ||
    output.trim() === ''
  ) {
    throw new StripeE2EError('invalid_arguments');
  }
  return { port, timeoutSeconds, runID, email, output };
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function createDiagnostics() {
  const events = [];
  return {
    events,
    record(event) {
      if (events.length >= maxDiagnosticEvents) return;
      events.push({ timestamp: new Date().toISOString(), ...event });
    },
  };
}

function instrumentPage(page, diagnostics) {
  page.on('console', (message) => {
    diagnostics.record({
      event: 'console',
      type: message.type(),
      origin: sanitizedOrigin(message.location().url),
    });
  });
  page.on('pageerror', (error) => {
    diagnostics.record({
      event: 'page_error',
      errorType: error?.name || 'Error',
    });
  });
  page.on('request', (request) => {
    diagnostics.record({
      event: 'request',
      method: request.method(),
      resourceType: request.resourceType(),
      origin: sanitizedOrigin(request.url()),
    });
  });
  page.on('response', (response) => {
    diagnostics.record({
      event: 'response',
      status: response.status(),
      resourceType: response.request().resourceType(),
      origin: sanitizedOrigin(response.url()),
    });
  });
  page.on('requestfailed', (request) => {
    diagnostics.record({
      event: 'request_failed',
      method: request.method(),
      resourceType: request.resourceType(),
      origin: sanitizedOrigin(request.url()),
    });
  });
}

async function connectToWebView(port, deadline, diagnostics) {
  const endpoint = `http://127.0.0.1:${port}`;
  while (Date.now() < deadline) {
    try {
      const browser = await chromium.connectOverCDP(endpoint, {
        timeout: Math.min(5000, Math.max(1, deadline - Date.now())),
      });
      diagnostics.record({ event: 'cdp_connected' });
      return browser;
    } catch {
      await sleep(500);
    }
  }
  throw new StripeE2EError('cdp_connection_timeout');
}

function allPages(browser) {
  return browser.contexts().flatMap((context) => context.pages());
}

async function waitForStripeCheckout(browser, deadline, diagnostics) {
  const instrumentedPages = new WeakSet();
  while (Date.now() < deadline) {
    for (const page of allPages(browser)) {
      if (!instrumentedPages.has(page)) {
        instrumentedPages.add(page);
        instrumentPage(page, diagnostics);
      }
      if (sanitizedOrigin(page.url()) === 'https://checkout.stripe.com') {
        diagnostics.record({ event: 'stripe_checkout_attached' });
        return page;
      }
    }
    await sleep(250);
  }
  throw new StripeE2EError('stripe_checkout_target_timeout');
}

async function assertStripeTestMode(page, deadline, diagnostics) {
  while (Date.now() < deadline) {
    try {
      const pathname = new URL(page.url()).pathname;
      if (pathname.includes('cs_test_')) {
        diagnostics.record({ event: 'stripe_test_mode_confirmed' });
        return;
      }
    } catch {
      // The Checkout URL can change while the page is loading.
    }
    for (const frame of page.frames()) {
      try {
        const badge = frame.getByText(/test mode/i).first();
        if ((await badge.count()) > 0 && (await badge.isVisible())) {
          diagnostics.record({ event: 'stripe_test_mode_confirmed' });
          return;
        }
      } catch {
        // Checkout can replace the frame while we inspect it.
      }
    }
    await sleep(250);
  }
  throw new StripeE2EError('stripe_test_mode_not_confirmed');
}

async function visibleLocator(page, selectors) {
  for (const frame of page.frames()) {
    for (const selector of selectors) {
      try {
        const locator = frame.locator(selector).first();
        if ((await locator.count()) > 0 && (await locator.isVisible())) {
          return locator;
        }
      } catch {
        // Checkout can replace the frame while we inspect it.
      }
    }
  }
  return null;
}

async function fillRequired(page, selectors, value, code) {
  const locator = await visibleLocator(page, selectors);
  if (!locator) throw new StripeE2EError(code);
  await locator.fill(value);
}

async function fillOptional(page, selectors, value) {
  const locator = await visibleLocator(page, selectors);
  if (locator) await locator.fill(value);
}

async function fillStripeCheckout(page, email) {
  await fillOptional(
    page,
    ['input[type="email"]', 'input[autocomplete="email"]'],
    email,
  );
  await fillRequired(
    page,
    [
      '#cardNumber',
      'input[name="cardnumber"]',
      'input[autocomplete="cc-number"]',
      'input[aria-label*="card number" i]',
    ],
    '4242424242424242',
    'card_number_field_not_found',
  );
  await fillRequired(
    page,
    [
      '#cardExpiry',
      'input[name="exp-date"]',
      'input[autocomplete="cc-exp"]',
      'input[aria-label*="expiration" i]',
    ],
    '12/34',
    'expiry_field_not_found',
  );
  await fillRequired(
    page,
    [
      '#cardCvc',
      'input[name="cvc"]',
      'input[autocomplete="cc-csc"]',
      'input[aria-label*="security code" i]',
      'input[aria-label*="cvc" i]',
    ],
    '123',
    'cvc_field_not_found',
  );
  await fillOptional(
    page,
    ['input[autocomplete="cc-name"]', 'input[name="name"]'],
    'Lantern E2E',
  );
  await fillOptional(
    page,
    [
      'input[autocomplete="postal-code"]',
      'input[name="postalCode"]',
      'input[aria-label*="postal" i]',
      'input[aria-label*="zip" i]',
    ],
    '94107',
  );
}

async function findSubmitButton(page) {
  const names = [/^subscribe$/i, /^pay(?:\s|$)/i, /^start trial$/i];
  for (const frame of page.frames()) {
    for (const name of names) {
      try {
        const button = frame.getByRole('button', { name }).first();
        if (
          (await button.count()) > 0 &&
          (await button.isVisible()) &&
          (await button.isEnabled())
        ) {
          return button;
        }
      } catch {
        // Checkout can replace the frame while we inspect it.
      }
    }
  }
  return visibleLocator(page, ['button[type="submit"]']);
}

async function waitForCheckoutCompletion(page, deadline, diagnostics) {
  while (Date.now() < deadline) {
    if (page.isClosed()) {
      diagnostics.record({ event: 'checkout_target_closed' });
      return { callbackOriginObserved: false, targetClosed: true };
    }
    const origin = sanitizedOrigin(page.url());
    if (origin === 'https://lantern.io' || origin === 'https://www.lantern.io') {
      diagnostics.record({ event: 'lantern_callback_observed', origin });
      return { callbackOriginObserved: true, targetClosed: false };
    }
    const alert = await visibleLocator(page, ['[role="alert"]']);
    if (alert) throw new StripeE2EError('stripe_checkout_reported_error');
    await sleep(250);
  }
  throw new StripeE2EError('stripe_checkout_completion_timeout');
}

async function writeResult(path, result, diagnostics) {
  await writeFile(
    path,
    `${JSON.stringify({ ...result, diagnostics: diagnostics.events }, null, 2)}\n`,
    { encoding: 'utf8' },
  );
}

export async function run(argv) {
  const diagnostics = createDiagnostics();
  let options;
  let stage = 'arguments';
  try {
    options = parseArguments(argv);
    const deadline = Date.now() + options.timeoutSeconds * 1000;
    stage = 'cdp_connect';
    const browser = await connectToWebView(options.port, deadline, diagnostics);
    stage = 'stripe_target';
    const page = await waitForStripeCheckout(browser, deadline, diagnostics);
    stage = 'stripe_test_mode';
    await assertStripeTestMode(
      page,
      Math.min(deadline, Date.now() + 15000),
      diagnostics,
    );
    stage = 'stripe_fields';
    await fillStripeCheckout(page, options.email);
    diagnostics.record({ event: 'stripe_fields_completed' });
    stage = 'stripe_submit';
    const submit = await findSubmitButton(page);
    if (!submit) throw new StripeE2EError('submit_button_not_found');
    await submit.click();
    diagnostics.record({ event: 'stripe_checkout_submitted' });
    stage = 'stripe_completion';
    const completion = await waitForCheckoutCompletion(
      page,
      deadline,
      diagnostics,
    );
    await writeResult(
      options.output,
      {
        success: true,
        runId: options.runID,
        checkoutSubmitted: true,
        ...completion,
      },
      diagnostics,
    );
  } catch (error) {
    const code =
      error instanceof StripeE2EError ? error.code : 'unexpected_helper_error';
    if (options?.output) {
      await writeResult(
        options.output,
        { success: false, runId: options.runID, stage, errorCode: code },
        diagnostics,
      );
    }
    console.error(`Stripe CDP helper failed at ${stage}: ${code}`);
    process.exitCode = 1;
  }
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  await run(process.argv.slice(2));
}
