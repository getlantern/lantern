import assert from 'node:assert/strict';
import test from 'node:test';

import { parseArguments, sanitizedOrigin } from './stripe_checkout_cdp.mjs';

const runID = '9a1632f8-5b33-4d6f-8a42-7a8a4f77d829';

test('sanitizedOrigin excludes paths, query strings, and fragments', () => {
  assert.equal(
    sanitizedOrigin(
      'https://checkout.stripe.com/c/pay/cs_test_secret?client_secret=secret#frag',
    ),
    'https://checkout.stripe.com',
  );
  assert.equal(sanitizedOrigin('data:text/plain,secret'), '<opaque>');
  assert.equal(sanitizedOrigin('not a URL'), '<invalid>');
});

test('parseArguments accepts only the tagged E2E identity', () => {
  assert.deepEqual(
    parseArguments([
      '--port',
      '9222',
      '--run-id',
      runID,
      '--email',
      `e2e+${runID}@getlantern.org`,
      '--output',
      'result.json',
      '--timeout-seconds',
      '180',
    ]),
    {
      port: 9222,
      timeoutSeconds: 180,
      runID,
      email: `e2e+${runID}@getlantern.org`,
      output: 'result.json',
    },
  );
  assert.throws(
    () =>
      parseArguments([
        '--port',
        '9222',
        '--run-id',
        runID,
        '--email',
        'someone@example.com',
        '--output',
        'result.json',
      ]),
    /invalid_arguments/,
  );
});
