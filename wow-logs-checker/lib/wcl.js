// Thin Warcraft Logs v2 API client: OAuth client-credentials + GraphQL.
// Docs: https://www.warcraftlogs.com/api/docs

export function createWclClient({ clientId, clientSecret, host = 'www.warcraftlogs.com', fetchImpl = fetch }) {
  if (!clientId || !clientSecret) throw new Error('WCL_CLIENT_ID and WCL_CLIENT_SECRET are required');
  const tokenUrl = `https://${host}/oauth/token`;
  const apiUrl = `https://${host}/api/v2/client`;
  let token = null;
  let expiresAt = 0;

  async function getToken() {
    if (token && Date.now() < expiresAt - 60_000) return token;
    const res = await fetchImpl(tokenUrl, {
      method: 'POST',
      headers: {
        Authorization: 'Basic ' + Buffer.from(`${clientId}:${clientSecret}`).toString('base64'),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=client_credentials',
    });
    if (!res.ok) throw new Error(`Warcraft Logs auth failed (HTTP ${res.status}). Check your client ID/secret.`);
    const json = await res.json();
    token = json.access_token;
    expiresAt = Date.now() + (json.expires_in ?? 3600) * 1000;
    return token;
  }

  async function query(gql, variables = {}) {
    const res = await fetchImpl(apiUrl, {
      method: 'POST',
      headers: { Authorization: `Bearer ${await getToken()}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: gql, variables }),
    });
    if (res.status === 429) throw new Error('Warcraft Logs rate limit hit. Wait a bit and try again.');
    if (!res.ok) throw new Error(`Warcraft Logs API error (HTTP ${res.status})`);
    const json = await res.json();
    if (json.errors?.length) throw new Error(json.errors.map((e) => e.message).join('; '));
    return json.data;
  }

  return { query };
}

// table()/rankings() fields come back as a JSON scalar shaped { data: {...} }.
export function unwrap(json) {
  if (json && typeof json === 'object' && 'data' in json && Object.keys(json).length === 1) return json.data;
  return json;
}
