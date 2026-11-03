// Access token of the Worker's service account (Firestore + FCM). Signing costs CPU, so
// the token is reused while the isolate lives.

const SCOPES = [
  'https://www.googleapis.com/auth/firebase.messaging',
  'https://www.googleapis.com/auth/datastore',
].join(' ');

const b64url = (bytes) =>
  btoa(String.fromCharCode(...new Uint8Array(bytes)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

const textB64url = (text) => b64url(new TextEncoder().encode(text));

function pemToDer(pem) {
  const body = pem.replace(/-----[A-Z ]+-----/g, '').replace(/\s+/g, '');
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

async function mint(sa) {
  const now = Math.floor(Date.now() / 1000);
  const header = textB64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = textB64url(
    JSON.stringify({ iss: sa.client_email, scope: SCOPES, aud: sa.token_uri, iat: now, exp: now + 3600 }),
  );
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${header}.${claims}`));
  const res = await fetch(sa.token_uri, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${header}.${claims}.${b64url(signature)}`,
    }),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`token endpoint ${res.status}: ${json.error ?? 'unknown'}`);
  return json;
}

let cached = null;

export async function accessToken(env) {
  if (env.EMULATOR_TOKEN) return env.EMULATOR_TOKEN; // tests against the Firestore emulator
  if (cached && cached.expiresAt > Date.now() + 60_000) return cached.token;
  const t = await mint(JSON.parse(env.SA_JSON));
  cached = { token: t.access_token, expiresAt: Date.now() + t.expires_in * 1000 };
  return cached.token;
}
