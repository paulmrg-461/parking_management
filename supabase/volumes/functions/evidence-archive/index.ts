// Deletes evidence photos past their site's retention window.
//
// Supabase Storage files cannot be removed from SQL, so this function is the
// bridge: it asks Storage to delete the object and then removes the row. It is
// protected by the service-role key (like push-dispatch) and is meant to run
// from a daily cron:
//
//   curl -X POST http://localhost:8000/functions/v1/evidence-archive \
//     -H "Authorization: Bearer $SERVICE_ROLE_KEY"
//
// Query parameters:
//   days=180     override every site's `evidence_retention_days`
//   dry_run=true only report what would be deleted
//
// Sites with `evidence_retention_days = 0` are skipped (keep forever). Backups
// (supabase/backup.sh) are the archive of record; run one before shrinking a
// retention window.

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const BATCH = 200
const MAX_BATCHES = 10

const headers = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json',
}

type Photo = {
  id: number
  file_path: string
  taken_at: string
}

async function rest(path: string, init: RequestInit = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: { ...headers, ...(init.headers ?? {}) },
  })
  const text = await response.text()
  return { response, body: text ? JSON.parse(text) : null }
}

async function storageDelete(path: string): Promise<boolean> {
  // No Content-Type: Storage rejects an empty JSON body on DELETE.
  const response = await fetch(
    `${SUPABASE_URL}/storage/v1/object/evidence/${encodeURI(path)}`,
    {
      method: 'DELETE',
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    },
  )
  if (response.ok || response.status === 404) {
    return true
  }
  // Storage answers a missing object with 400 + NoSuchKey; the row still needs
  // cleaning, so treat it as already deleted.
  const body = await response.text()
  return body.includes('NoSuchKey') || body.includes('not_found')
}

Deno.serve(async (req) => {
  const started = Date.now()
  const url = new URL(req.url)
  const dryRun = url.searchParams.get('dry_run') === 'true'
  const override = Number(url.searchParams.get('days') ?? '')
  const done = (
    body: Record<string, unknown>,
    status = 200,
  ) => {
    console.log(
      JSON.stringify({
        fn: 'evidence-archive',
        status,
        ms: Date.now() - started,
        dry_run: dryRun,
        ...body,
      }),
    )
    return new Response(JSON.stringify(body), {
      status,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  if (req.method !== 'POST') return done({ message: 'Method not allowed' }, 405)
  if (req.headers.get('authorization') !== `Bearer ${SERVICE_KEY}`) {
    return done({ message: 'Forbidden' }, 403)
  }

  const settings = await rest(
    'parking_settings?select=lot_id,evidence_retention_days',
  )
  if (!settings.response.ok || !Array.isArray(settings.body)) {
    return done({ error: 'Could not read parking settings' }, 500)
  }

  let deletedObjects = 0
  let deletedRows = 0
  let failed = 0
  const sites: Array<{ lot_id: number; days: number }> = []

  for (const row of settings.body as Array<{
    lot_id: number
    evidence_retention_days: number
  }>) {
    const days = Number.isFinite(override) && override > 0
      ? override
      : Number(row.evidence_retention_days ?? 0)
    if (days <= 0) continue
    sites.push({ lot_id: row.lot_id, days })

    const cutoff = new Date(Date.now() - days * 86400000).toISOString()
    for (let batch = 0; batch < MAX_BATCHES; batch++) {
      const { response, body } = await rest(
        'evidence_photos?select=id,file_path,taken_at,session:parking_sessions!inner(lot_id)' +
          `&session.lot_id=eq.${row.lot_id}` +
          `&taken_at=lt.${encodeURIComponent(cutoff)}` +
          `&order=taken_at&limit=${BATCH}`,
      )
      if (!response.ok || !Array.isArray(body)) {
        failed++
        break
      }
      const photos = body as Photo[]
      if (photos.length === 0) break

      if (dryRun) {
        deletedObjects += photos.length
        break
      }

      const removed: number[] = []
      for (const photo of photos) {
        if (await storageDelete(photo.file_path)) {
          deletedObjects++
          removed.push(photo.id)
        } else {
          failed++
        }
      }
      if (removed.length > 0) {
        const ids = removed.join(',')
        const deleted = await rest(`evidence_photos?id=in.(${ids})`, {
          method: 'DELETE',
          headers: { Prefer: 'return=minimal' },
        })
        if (deleted.response.ok) {
          deletedRows += removed.length
        } else {
          failed += removed.length
        }
      }
      if (photos.length < BATCH) break
    }
  }

  return done({
    configured: true,
    sites,
    deleted_objects: deletedObjects,
    deleted_rows: deletedRows,
    failed,
  })
})
