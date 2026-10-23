// Admin-only user management on top of GoTrue.
//
// The service-role key never reaches the Flutter client: this function
// verifies the caller with their own JWT, checks the local profile role, and
// only then calls the GoTrue admin API.

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })
}

async function rest(path: string, init: RequestInit = {}, key = SERVICE_KEY) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
  })
  const text = await response.text()
  return { response, body: text ? JSON.parse(text) : null }
}

async function auth(path: string, init: RequestInit = {}) {
  const response = await fetch(`${SUPABASE_URL}/auth/v1/${path}`, {
    ...init,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
  })
  const text = await response.text()
  return { response, body: text ? JSON.parse(text) : null }
}

async function callerId(req: Request): Promise<string> {
  const authorization = req.headers.get('authorization') ?? ''
  if (!authorization.toLowerCase().startsWith('bearer ')) {
    throw new Error('AuthenticationError')
  }
  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: ANON_KEY, Authorization: authorization },
  })
  if (!response.ok) {
    throw new Error('InvalidTokenError')
  }
  const user = await response.json()
  return user.id
}

async function requireAdmin(req: Request): Promise<string> {
  const authId = await callerId(req)
  const { response, body } = await rest(
    `users?auth_user_id=eq.${authId}&select=role,is_active`,
  )
  if (!response.ok || !Array.isArray(body) || body.length === 0) {
    throw new Error('InvalidTokenError')
  }
  if (!body[0].is_active) {
    throw new Error('InvalidTokenError')
  }
  if (body[0].role !== 'admin') {
    throw new Error('AdminRequiredError')
  }
  return authId
}

async function activeAdminCount(excludeId?: number): Promise<number> {
  const filter = excludeId == null ? '' : `&id=neq.${excludeId}`
  const { response, body } = await rest(
    `users?role=eq.admin&is_active=eq.true&select=id${filter}`,
  )
  if (!response.ok || !Array.isArray(body)) {
    throw new Error('InternalError')
  }
  return body.length
}

async function profile(authUserId: string) {
  const { response, body } = await rest(
    `users?auth_user_id=eq.${authUserId}&select=id,username,display_name,role,is_active`,
  )
  if (!response.ok || !Array.isArray(body) || body.length === 0) {
    throw new Error('UserNotFoundError')
  }
  return body[0]
}

// Membership rows are written with the service key: the Edge Function already
// verified the caller is a platform admin, and `set_lot_member` would reject
// the service role (no auth.uid()).
async function assignLot(userId: number, lotId: number, role: string) {
  const lot = Number.isFinite(lotId) && lotId > 0 ? lotId : 1
  const { response, body } = await rest(
    'lot_members?on_conflict=user_id,lot_id',
    {
      method: 'POST',
      headers: { Prefer: 'resolution=merge-duplicates,return=representation' },
      body: JSON.stringify([{ user_id: userId, lot_id: lot, role }]),
    },
  )
  if (!response.ok) {
    console.error('lot membership could not be written', body)
    throw new Error('LotNotFoundError')
  }
}

async function createUser(payload: Record<string, unknown>) {
  const username = String(payload.username ?? '').trim().toLowerCase()
  const pin = String(payload.pin ?? '')
  const role = payload.role === 'admin' ? 'admin' : 'operator'
  const displayName = String(payload.display_name ?? username)
  if (!/^[a-z0-9._-]+$/.test(username)) {
    throw new Error('InvalidUsername')
  }
  if (pin.length < 6) {
    throw new Error('InvalidPin')
  }

  const created = await auth('admin/users', {
    method: 'POST',
    body: JSON.stringify({
      email: `${username}@parking.local`,
      password: pin,
      email_confirm: true,
      app_metadata: { role },
      user_metadata: { display_name: displayName },
    }),
  })
  if (!created.response.ok) {
    const message = created.body?.msg ?? created.body?.message ?? 'User creation failed'
    throw new Error(message)
  }
  const createdProfile = await profile(created.body.id)
  const lotId = Number(payload.lot_id ?? 1)
  await assignLot(Number(createdProfile.id), lotId, role)
  // The profile trigger seeds the default lot; a user created for another site
  // belongs only to the requested one.
  if (lotId !== 1) {
    await rest(`lot_members?user_id=eq.${createdProfile.id}&lot_id=eq.1`, {
      method: 'DELETE',
    })
  }
  return createdProfile
}

async function resetPin(payload: Record<string, unknown>) {
  const id = Number(payload.id)
  const pin = String(payload.pin ?? '')
  if (pin.length < 6) {
    throw new Error('InvalidPin')
  }
  const { response, body } = await rest(
    `users?id=eq.${id}&select=auth_user_id`,
  )
  if (!response.ok || !Array.isArray(body) || body.length === 0) {
    throw new Error('UserNotFoundError')
  }
  const updated = await auth(`admin/users/${body[0].auth_user_id}`, {
    method: 'PUT',
    body: JSON.stringify({ password: pin }),
  })
  if (!updated.response.ok) {
    const message = updated.body?.msg ?? updated.body?.message ?? 'PIN reset failed'
    throw new Error(message)
  }
  return await profile(body[0].auth_user_id)
}

async function deleteUser(payload: Record<string, unknown>, callerAuthId: string) {
  const id = Number(payload.id)
  const { response, body } = await rest(
    `users?id=eq.${id}&select=auth_user_id,role,is_active`,
  )
  if (!response.ok || !Array.isArray(body) || body.length === 0) {
    throw new Error('UserNotFoundError')
  }
  const target = body[0]
  if (target.auth_user_id === callerAuthId) {
    throw new Error('CannotDeleteSelfError')
  }
  if (target.role === 'admin' && target.is_active) {
    if ((await activeAdminCount(id)) === 0) {
      throw new Error('LastAdminError')
    }
  }
  const removed = await auth(`admin/users/${target.auth_user_id}`, {
    method: 'DELETE',
  })
  if (!removed.response.ok) {
    throw new Error('User delete failed')
  }
  await rest(`users?id=eq.${id}`, { method: 'DELETE' })
  return { deleted: true }
}

async function updateUser(payload: Record<string, unknown>) {
  const id = Number(payload.id)
  const { response, body } = await rest(
    `users?id=eq.${id}&select=auth_user_id,role,is_active`,
  )
  if (!response.ok || !Array.isArray(body) || body.length === 0) {
    throw new Error('UserNotFoundError')
  }
  const authUserId = body[0].auth_user_id
  const targetIsAdmin = body[0].role === 'admin' && body[0].is_active
  const demoting = payload.role != null && payload.role !== 'admin'
  const deactivating = payload.is_active === false
  const lotId = payload.lot_id == null ? null : Number(payload.lot_id)
  if (targetIsAdmin && (demoting || deactivating)) {
    if ((await activeAdminCount(id)) === 0) {
      throw new Error('LastAdminError')
    }
  }

  const authPatch: Record<string, unknown> = {}
  if (payload.pin != null) authPatch.password = String(payload.pin)
  if (payload.is_active != null) {
    authPatch.ban_duration = payload.is_active ? 'none' : '876000h'
  }
  if (payload.role != null || payload.display_name != null) {
    const current = await auth(`admin/users/${authUserId}`)
    const appMetadata = { ...(current.body?.app_metadata ?? {}) }
    const userMetadata = { ...(current.body?.user_metadata ?? {}) }
    if (payload.role != null) appMetadata.role = payload.role
    if (payload.display_name != null) {
      userMetadata.display_name = payload.display_name
    }
    authPatch.app_metadata = appMetadata
    authPatch.user_metadata = userMetadata
  }
  if (Object.keys(authPatch).length > 0) {
    const updated = await auth(`admin/users/${authUserId}`, {
      method: 'PUT',
      body: JSON.stringify(authPatch),
    })
    if (!updated.response.ok) {
      const message = updated.body?.msg ?? updated.body?.message ?? 'User update failed'
      throw new Error(message)
    }
  }

  const localPatch: Record<string, unknown> = {}
  if (payload.role != null) localPatch.role = payload.role
  if (payload.is_active != null) localPatch.is_active = payload.is_active
  if (payload.display_name != null) localPatch.display_name = payload.display_name
  if (Object.keys(localPatch).length > 0) {
    await rest(`users?id=eq.${id}`, {
      method: 'PATCH',
      body: JSON.stringify(localPatch),
    })
  }
  if (lotId != null) {
    const membershipRole = payload.role === 'admin' || payload.role === 'operator'
      ? String(payload.role)
      : (body[0].role === 'admin' ? 'admin' : 'operator')
    await assignLot(id, lotId, membershipRole)
  }
  return await profile(authUserId)
}

Deno.serve(async (req) => {
  const started = Date.now()
  let action = 'unknown'
  // One structured line per request: greppable in `docker compose logs
  // functions` and free of user data.
  const done = (body: unknown, status = 200) => {
    console.log(
      JSON.stringify({
        fn: 'admin-users',
        action,
        status,
        ms: Date.now() - started,
        ok: status < 400,
      }),
    )
    return json(body, status)
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors })
  }
  try {
    const callerAuthId = await requireAdmin(req)
    const payload = await req.json().catch(() => ({}))
    action = String(payload.action ?? 'unknown')
    switch (payload.action) {
      case 'create':
        return done(await createUser(payload))
      case 'update':
        return done(await updateUser(payload))
      case 'reset_pin':
        return done(await resetPin(payload))
      case 'delete':
        return done(await deleteUser(payload, callerAuthId))
      default:
        return done({ message: 'Unknown action' }, 400)
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : 'InternalError'
    const status = message === 'AdminRequiredError'
      ? 403
      : message === 'InvalidTokenError' || message === 'AuthenticationError'
      ? 401
      : message === 'LastAdminError' || message === 'CannotDeleteSelfError'
      ? 409
      : 400
    return done({ message }, status)
  }
})
