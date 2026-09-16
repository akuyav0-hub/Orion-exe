// ============================================================
// MOON CORE — Cloudflare Worker — v0.5.1 (Recovery Patch)
// ============================================================
// Auth model:
//   - operator_id = SHA-256("orion-op-id-v1:" + phrase). Stable.
//   - verify_token_phrase = SHA-256("orion-verify-v1:" + op_id + ":" + phrase)
//   - verify_token_seed   = SHA-256("orion-seed-verify-v1:" + seed_entropy)
//   - recovery_id         = SHA-256("orion-recovery-v1:" + seed_entropy)
//   - wrapped_key_phrase  = master_key encrypted with phrase-derived key
//   - wrapped_key_seed    = master_key encrypted with seed-derived key
//
// On Return: client sends operator_id + verify_token_phrase. Server
// returns wrapped_key_phrase. Client unwraps locally.
// On Recover: client sends recovery_id + verify_token_seed. Server
// returns operator_id + wrapped_key_seed. Client unwraps locally,
// picks a new phrase, re-wraps, and updates the server.
// ============================================================

const DEFAULT_DOMAINS = ['finance','tech','business','ai_mastery','health','philosophy'];

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Operator-Id, X-Verify-Token',
  'Access-Control-Max-Age': '86400',
};

function json(data, status=200) { return new Response(JSON.stringify(data), { status, headers: {'Content-Type':'application/json', ...CORS_HEADERS}}); }
function err(msg, status=400) { return json({ error: msg }, status); }

async function authenticate(request, env) {
  const operatorId = request.headers.get('X-Operator-Id');
  const verifyToken = request.headers.get('X-Verify-Token');
  if (!operatorId || !verifyToken) return null;
  const row = await env.DB.prepare(
    'SELECT operator_id, verify_token_phrase FROM operators WHERE operator_id = ?'
  ).bind(operatorId).first();
  if (!row) return null;
  if (row.verify_token_phrase !== verifyToken) return null;
  await env.DB.prepare('UPDATE operators SET last_seen_at = ? WHERE operator_id = ?').bind(Date.now(), operatorId).run();
  return { operatorId };
}

// ============================================================
// AUTH ROUTES
// ============================================================

// POST /awaken — first-time registration
// Body: { operator_id, recovery_id, verify_token_phrase, verify_token_seed, wrapped_key_phrase, wrapped_key_seed }
async function awaken(request, env) {
  const body = await request.json();
  const required = ['operator_id','recovery_id','verify_token_phrase','verify_token_seed','wrapped_key_phrase','wrapped_key_seed'];
  for (const f of required) if (!body[f]) return err('missing ' + f);

  const existing = await env.DB.prepare('SELECT operator_id FROM operators WHERE operator_id = ? OR recovery_id = ?')
    .bind(body.operator_id, body.recovery_id).first();
  if (existing) return err('operator already exists; use /recognize', 409);

  const now = Date.now();
  await env.DB.prepare(
    `INSERT INTO operators (operator_id, recovery_id, created_at, last_seen_at,
     verify_token_phrase, verify_token_seed, wrapped_key_phrase, wrapped_key_seed)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    body.operator_id, body.recovery_id, now, now,
    body.verify_token_phrase, body.verify_token_seed,
    body.wrapped_key_phrase, body.wrapped_key_seed
  ).run();

  await env.DB.prepare('INSERT INTO state (operator_id, updated_at) VALUES (?, ?)').bind(body.operator_id, now).run();
  for (const d of DEFAULT_DOMAINS) {
    await env.DB.prepare('INSERT INTO mission (operator_id, domain, updated_at) VALUES (?, ?, ?)').bind(body.operator_id, d, now).run();
  }
  // Seed the six starting Chronicles
  await seedChroniclesForOperator(body.operator_id, env);
  return json({ ok: true, operator_id: body.operator_id, created_at: now });
}

// POST /recognize — Return with phrase
// Body: { operator_id, verify_token_phrase }
// Returns wrapped_key_phrase so client can unwrap master key locally
async function recognize(request, env) {
  const body = await request.json();
  if (!body.operator_id || !body.verify_token_phrase) return err('missing operator_id or verify_token_phrase');
  const row = await env.DB.prepare(
    'SELECT operator_id, created_at, last_seen_at, verify_token_phrase, wrapped_key_phrase FROM operators WHERE operator_id = ?'
  ).bind(body.operator_id).first();
  if (!row) return err('operator not found', 404);
  if (row.verify_token_phrase !== body.verify_token_phrase) return err('initiation protocol incorrect', 401);
  await env.DB.prepare('UPDATE operators SET last_seen_at = ? WHERE operator_id = ?').bind(Date.now(), body.operator_id).run();
  return json({ ok: true, operator_id: row.operator_id, created_at: row.created_at, last_seen_at: row.last_seen_at, wrapped_key_phrase: row.wrapped_key_phrase });
}

// POST /recover — Recovery via seed
// Body: { recovery_id, verify_token_seed }
// Returns operator_id + wrapped_key_seed
async function recover(request, env) {
  const body = await request.json();
  if (!body.recovery_id || !body.verify_token_seed) return err('missing recovery_id or verify_token_seed');
  const row = await env.DB.prepare(
    'SELECT operator_id, verify_token_seed, wrapped_key_seed FROM operators WHERE recovery_id = ?'
  ).bind(body.recovery_id).first();
  if (!row) return err('recovery seed not recognized', 404);
  if (row.verify_token_seed !== body.verify_token_seed) return err('recovery seed incorrect', 401);
  return json({ ok: true, operator_id: row.operator_id, wrapped_key_seed: row.wrapped_key_seed });
}

// POST /update-phrase — authenticated; replaces phrase-based verify and wrapped key
// Body: { new_verify_token_phrase, new_wrapped_key_phrase }
async function updatePhrase(request, auth, env) {
  const body = await request.json();
  if (!body.new_verify_token_phrase || !body.new_wrapped_key_phrase) return err('missing fields');
  // The new operator_id would change if it's still derived from the phrase. We need to
  // either (a) keep the original operator_id stable (recommended) or (b) allow op_id rotation.
  // We choose (a): operator_id is stable, only the verify token and wrapped key change.
  await env.DB.prepare(
    'UPDATE operators SET verify_token_phrase = ?, wrapped_key_phrase = ?, last_seen_at = ? WHERE operator_id = ?'
  ).bind(body.new_verify_token_phrase, body.new_wrapped_key_phrase, Date.now(), auth.operatorId).run();
  return json({ ok: true });
}

// POST /rotate-after-recovery — seed-authenticated phrase rotation
// Body: { recovery_id, verify_token_seed, new_verify_token_phrase, new_wrapped_key_phrase }
// Used immediately after /recover to bind a new phrase. Authenticates via SEED, not phrase.
async function rotateAfterRecovery(request, env) {
  const body = await request.json();
  const required = ['recovery_id','verify_token_seed','new_verify_token_phrase','new_wrapped_key_phrase'];
  for (const f of required) if (!body[f]) return err('missing ' + f);
  const row = await env.DB.prepare(
    'SELECT operator_id, verify_token_seed FROM operators WHERE recovery_id = ?'
  ).bind(body.recovery_id).first();
  if (!row) return err('recovery seed not recognized', 404);
  if (row.verify_token_seed !== body.verify_token_seed) return err('recovery seed incorrect', 401);
  await env.DB.prepare(
    'UPDATE operators SET verify_token_phrase = ?, wrapped_key_phrase = ?, last_seen_at = ? WHERE operator_id = ?'
  ).bind(body.new_verify_token_phrase, body.new_wrapped_key_phrase, Date.now(), row.operator_id).run();
  return json({ ok: true, operator_id: row.operator_id });
}

// ============================================================
// CHRONICLES (v0.6a)
// Bound volumes of becoming. Per-Chronicle entry numbering,
// typed amendments, visibility states. All content client-side
// encrypted; plaintext metadata only for queryable fields.
// ============================================================

const CHRONICLE_SLUGS = ['capital','creation','forge','body','mind','machine'];
const VALID_VISIBILITY = ['sealed','witness_ready','shared'];
const VALID_AMENDMENT_TYPES = ['correction','update','later_reflection'];

// Seed six starting Chronicles for a freshly-awakened operator.
// Per v0.6b Session 4 decision: ship 3 surfaced (Forge/Capital/Machine),
// seed 3 dormant (Creation/Body/Mind) awaiting operator wake.
// Called from awaken(); also safe to call repeatedly (INSERT OR IGNORE).
async function seedChroniclesForOperator(operatorId, env) {
  const now = Date.now();
  const seeds = [
    // [slug, title, tonal_lean, surfaced]
    ['capital',  'Chronicle of Capital',      'cold_analytical',      1],
    ['forge',    'Chronicle of the Forge',    'sharp_leverage',       1],
    ['machine',  'Chronicle of the Machine',  'precise_craft',        1],
    ['creation', 'Chronicle of Creation',     'warm_generative',      0],
    ['body',     'Chronicle of the Body',     'direct_unsentimental', 0],
    ['mind',     'Chronicle of the Mind',     'patient_exploratory',  0],
  ];
  for (const [slug, title, lean, surfaced] of seeds) {
    await env.DB.prepare(
      `INSERT OR IGNORE INTO chronicles (operator_id, slug, title, tonal_lean, created_at, updated_at, surfaced)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    ).bind(operatorId, slug, title, lean, now, now, surfaced).run();
  }
}

// Slug normalization for Chronicle names.
// Operator types "Body", "body", "BODY", " Body " — all resolve to slug "body".
// "My Faith" → "my-faith". Used for collision detection.
function normalizeSlug(input) {
  if (!input || typeof input !== 'string') return '';
  return input
    .toLowerCase()
    .trim()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9_-]/g, '')
    .slice(0, 32);
}

// GET /chronicles — list all Chronicles for the operator
// Optional query: ?surfaced=1 to filter to only-active (drops dormant)
async function listChronicles(url, auth, env) {
  const onlySurfaced = url.searchParams.get('surfaced') === '1';
  const q = onlySurfaced
    ? `SELECT id, slug, title, tonal_lean, created_at, updated_at, entry_count, level, depth_total, status, surfaced, metadata_enc
       FROM chronicles WHERE operator_id = ? AND surfaced = 1 ORDER BY created_at ASC`
    : `SELECT id, slug, title, tonal_lean, created_at, updated_at, entry_count, level, depth_total, status, surfaced, metadata_enc
       FROM chronicles WHERE operator_id = ? ORDER BY created_at ASC`;
  const r = await env.DB.prepare(q).bind(auth.operatorId).all();
  return json({ chronicles: r.results || [] });
}

// POST /chronicles — create a new Chronicle OR detect dormant-collision
// Body: { title, tonal_lean?, metadata_enc? }
// Slug is derived from title via normalizeSlug (case-insensitive, whitespace-normalized).
// If slug collides with an existing Chronicle:
//   - if existing is dormant (surfaced=0): return 409 with `dormant: true` so frontend
//     can show the "Wake it, or name a new one?" prompt
//   - if existing is surfaced (surfaced=1): return 409 with `dormant: false` — truly duplicate
async function createChronicle(request, auth, env) {
  const body = await request.json();
  if (!body.title) return err('missing title');
  if (body.title.length > 100) return err('title too long');
  const slug = normalizeSlug(body.title);
  if (!slug) return err('invalid title — could not derive slug');

  // Check for collision
  const existing = await env.DB.prepare(
    'SELECT id, slug, title, surfaced FROM chronicles WHERE operator_id = ? AND slug = ?'
  ).bind(auth.operatorId, slug).first();

  if (existing) {
    return new Response(
      JSON.stringify({
        ok: false,
        collision: true,
        dormant: existing.surfaced === 0,
        existing_slug: existing.slug,
        existing_title: existing.title,
      }),
      { status: 409, headers: { 'content-type': 'application/json', ...CORS_HEADERS } }
    );
  }

  const now = Date.now();
  const result = await env.DB.prepare(
    `INSERT INTO chronicles (operator_id, slug, title, tonal_lean, created_at, updated_at, metadata_enc, surfaced)
     VALUES (?, ?, ?, ?, ?, ?, ?, 1)`
  ).bind(auth.operatorId, slug, body.title, body.tonal_lean || null, now, now, body.metadata_enc || null).run();
  return json({ ok: true, id: result.meta?.last_row_id, slug });
}

// POST /chronicles/:slug/wake — wake a dormant Chronicle
// Sets surfaced=1 on an existing Chronicle. No-op if already surfaced.
async function wakeChronicle(slug, auth, env) {
  const result = await env.DB.prepare(
    `UPDATE chronicles SET surfaced = 1, updated_at = ?
     WHERE operator_id = ? AND slug = ?`
  ).bind(Date.now(), auth.operatorId, slug).run();
  if (!result.meta?.changes) return err('chronicle not found', 404);
  return json({ ok: true, slug, surfaced: 1 });
}

// PUT /chronicles/:slug — update Chronicle metadata
// Body: { title?, tonal_lean?, status?, metadata_enc? }
async function updateChronicle(slug, request, auth, env) {
  const body = await request.json();
  const fields = ['title','tonal_lean','status','metadata_enc'];
  const updates = [], values = [];
  for (const f of fields) if (body[f] !== undefined) { updates.push(`${f} = ?`); values.push(body[f]); }
  if (!updates.length) return err('no fields to update');
  updates.push('updated_at = ?'); values.push(Date.now());
  values.push(auth.operatorId); values.push(slug);
  const result = await env.DB.prepare(
    `UPDATE chronicles SET ${updates.join(', ')} WHERE operator_id = ? AND slug = ?`
  ).bind(...values).run();
  if (!result.meta?.changes) return err('chronicle not found', 404);
  return json({ ok: true });
}

// GET /chronicles/:slug/entries?limit=N&before=ts
async function listChronicleEntries(slug, url, auth, env) {
  const chronicle = await env.DB.prepare(
    'SELECT id FROM chronicles WHERE operator_id = ? AND slug = ?'
  ).bind(auth.operatorId, slug).first();
  if (!chronicle) return err('chronicle not found', 404);
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '50'), 200);
  const before = parseInt(url.searchParams.get('before') || '0');
  let q = `SELECT id, entry_number, created_at, content_enc, response_enc, response_raw_enc,
           response_movements, engine_pick, voicing_flag,
           depth_score, visibility, word_count
           FROM chronicle_entries WHERE operator_id = ? AND chronicle_id = ?`;
  const b = [auth.operatorId, chronicle.id];
  if (before > 0) { q += ' AND created_at < ?'; b.push(before); }
  q += ' ORDER BY entry_number DESC LIMIT ?'; b.push(limit);
  const r = await env.DB.prepare(q).bind(...b).all();
  return json({ entries: r.results || [], chronicle_id: chronicle.id });
}

// POST /chronicles/:slug/entries — deposit a new entry
// Body: {
//   content_enc,                        // operator's deposit (encrypted)
//   response_enc?,                      // Orion's response as displayed in UI (encrypted)
//   response_raw_enc?,                  // Orion's brain raw output, untouched by safety pass (encrypted)
//                                       //   For Session 5 (no safety pass yet): == response_enc
//                                       //   For Session 5.5+: preserved through safety pass for retrofit
//   response_movements?,                // FINAL instrument choice: 'mirror' | 'lesson' | 'forge_stroke'
//   engine_pick?,                       // Engine's proposal before operator: same values, or null
//   voicing_flag?,                      // 0 default; 1 if safety pass failed validation twice
//   depth_score?, visibility?, word_count
// }
async function appendChronicleEntry(slug, request, auth, env) {
  const body = await request.json();
  if (!body.content_enc) return err('missing content_enc');
  if (body.visibility && !VALID_VISIBILITY.includes(body.visibility)) return err('invalid visibility');

  const chronicle = await env.DB.prepare(
    'SELECT id, entry_count, depth_total FROM chronicles WHERE operator_id = ? AND slug = ?'
  ).bind(auth.operatorId, slug).first();
  if (!chronicle) return err('chronicle not found', 404);

  const nextEntryNumber = (chronicle.entry_count || 0) + 1;
  const now = Date.now();
  const depth = typeof body.depth_score === 'number' ? Math.max(0, Math.min(1, body.depth_score)) : 0;
  const wc = typeof body.word_count === 'number' ? body.word_count : 0;
  const voicingFlag = body.voicing_flag === 1 ? 1 : 0;

  const result = await env.DB.prepare(
    `INSERT INTO chronicle_entries
     (operator_id, chronicle_id, entry_number, created_at,
      content_enc, response_enc, response_raw_enc,
      response_movements, engine_pick, voicing_flag,
      depth_score, visibility, word_count)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    auth.operatorId, chronicle.id, nextEntryNumber, now,
    body.content_enc, body.response_enc || null, body.response_raw_enc || body.response_enc || null,
    body.response_movements || null, body.engine_pick || null, voicingFlag,
    depth, body.visibility || 'sealed', wc
  ).run();

  // Update Chronicle aggregates
  const newDepthTotal = (chronicle.depth_total || 0) + depth;
  // Level threshold: every 5.0 accumulated depth = next level (tunable)
  const newLevel = Math.max(1, Math.floor(newDepthTotal / 5.0) + 1);
  await env.DB.prepare(
    `UPDATE chronicles SET entry_count = ?, depth_total = ?, level = ?, updated_at = ?
     WHERE id = ?`
  ).bind(nextEntryNumber, newDepthTotal, newLevel, now, chronicle.id).run();

  return json({
    ok: true,
    id: result.meta?.last_row_id,
    entry_number: nextEntryNumber,
    level: newLevel,
    depth_total: newDepthTotal,
  });
}

// GET /chronicles/:slug/entries/:n — fetch a single entry with amendments
async function getChronicleEntry(slug, entryNumber, auth, env) {
  const chronicle = await env.DB.prepare(
    'SELECT id FROM chronicles WHERE operator_id = ? AND slug = ?'
  ).bind(auth.operatorId, slug).first();
  if (!chronicle) return err('chronicle not found', 404);
  const entry = await env.DB.prepare(
    `SELECT id, entry_number, created_at, content_enc, response_enc, response_raw_enc,
     response_movements, engine_pick, voicing_flag,
     depth_score, visibility, word_count
     FROM chronicle_entries WHERE chronicle_id = ? AND entry_number = ?`
  ).bind(chronicle.id, entryNumber).first();
  if (!entry) return err('entry not found', 404);
  const amendments = await env.DB.prepare(
    `SELECT id, created_at, amendment_type, content_enc
     FROM chronicle_amendments WHERE entry_id = ? ORDER BY created_at ASC`
  ).bind(entry.id).all();
  return json({ entry, amendments: amendments.results || [] });
}

// POST /chronicles/:slug/entries/:n/amendments — append a dated note
// Body: { amendment_type, content_enc }
async function appendAmendment(slug, entryNumber, request, auth, env) {
  const body = await request.json();
  if (!body.amendment_type || !body.content_enc) return err('missing fields');
  if (!VALID_AMENDMENT_TYPES.includes(body.amendment_type)) return err('invalid amendment_type');
  const chronicle = await env.DB.prepare(
    'SELECT id FROM chronicles WHERE operator_id = ? AND slug = ?'
  ).bind(auth.operatorId, slug).first();
  if (!chronicle) return err('chronicle not found', 404);
  const entry = await env.DB.prepare(
    'SELECT id FROM chronicle_entries WHERE chronicle_id = ? AND entry_number = ?'
  ).bind(chronicle.id, entryNumber).first();
  if (!entry) return err('entry not found', 404);
  const result = await env.DB.prepare(
    `INSERT INTO chronicle_amendments (operator_id, entry_id, created_at, amendment_type, content_enc)
     VALUES (?, ?, ?, ?, ?)`
  ).bind(auth.operatorId, entry.id, Date.now(), body.amendment_type, body.content_enc).run();
  return json({ ok: true, id: result.meta?.last_row_id });
}

// ============================================================
// CHRONICLE SUGGESTIONS (v0.6c — Phase 5)
// Log every [CHRONICLE_SUGGESTION:...] marker fire for retrospective
// drift analysis. Records threshold_type, domain, excerpt_length,
// clicked_or_not. The corpus enables precise threshold-tuning later.
// ============================================================

const VALID_THRESHOLDS = ['principle_understood', 'decision_declared', 'self_observation'];

// POST /chronicle-suggestions
// Body: { threshold_type, domain, excerpt_length, session_marker? }
// Excerpt CONTENT is NOT stored server-side — privacy by design.
// Only length is stored (for drift signal analysis without content surveillance).
async function logChronicleSuggestion(request, auth, env) {
  const body = await request.json();
  if (!body.threshold_type || !VALID_THRESHOLDS.includes(body.threshold_type)) {
    return err('invalid or missing threshold_type');
  }
  if (!body.domain || typeof body.domain !== 'string') return err('missing domain');
  const excerptLength = typeof body.excerpt_length === 'number' ? body.excerpt_length : 0;
  const sessionMarker = body.session_marker || null;
  const r = await env.DB.prepare(
    `INSERT INTO chronicle_suggestions
     (operator_id, created_at, threshold_type, domain, excerpt_length, clicked, session_marker)
     VALUES (?, ?, ?, ?, ?, 0, ?)`
  ).bind(auth.operatorId, Date.now(), body.threshold_type, body.domain, excerptLength, sessionMarker).run();
  return json({ ok: true, id: r.meta?.last_row_id });
}

// PUT /chronicle-suggestions/:id/clicked
// Body: { deposit_id?: number }   (deposit_id links to chronicle_entries.id if the click led to a real deposit)
async function markSuggestionClicked(suggestionId, request, auth, env) {
  let depositId = null;
  try {
    const body = await request.json();
    if (body && typeof body.deposit_id === 'number') depositId = body.deposit_id;
  } catch (e) { /* empty body is fine */ }
  const result = await env.DB.prepare(
    `UPDATE chronicle_suggestions
     SET clicked = 1, clicked_at = ?, deposit_id = ?
     WHERE id = ? AND operator_id = ?`
  ).bind(Date.now(), depositId, suggestionId, auth.operatorId).run();
  if (!result.meta?.changes) return err('suggestion not found', 404);
  return json({ ok: true });
}

// GET /chronicle-suggestions?since=&threshold=&domain=&limit=
// For retrospective analysis. Returns aggregate-shape rows.
async function listChronicleSuggestions(url, auth, env) {
  const since = parseInt(url.searchParams.get('since') || '0');
  const threshold = url.searchParams.get('threshold');
  const domain = url.searchParams.get('domain');
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '500'), 2000);
  let q = `SELECT id, created_at, threshold_type, domain, excerpt_length, clicked, clicked_at, deposit_id, session_marker
           FROM chronicle_suggestions WHERE operator_id = ?`;
  const b = [auth.operatorId];
  if (since > 0) { q += ' AND created_at >= ?'; b.push(since); }
  if (threshold && VALID_THRESHOLDS.includes(threshold)) { q += ' AND threshold_type = ?'; b.push(threshold); }
  if (domain) { q += ' AND domain = ?'; b.push(domain); }
  q += ' ORDER BY created_at DESC LIMIT ?'; b.push(limit);
  const r = await env.DB.prepare(q).bind(...b).all();
  return json({ suggestions: r.results || [] });
}

// ============================================================
// STATE / CONVERSATIONS / MEMORIES / LESSONS / MISSION / EVOLUTION
// (Same as v0.5 — unchanged)
// ============================================================

async function getState(auth, env) {
  const row = await env.DB.prepare('SELECT * FROM state WHERE operator_id = ?').bind(auth.operatorId).first();
  return json({ state: row || null });
}
async function putState(request, auth, env) {
  const body = await request.json();
  const fields = ['navi_name','current_form','sync_value','total_interactions','preferred_model','settings_enc'];
  const updates = [], values = [];
  for (const f of fields) if (body[f] !== undefined) { updates.push(`${f} = ?`); values.push(body[f]); }
  if (!updates.length) return err('no fields to update');
  updates.push('updated_at = ?'); values.push(Date.now()); values.push(auth.operatorId);
  await env.DB.prepare(`UPDATE state SET ${updates.join(', ')} WHERE operator_id = ?`).bind(...values).run();
  return json({ ok: true });
}

async function appendConversation(request, auth, env) {
  const body = await request.json();
  if (!body.role || !body.content_enc) return err('missing role or content_enc');
  if (!['user','assistant'].includes(body.role)) return err('invalid role');
  const ts = Date.now();
  const interrupted = body.interrupted ? 1 : 0;
  const r = await env.DB.prepare(
    'INSERT INTO conversations (operator_id, ts, role, content_enc, form, topics_enc, interrupted) VALUES (?, ?, ?, ?, ?, ?, ?)'
  ).bind(auth.operatorId, ts, body.role, body.content_enc, body.form || null, body.topics_enc || null, interrupted).run();
  return json({ ok: true, id: r.meta?.last_row_id, ts });
}

// PATCH /conversations/:id — flag an existing row.
// Currently only supports {interrupted: boolean}. This is the path used
// when an assistant response was already written to D1 (because frontend
// optimistically appended on stream-start) and the operator then stopped
// the stream, requiring a retroactive flag.
async function patchConversation(id, request, auth, env) {
  const body = await request.json();
  if (typeof body.interrupted !== 'boolean') return err('only {interrupted: boolean} is supported');
  const r = await env.DB.prepare(
    'UPDATE conversations SET interrupted = ? WHERE id = ? AND operator_id = ?'
  ).bind(body.interrupted ? 1 : 0, id, auth.operatorId).run();
  if (!r.success || r.meta?.changes === 0) return err('row not found or not owned', 404);
  return json({ ok: true, id, interrupted: body.interrupted });
}

async function listConversations(url, auth, env) {
  // Params:
  //   limit   - max rows (default 50, hard cap 500)
  //   before  - ts <  before   (backward paging cursor; unchanged behaviour)
  //   since   - ts >= since    (window start)
  //   until   - ts <= until    (window end)
  //   order   - 'asc' | 'desc' (default desc; asc reads a window chronologically)
  //
  // since/until make an ARBITRARY window queryable instead of only the slice
  // adjacent to now. All params compose; omitting them preserves the original
  // behaviour exactly, so existing callers are unaffected.
  //
  // The response echoes the resolved window back. That is deliberate: the client
  // can confirm it got the window it asked for rather than assuming, which is how
  // it detects talking to a Worker that predates these params (an older Worker
  // silently ignores unknown query params and would return the wrong rows while
  // looking successful).
  const limit  = Math.min(parseInt(url.searchParams.get('limit') || '50'), 500);
  const before = parseInt(url.searchParams.get('before') || '0');
  const since  = parseInt(url.searchParams.get('since')  || '0');
  const until  = parseInt(url.searchParams.get('until')  || '0');
  const order  = (url.searchParams.get('order') || '').toLowerCase() === 'asc' ? 'ASC' : 'DESC';

  let q = 'SELECT id, ts, role, content_enc, form, topics_enc, interrupted FROM conversations WHERE operator_id = ?';
  const b = [auth.operatorId];
  if (before > 0) { q += ' AND ts < ?';  b.push(before); }
  if (since  > 0) { q += ' AND ts >= ?'; b.push(since);  }
  if (until  > 0) { q += ' AND ts <= ?'; b.push(until);  }
  q += ` ORDER BY ts ${order} LIMIT ?`; b.push(limit);

  const r = await env.DB.prepare(q).bind(...b).all();
  const rows = r.results || [];
  return json({
    conversations: rows,
    window: {
      since: since || null,
      until: until || null,
      before: before || null,
      order: order.toLowerCase(),
      limit,
      returned: rows.length,
      supports_window: true,
    },
  });
}

async function addMemory(request, auth, env) {
  const body = await request.json();
  if (!body.category || !body.content_enc) return err('missing fields');
  const now = Date.now();
  const r = await env.DB.prepare(
    'INSERT INTO memories (operator_id, created_at, last_accessed_at, category, content_enc, importance, decay) VALUES (?, ?, ?, ?, ?, ?, ?)'
  ).bind(auth.operatorId, now, now, body.category, body.content_enc, body.importance ?? 5, body.decay ?? 0).run();
  return json({ ok: true, id: r.meta?.last_row_id });
}
async function listMemories(url, auth, env) {
  const cat = url.searchParams.get('category');
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '50'), 200);
  let q = 'SELECT id, created_at, last_accessed_at, category, content_enc, importance, decay FROM memories WHERE operator_id = ?';
  const b = [auth.operatorId];
  if (cat) { q += ' AND category = ?'; b.push(cat); }
  q += ' ORDER BY importance DESC, created_at DESC LIMIT ?'; b.push(limit);
  const r = await env.DB.prepare(q).bind(...b).all();
  return json({ memories: r.results || [] });
}
async function deleteMemory(id, auth, env) {
  await env.DB.prepare('DELETE FROM memories WHERE id = ? AND operator_id = ?').bind(id, auth.operatorId).run();
  return json({ ok: true });
}

async function addLesson(request, auth, env) {
  const body = await request.json();
  if (!body.domain || !body.title_enc || !body.content_enc || !body.source) return err('missing fields');
  const now = Date.now();
  const r = await env.DB.prepare(
    'INSERT INTO lessons (operator_id, created_at, domain, title_enc, content_enc, source, followup_due) VALUES (?, ?, ?, ?, ?, ?, ?)'
  ).bind(auth.operatorId, now, body.domain, body.title_enc, body.content_enc, body.source, body.followup_due || null).run();
  return json({ ok: true, id: r.meta?.last_row_id });
}
async function listLessons(url, auth, env) {
  const dom = url.searchParams.get('domain');
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '50'), 200);
  let q = 'SELECT id, created_at, domain, title_enc, content_enc, source, followup_due, followup_state, followup_closed_at FROM lessons WHERE operator_id = ?';
  const b = [auth.operatorId];
  if (dom) { q += ' AND domain = ?'; b.push(dom); }
  // open=1 returns only debts still owed. Anything else returns everything,
  // because a closed debt is still part of the record.
  if (url.searchParams.get('open') === '1') q += ' AND followup_state IS NULL';
  q += ' ORDER BY created_at DESC LIMIT ?'; b.push(limit);
  const r = await env.DB.prepare(q).bind(...b).all();
  return json({ lessons: r.results || [] });
}

// ============================================================
// USAGE LEDGER (v0.6r)
// Counts only — no content, nothing derived from content, nothing to encrypt.
// It exists because Orion runs on two devices and a per-device spend counter
// would report two numbers, neither of which is the truth.
// ============================================================
const USAGE_KINDS = new Set(['spend', 'topup']);

async function recordUsage(request, auth, env) {
  const b = await request.json();
  const kind = String(b.kind || '');
  if (!USAGE_KINDS.has(kind)) return err('kind must be spend or topup');

  const n = (v) => {
    const x = Math.trunc(Number(v) || 0);
    return x > 0 ? x : 0;
  };
  const micro = n(b.micro_usd);
  if (kind === 'topup' && micro <= 0) return err('a topup needs a positive micro_usd');

  const clientId = b.client_event_id ? String(b.client_event_id).slice(0, 120) : null;

  // Idempotency, same discipline as the Academy: a replayed write returns the
  // row it already made rather than counting the same turn twice.
  if (clientId) {
    const existing = await env.DB.prepare(
      'SELECT id FROM usage_events WHERE operator_id = ? AND client_event_id = ?'
    ).bind(auth.operatorId, clientId).first();
    if (existing) return json({ ok: true, id: existing.id, duplicate: true });
  }

  const r = await env.DB.prepare(
    'INSERT INTO usage_events (operator_id, created_at, kind, model, input_tokens, output_tokens, cache_write_tokens, cache_read_tokens, web_searches, micro_usd, price_rev, client_event_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
  ).bind(
    auth.operatorId, Date.now(), kind,
    kind === 'spend' ? (b.model ? String(b.model).slice(0, 80) : null) : null,
    n(b.input_tokens), n(b.output_tokens), n(b.cache_write_tokens), n(b.cache_read_tokens),
    n(b.web_searches), micro,
    b.price_rev ? String(b.price_rev).slice(0, 40) : null,
    clientId
  ).run();
  return json({ ok: true, id: r.meta?.last_row_id });
}

async function usageSummary(url, auth, env) {
  // Window for the burn-rate figure. The lifetime totals are never windowed —
  // a balance that only counted recent spend would read high and be wrong in
  // the one direction that costs the operator money.
  const days = Math.min(Math.max(parseInt(url.searchParams.get('days') || '30'), 1), 365);
  const since = Date.now() - days * 86400000;

  const totals = await env.DB.prepare(
    "SELECT " +
    " COALESCE(SUM(CASE WHEN kind = 'spend' THEN micro_usd ELSE 0 END), 0) AS spent_micro," +
    " COALESCE(SUM(CASE WHEN kind = 'topup' THEN micro_usd ELSE 0 END), 0) AS topup_micro," +
    " COALESCE(SUM(input_tokens), 0)  AS input_tokens," +
    " COALESCE(SUM(output_tokens), 0) AS output_tokens," +
    " COALESCE(SUM(cache_write_tokens), 0) AS cache_write_tokens," +
    " COALESCE(SUM(cache_read_tokens), 0)  AS cache_read_tokens," +
    " COALESCE(SUM(web_searches), 0)  AS web_searches," +
    " COALESCE(SUM(CASE WHEN kind = 'spend' THEN 1 ELSE 0 END), 0) AS turns," +
    " MIN(created_at) AS first_at, MAX(created_at) AS last_at" +
    ' FROM usage_events WHERE operator_id = ?'
  ).bind(auth.operatorId).first();

  const window = await env.DB.prepare(
    "SELECT COALESCE(SUM(micro_usd), 0) AS spent_micro," +
    ' COALESCE(SUM(web_searches), 0) AS web_searches,' +
    ' COUNT(*) AS turns' +
    " FROM usage_events WHERE operator_id = ? AND kind = 'spend' AND created_at >= ?"
  ).bind(auth.operatorId, since).first();

  const spent = Number(totals?.spent_micro || 0);
  const topped = Number(totals?.topup_micro || 0);
  return json({
    totals: {
      spent_micro: spent,
      topup_micro: topped,
      // Only meaningful once a topup has been recorded. Reported as null rather
      // than a negative number so the client shows "unknown", never "-$4.12".
      remaining_micro: topped > 0 ? topped - spent : null,
      input_tokens: Number(totals?.input_tokens || 0),
      output_tokens: Number(totals?.output_tokens || 0),
      cache_write_tokens: Number(totals?.cache_write_tokens || 0),
      cache_read_tokens: Number(totals?.cache_read_tokens || 0),
      web_searches: Number(totals?.web_searches || 0),
      turns: Number(totals?.turns || 0),
      first_at: totals?.first_at ?? null,
      last_at: totals?.last_at ?? null,
    },
    window: {
      days,
      spent_micro: Number(window?.spent_micro || 0),
      web_searches: Number(window?.web_searches || 0),
      turns: Number(window?.turns || 0),
    },
  });
}

// v0.6s: retire a follow-up. State, never deletion — whether something was
// taught or let go is precisely what the record is for.
const FOLLOWUP_STATES = new Set(['closed', 'dropped']);
async function patchLesson(id, request, auth, env) {
  const b = await request.json();
  const updates = [], values = [];
  if (b.followup_state !== undefined) {
    if (b.followup_state !== null && !FOLLOWUP_STATES.has(b.followup_state)) {
      return err("followup_state must be 'closed', 'dropped', or null");
    }
    updates.push('followup_state = ?'); values.push(b.followup_state);
    updates.push('followup_closed_at = ?'); values.push(b.followup_state ? Date.now() : null);
  }
  if (b.followup_due !== undefined) { updates.push('followup_due = ?'); values.push(b.followup_due); }
  if (!updates.length) return err('nothing to update');
  values.push(id, auth.operatorId);
  const r = await env.DB.prepare(
    `UPDATE lessons SET ${updates.join(', ')} WHERE id = ? AND operator_id = ?`
  ).bind(...values).run();
  if (!r.meta || r.meta.changes === 0) return err('no such lesson for this operator', 404);
  return json({ ok: true, id });
}

async function getMission(auth, env) {
  const r = await env.DB.prepare('SELECT id, domain, updated_at, level, progress_enc, status FROM mission WHERE operator_id = ? ORDER BY domain').bind(auth.operatorId).all();
  return json({ mission: r.results || [] });
}
async function putMission(domain, request, auth, env) {
  const body = await request.json();
  const fields = ['level','progress_enc','status'];
  const updates = [], values = [];
  for (const f of fields) if (body[f] !== undefined) { updates.push(`${f} = ?`); values.push(body[f]); }
  updates.push('updated_at = ?'); values.push(Date.now()); values.push(auth.operatorId); values.push(domain);
  await env.DB.prepare(`UPDATE mission SET ${updates.join(', ')} WHERE operator_id = ? AND domain = ?`).bind(...values).run();
  return json({ ok: true });
}
async function addMissionDomain(request, auth, env) {
  const body = await request.json();
  if (!body.domain) return err('missing domain');
  const clean = body.domain.toLowerCase().replace(/[^a-z0-9_]/g,'_').slice(0,32);
  if (!clean) return err('invalid domain');
  try {
    await env.DB.prepare('INSERT INTO mission (operator_id, domain, updated_at) VALUES (?, ?, ?)').bind(auth.operatorId, clean, Date.now()).run();
    return json({ ok: true, domain: clean });
  } catch (e) { return err('domain already exists', 409); }
}

// ============================================================
// THE ACADEMY (v0.6o) — attributes + tests
// ============================================================
// Orion reads and writes these himself through tool-use. There is no
// operator-facing panel and no operator-facing write path: the operator
// cannot hand themselves a level. A level moves when the teacher says it
// moves, and only then.
//
// The taxonomy is open. Attribute rows are created on first test, so the
// set of things being learned is whatever Orion has actually decided to
// teach — nothing is pre-seeded.
//
// level == tests_passed, always. It is derived, not independently set,
// so the counter and the notch count can never drift apart.
// ============================================================

function cleanSlug(raw) {
  if (!raw || typeof raw !== 'string') return '';
  return raw.toLowerCase().trim().replace(/[^a-z0-9_]/g, '_').replace(/_+/g, '_').replace(/^_|_$/g, '').slice(0, 40);
}

// The single honest view. Orion's words: "the number is a receipt; the topics
// and assessments underneath it are the actual record," and the honest answer to
// "where do I stand" is what you cleared, what you were held on, and what has not
// been touched in a while. That answer used to take two reaches — levels here,
// holds from the history — which made the shallow answer free and the true one
// cost extra. Things that cost extra get skipped exactly when they matter. So the
// last test and the last hold, with their topics, come back with the levels.
async function listAttributes(auth, env) {
  const r = await env.DB.prepare(
    `SELECT id, slug, label, created_at, updated_at, level, tests_taken, tests_passed,
            last_test_at, last_pass_at, status
       FROM attributes WHERE operator_id = ? ORDER BY slug`
  ).bind(auth.operatorId).all();
  const attributes = r.results || [];
  if (!attributes.length) return json({ attributes });

  // Most recent test per attribute, and most recent HOLD per attribute. The id
  // tiebreak matters for the same reason it does in the history listing: two rows
  // in one millisecond must not come back in an undefined order.
  const latest = await env.DB.prepare(
    `SELECT attribute_id, verdict, topic_enc, created_at FROM (
       SELECT attribute_id, verdict, topic_enc, created_at,
              ROW_NUMBER() OVER (PARTITION BY attribute_id ORDER BY created_at DESC, id DESC) rn
         FROM attribute_tests WHERE operator_id = ?
     ) WHERE rn = 1`
  ).bind(auth.operatorId).all();
  const latestHold = await env.DB.prepare(
    `SELECT attribute_id, topic_enc, created_at FROM (
       SELECT attribute_id, topic_enc, created_at,
              ROW_NUMBER() OVER (PARTITION BY attribute_id ORDER BY created_at DESC, id DESC) rn
         FROM attribute_tests WHERE operator_id = ? AND verdict = 'hold'
     ) WHERE rn = 1`
  ).bind(auth.operatorId).all();

  const byId = new Map(), holdById = new Map();
  for (const row of (latest.results || [])) byId.set(row.attribute_id, row);
  for (const row of (latestHold.results || [])) holdById.set(row.attribute_id, row);
  for (const a of attributes) {
    const t = byId.get(a.id), h = holdById.get(a.id);
    a.last_test = t ? { verdict: t.verdict, topic_enc: t.topic_enc, created_at: t.created_at } : null;
    a.last_hold = h ? { topic_enc: h.topic_enc, created_at: h.created_at } : null;
  }
  return json({ attributes });
}

// Renaming is the one operation that can rewrite the past: every test recorded
// under the old label retroactively becomes a test in the new one. It is gated
// hard on the operator's own typed instruction — Orion has no tool for this and
// cannot trigger it. He flags, the operator decides, and only then does it move.
// Refuses rather than merging: folding two attributes together would silently
// reshape what the record says happened, which is a separate decision entirely.
async function renameAttribute(slug, request, auth, env) {
  const body = await request.json();
  const from = cleanSlug(slug);
  const to = cleanSlug(body.new_slug || '');
  if (!from || !to) return err('both the current and the new slug are required');

  const existing = await env.DB.prepare(
    'SELECT id, label FROM attributes WHERE operator_id = ? AND slug = ?'
  ).bind(auth.operatorId, from).first();
  if (!existing) return err(`no attribute named '${from}'`, 404);

  if (to !== from) {
    const collision = await env.DB.prepare(
      'SELECT id FROM attributes WHERE operator_id = ? AND slug = ?'
    ).bind(auth.operatorId, to).first();
    if (collision) {
      return err(`'${to}' already exists — renaming into it would merge two records, which is a separate decision. Pick a free name.`, 409);
    }
  }

  const label = (typeof body.new_label === 'string' && body.new_label.trim())
    ? body.new_label.trim().slice(0, 80)
    : to.replace(/_/g, ' ');
  const now = Date.now();

  await env.DB.batch([
    env.DB.prepare('UPDATE attributes SET slug = ?, label = ?, updated_at = ? WHERE id = ?')
      .bind(to, label, now, existing.id),
    env.DB.prepare('UPDATE attribute_tests SET slug = ? WHERE operator_id = ? AND attribute_id = ?')
      .bind(to, auth.operatorId, existing.id),
  ]);

  return json({ ok: true, from, to, label, previous_label: existing.label });
}

async function recordAttributeTest(request, auth, env) {
  const body = await request.json();
  const slug = cleanSlug(body.slug);
  if (!slug) return err('missing or invalid slug');
  const verdict = (body.verdict || '').toLowerCase();
  if (verdict !== 'pass' && verdict !== 'hold') return err("verdict must be 'pass' or 'hold'");

  const now = Date.now();
  const label = (typeof body.label === 'string' && body.label.trim())
    ? body.label.trim().slice(0, 80)
    : slug.replace(/_/g, ' ');

  // Idempotency: a replay of a call already recorded returns the original
  // outcome and moves nothing. Levels are durable, so a retried request must
  // never be able to advance the operator twice for one answer.
  const clientTestId = (typeof body.client_test_id === 'string' && body.client_test_id.trim())
    ? body.client_test_id.trim().slice(0, 120)
    : null;
  if (clientTestId) {
    const prior = await env.DB.prepare(
      `SELECT t.id, t.slug, t.verdict, t.level_after, a.label, a.tests_taken, a.tests_passed
         FROM attribute_tests t JOIN attributes a ON a.id = t.attribute_id
        WHERE t.operator_id = ? AND t.client_test_id = ?`
    ).bind(auth.operatorId, clientTestId).first();
    if (prior) {
      return json({
        ok: true, duplicate: true, slug: prior.slug, label: prior.label,
        verdict: prior.verdict, level: prior.level_after, leveled_up: false,
        attribute_created: false, tests_taken: prior.tests_taken,
        tests_passed: prior.tests_passed, test_id: prior.id,
      });
    }
  }

  let attr = await env.DB.prepare(
    'SELECT id, level, tests_taken, tests_passed FROM attributes WHERE operator_id = ? AND slug = ?'
  ).bind(auth.operatorId, slug).first();

  let created = false;
  if (!attr) {
    const ins = await env.DB.prepare(
      `INSERT INTO attributes (operator_id, slug, label, created_at, updated_at, level, tests_taken, tests_passed)
       VALUES (?, ?, ?, ?, ?, 0, 0, 0)`
    ).bind(auth.operatorId, slug, label, now, now).run();
    attr = { id: ins.meta?.last_row_id, level: 0, tests_taken: 0, tests_passed: 0 };
    created = true;
  }

  const passed = verdict === 'pass';
  const testsTaken = attr.tests_taken + 1;
  const testsPassed = attr.tests_passed + (passed ? 1 : 0);
  const level = testsPassed; // level IS the passed count — derived, never set independently

  // The counter update and the test-log insert go out together. They are the
  // pair that must not drift: a counter that moved without a matching test row
  // is a level nobody can account for.
  const updateStmt = passed
    ? env.DB.prepare(
        `UPDATE attributes SET level = ?, tests_taken = ?, tests_passed = ?,
                last_test_at = ?, last_pass_at = ?, updated_at = ? WHERE id = ?`
      ).bind(level, testsTaken, testsPassed, now, now, now, attr.id)
    : env.DB.prepare(
        `UPDATE attributes SET level = ?, tests_taken = ?, tests_passed = ?,
                last_test_at = ?, updated_at = ? WHERE id = ?`
      ).bind(level, testsTaken, testsPassed, now, now, attr.id);

  const insertStmt = env.DB.prepare(
    `INSERT INTO attribute_tests (operator_id, attribute_id, slug, created_at, verdict, topic_enc, assessment_enc, level_after, client_test_id)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(auth.operatorId, attr.id, slug, now, verdict,
         body.topic_enc || null, body.assessment_enc || null, level, clientTestId);

  const batched = await env.DB.batch([updateStmt, insertStmt]);
  const t = batched[1];

  const payload = {
    ok: true,
    slug,
    label,
    verdict,
    level,
    leveled_up: passed,
    attribute_created: created,
    tests_taken: testsTaken,
    tests_passed: testsPassed,
    test_id: t.meta?.last_row_id,
  };

  // THE GUARDRAIL. Opening a new attribute hands back everything already open.
  // The failure this catches is not a lapse in discipline — it is coining fresh
  // language that feels correct, which is reconstruction-from-plausibility
  // wearing a different coat. Seeing the open list at the moment of creation
  // catches it while it is still cheap, and costs nothing when the check already
  // happened: the expected names simply appear.
  if (created) {
    const others = await env.DB.prepare(
      'SELECT slug, label, level FROM attributes WHERE operator_id = ? AND slug != ? ORDER BY slug'
    ).bind(auth.operatorId, slug).all();
    payload.already_open = (others.results || []);
  }

  return json(payload);
}

async function listAttributeTests(url, auth, env) {
  const slug = cleanSlug(url.searchParams.get('slug') || '');
  // Garbage in the query string must not reach LIMIT — SQLite treats a
  // negative limit as unbounded, and NaN would fail the bind.
  const rawLimit = parseInt(url.searchParams.get('limit') || '20', 10);
  const limit = Math.min(Math.max(Number.isFinite(rawLimit) ? rawLimit : 20, 1), 100);
  let q = `SELECT id, slug, created_at, verdict, topic_enc, assessment_enc, level_after
             FROM attribute_tests WHERE operator_id = ?`;
  const b = [auth.operatorId];
  if (slug) { q += ' AND slug = ?'; b.push(slug); }
  // id breaks the tie: two tests recorded inside the same millisecond would
  // otherwise come back in an undefined order, and history that reshuffles is
  // worse than history that is merely coarse.
  q += ' ORDER BY created_at DESC, id DESC LIMIT ?'; b.push(limit);
  const r = await env.DB.prepare(q).bind(...b).all();
  return json({ tests: r.results || [] });
}

async function listEvolution(url, auth, env) {
  const unackOnly = url.searchParams.get('unack') === '1';
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 100);
  let q = 'SELECT id, created_at, trigger_type, theme, theme_enc, content_enc, surfaced_at, acknowledged FROM evolution WHERE operator_id = ?';
  const b = [auth.operatorId];
  if (unackOnly) q += ' AND acknowledged = 0';
  q += ' ORDER BY created_at DESC LIMIT ?'; b.push(limit);
  const r = await env.DB.prepare(q).bind(...b).all();
  return json({ evolution: r.results || [] });
}
async function ackEvolution(id, auth, env) {
  await env.DB.prepare('UPDATE evolution SET acknowledged = 1, surfaced_at = COALESCE(surfaced_at, ?) WHERE id = ? AND operator_id = ?').bind(Date.now(), id, auth.operatorId).run();
  return json({ ok: true });
}
async function submitEvolution(request, auth, env) {
  const body = await request.json();
  if (!body.content_enc) return err('missing content_enc');
  await env.DB.prepare('INSERT INTO evolution (operator_id, created_at, trigger_type, theme, theme_enc, content_enc, acknowledged) VALUES (?, ?, ?, ?, ?, ?, 0)')
    .bind(auth.operatorId, Date.now(), 'weekly_reflection', body.theme || 'untitled', body.theme_enc || null, body.content_enc).run();
  if (body.replaces_pending_id) {
    await env.DB.prepare("DELETE FROM evolution WHERE id = ? AND operator_id = ? AND content_enc = 'PENDING'")
      .bind(body.replaces_pending_id, auth.operatorId).run();
  }
  return json({ ok: true });
}
async function reflectionDue(auth, env) {
  const r = await env.DB.prepare("SELECT id, created_at FROM evolution WHERE operator_id = ? AND content_enc = 'PENDING' ORDER BY created_at DESC LIMIT 1").bind(auth.operatorId).first();
  return json({ due: !!r, pending_id: r?.id || null, created_at: r?.created_at || null });
}

async function runReflectionForOperator(operatorId, env, triggerType) {
  const weekAgo = Date.now() - 7*24*60*60*1000;
  const convs = await env.DB.prepare('SELECT id FROM conversations WHERE operator_id = ? AND ts >= ? LIMIT 1').bind(operatorId, weekAgo).all();
  if (!convs.results?.length) return 0;
  await env.DB.prepare('INSERT INTO evolution (operator_id, created_at, trigger_type, theme, content_enc) VALUES (?, ?, ?, ?, ?)')
    .bind(operatorId, Date.now(), triggerType + '_pending', 'pending_client_synthesis', 'PENDING').run();
  return 1;
}

// ============================================================
// MAIN
// ============================================================
export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') return new Response(null, { headers: CORS_HEADERS });
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;
    try {
      // Public
      if (path === '/health') return json({ ok: true, service: 'moon-core', version: '0.6s-followups', supports_academy: true, supports_rename: true, supports_usage: true, supports_followup_state: true, time: Date.now() });
      if (path === '/awaken' && method === 'POST') return awaken(request, env);
      if (path === '/recognize' && method === 'POST') return recognize(request, env);
      if (path === '/recover' && method === 'POST') return recover(request, env);
      if (path === '/rotate-after-recovery' && method === 'POST') return rotateAfterRecovery(request, env);

      // Auth required for everything below
      const auth = await authenticate(request, env);
      if (!auth) return err('unauthorized', 401);

      // Phrase rotation (used after recovery)
      if (path === '/update-phrase' && method === 'POST') return updatePhrase(request, auth, env);

      // State
      if (path === '/state' && method === 'GET') return getState(auth, env);
      if (path === '/state' && method === 'PUT') return putState(request, auth, env);

      // Conversations
      if (path === '/conversations' && method === 'POST') return appendConversation(request, auth, env);
      if (path === '/conversations' && method === 'GET') return listConversations(url, auth, env);
      const convMatch = path.match(/^\/conversations\/(\d+)$/);
      if (convMatch && method === 'PATCH') return patchConversation(parseInt(convMatch[1]), request, auth, env);

      // Memories
      if (path === '/memories' && method === 'POST') return addMemory(request, auth, env);
      if (path === '/memories' && method === 'GET') return listMemories(url, auth, env);
      const mm = path.match(/^\/memories\/(\d+)$/);
      if (mm && method === 'DELETE') return deleteMemory(parseInt(mm[1]), auth, env);

      // Lessons
      if (path === '/lessons' && method === 'POST') return addLesson(request, auth, env);
      if (path === '/lessons' && method === 'GET') return listLessons(url, auth, env);
      const lm = path.match(/^\/lessons\/(\d+)$/);
      if (lm && method === 'PATCH') return patchLesson(parseInt(lm[1]), request, auth, env);

      // Usage ledger (v0.6r)
      if (path === '/usage' && method === 'POST') return recordUsage(request, auth, env);
      if (path === '/usage/summary' && method === 'GET') return usageSummary(url, auth, env);

      // Mission
      if (path === '/mission' && method === 'GET') return getMission(auth, env);
      if (path === '/mission' && method === 'POST') return addMissionDomain(request, auth, env);
      const xm = path.match(/^\/mission\/([a-z0-9_]+)$/);
      if (xm && method === 'PUT') return putMission(xm[1], request, auth, env);

      // The Academy (v0.6o) — attributes Orion tests against.
      // NOTE: /attributes/tests is matched BEFORE /attributes/test so the
      // plural history route is never swallowed by the singular write route.
      if (path === '/attributes' && method === 'GET') return listAttributes(auth, env);
      if (path === '/attributes/tests' && method === 'GET') return listAttributeTests(url, auth, env);
      if (path === '/attributes/test' && method === 'POST') return recordAttributeTest(request, auth, env);
      const attrRename = path.match(/^\/attributes\/([a-z0-9_]+)\/rename$/);
      if (attrRename && method === 'POST') return renameAttribute(attrRename[1], request, auth, env);

      // Evolution
      if (path === '/evolution' && method === 'GET') return listEvolution(url, auth, env);
      if (path === '/evolution/synthesize' && method === 'POST') return submitEvolution(request, auth, env);
      if (path === '/reflection/due' && method === 'GET') return reflectionDue(auth, env);
      const em = path.match(/^\/evolution\/(\d+)\/acknowledge$/);
      if (em && method === 'PUT') return ackEvolution(parseInt(em[1]), auth, env);

      // Chronicles (v0.6a)
      if (path === '/chronicles' && method === 'GET') return listChronicles(url, auth, env);
      if (path === '/chronicles' && method === 'POST') return createChronicle(request, auth, env);
      const chronicleWakeMatch = path.match(/^\/chronicles\/([a-z0-9_-]+)\/wake$/);
      if (chronicleWakeMatch && method === 'POST') return wakeChronicle(chronicleWakeMatch[1], auth, env);
      const chronicleMatch = path.match(/^\/chronicles\/([a-z0-9_-]+)$/);
      if (chronicleMatch && method === 'PUT') return updateChronicle(chronicleMatch[1], request, auth, env);
      const chronicleEntriesMatch = path.match(/^\/chronicles\/([a-z0-9_-]+)\/entries$/);
      if (chronicleEntriesMatch && method === 'GET') return listChronicleEntries(chronicleEntriesMatch[1], url, auth, env);
      if (chronicleEntriesMatch && method === 'POST') return appendChronicleEntry(chronicleEntriesMatch[1], request, auth, env);
      const chronicleEntryMatch = path.match(/^\/chronicles\/([a-z0-9_-]+)\/entries\/(\d+)$/);
      if (chronicleEntryMatch && method === 'GET') return getChronicleEntry(chronicleEntryMatch[1], parseInt(chronicleEntryMatch[2]), auth, env);
      const amendmentMatch = path.match(/^\/chronicles\/([a-z0-9_-]+)\/entries\/(\d+)\/amendments$/);
      if (amendmentMatch && method === 'POST') return appendAmendment(amendmentMatch[1], parseInt(amendmentMatch[2]), request, auth, env);

      // Chronicle Suggestions (v0.6c — Phase 5 logging for retrospective drift analysis)
      if (path === '/chronicle-suggestions' && method === 'POST') return logChronicleSuggestion(request, auth, env);
      if (path === '/chronicle-suggestions' && method === 'GET') return listChronicleSuggestions(url, auth, env);
      const suggestionClickMatch = path.match(/^\/chronicle-suggestions\/(\d+)\/clicked$/);
      if (suggestionClickMatch && method === 'PUT') return markSuggestionClicked(parseInt(suggestionClickMatch[1]), request, auth, env);

      return err('not found', 404);
    } catch (e) {
      console.error('worker error', e);
      return err('internal error: ' + (e.message || String(e)), 500);
    }
  },

  async scheduled(event, env, ctx) {
    const ops = await env.DB.prepare('SELECT operator_id FROM operators WHERE last_seen_at > ?').bind(Date.now() - 30*24*60*60*1000).all();
    for (const op of (ops.results || [])) {
      const pending = await env.DB.prepare("SELECT id FROM evolution WHERE operator_id = ? AND content_enc = 'PENDING'").bind(op.operator_id).first();
      if (!pending) await runReflectionForOperator(op.operator_id, env, 'weekly_reflection');
    }
  },
};
