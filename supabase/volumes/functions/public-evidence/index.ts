// Public evidence page backend: the customer scans the small QR on the
// receipt, opens /evidence?session=..&plate=.., and this function returns
// short-lived signed URLs for that session's photos and videos. The plate is
// the access key, so the function verifies both the session id and the plate.
//
// It runs with the service role to read Storage/rows, but the caller only needs
// the anon key (VERIFY_JWT still verifies the token signature).

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const PUBLIC_URL = Deno.env.get('SUPABASE_PUBLIC_URL') ?? ''
const EXPIRES_IN = 3600

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
}

const headers = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json',
}

type MediaRow = {
  file_path: string
  taken_at: string
  kind: string
  duration_seconds: number | null
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })

async function rest(path: string) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, { headers })
  const text = await response.text()
  return { ok: response.ok, body: text ? JSON.parse(text) : null }
}

async function sign(path: string, base: string): Promise<string | null> {
  const response = await fetch(
    `${SUPABASE_URL}/storage/v1/object/sign/evidence/${path
      .split('/')
      .map(encodeURIComponent)
      .join('/')}`,
    {
      method: 'POST',
      headers,
      body: JSON.stringify({ expiresIn: EXPIRES_IN }),
    },
  )
  if (!response.ok) return null
  const body = await response.json()
  const signed = String(body.signedURL ?? '')
  if (!signed) return null
  return `${base}/storage/v1${signed}`
}

Deno.serve(async (req) => {
  const started = Date.now()
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'GET' && req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405)
  }

  let sessionId = new URL(req.url).searchParams.get('session')
  let plate = new URL(req.url).searchParams.get('plate')
  if (req.method === 'POST') {
    const body = await req.json().catch(() => null) as
      | { session?: unknown; plate?: unknown }
      | null
    sessionId = sessionId ?? String(body?.session ?? '')
    plate = plate ?? (typeof body?.plate === 'string' ? body.plate : null)
  }

  const id = Number(sessionId)
  const normalized = (plate ?? '').replace(/\s+/g, '').toUpperCase()
  if (!Number.isInteger(id) || id <= 0 || normalized.length < 3) {
    return json({ error: 'invalid_link' }, 400)
  }

  const session = await rest(
    'parking_sessions?select=id,lot_id,entry_time,exit_time,status,vehicle:vehicles!inner(plate)' +
      `&id=eq.${id}&vehicle.plate=eq.${encodeURIComponent(normalized)}&limit=1`,
  )
  if (!session.ok || !Array.isArray(session.body) || session.body.length === 0) {
    return json({ error: 'not_found' }, 404)
  }
  const row = session.body[0] as {
    id: number
    lot_id: number
    entry_time: string
    exit_time: string | null
    status: string
    vehicle: { plate: string }
  }

  // Duration + current fare (or final amount) for the customer page. The RPC
  // validates the same session+plate pair; a failure must not hide evidence.
  let summary: unknown = null
  try {
    const summaryResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/rpc/public_session_summary`,
      {
        method: 'POST',
        headers,
        body: JSON.stringify({
          p_session_id: id,
          p_plate: normalized,
        }),
      },
    )
    if (summaryResponse.ok) {
      summary = await summaryResponse.json().catch(() => null)
    }
  } catch (_) {
    summary = null
  }

  // Signed URLs must be reachable by the customer: use the host they called us
  // on (the app/gateway they can access), falling back to the public URL.
  const forwarded = req.headers.get('x-forwarded-host') ?? req.headers.get('host')
  const proto = req.headers.get('x-forwarded-proto') ?? 'http'
  const base = forwarded ? `${proto}://${forwarded}` : PUBLIC_URL

  // The branding bucket is public, so the logo can be linked directly.
  const settingsRes = await rest(
    'parking_settings?select=phone,whatsapp,address,schedule,logo_path' +
      `&lot_id=eq.${row.lot_id}&limit=1`,
  )
  const settings = Array.isArray(settingsRes.body) && settingsRes.body.length > 0
    ? settingsRes.body[0] as {
      phone: string | null
      whatsapp: string | null
      address: string | null
      schedule: string | null
      logo_path: string | null
    }
    : null
  const lotRes = await rest(
    `parking_lots?select=id,name&id=eq.${row.lot_id}&limit=1`,
  )
  const lotRow = Array.isArray(lotRes.body) && lotRes.body.length > 0
    ? lotRes.body[0] as { id: number; name: string }
    : null
  const logoUrl = settings?.logo_path && base
    ? `${base}/storage/v1/object/public/branding/${settings.logo_path
      .split('/')
      .map(encodeURIComponent)
      .join('/')}`
    : null

  const media = await rest(
    'evidence_photos?select=file_path,taken_at,kind,duration_seconds' +
      `&session_id=eq.${id}&order=taken_at`,
  )
  if (!media.ok || !Array.isArray(media.body)) {
    return json({ error: 'evidence_unavailable' }, 500)
  }

  const photos: unknown[] = []
  const videos: unknown[] = []
  let failed = 0
  for (const item of media.body as MediaRow[]) {
    const url = base ? await sign(item.file_path, base) : null
    if (!url) {
      failed++
      continue
    }
    if (item.kind === 'video') {
      videos.push({
        url,
        taken_at: item.taken_at,
        duration_seconds: item.duration_seconds,
      })
    } else {
      photos.push({ url, taken_at: item.taken_at })
    }
  }

  console.log(JSON.stringify({
    fn: 'public-evidence',
    status: 200,
    ms: Date.now() - started,
    session: id,
    photos: photos.length,
    videos: videos.length,
    failed,
    summary: summary !== null,
  }))

  return json({
    plate: row.vehicle.plate,
    lot_id: row.lot_id,
    entry_time: row.entry_time,
    exit_time: row.exit_time,
    status: row.status,
    summary,
    lot: {
      id: row.lot_id,
      name: lotRow?.name ?? '',
      phone: settings?.phone ?? '',
      whatsapp: settings?.whatsapp ?? '',
      address: settings?.address ?? '',
      schedule: settings?.schedule ?? '',
      logo_url: logoUrl,
    },
    photos,
    videos,
  })
})
