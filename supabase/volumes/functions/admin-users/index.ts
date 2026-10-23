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

async function requireAdmin(req: Request): Promise<void> {
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
  return await profile(created.body.id)
}

async function updateUser(payload: Record<string, unknown>) {
  const id = Number(payload.id)
  const { response, body } = await rest(
    `users?id=eq.${id}&select=auth_user_id`,
  )
  if (!response.ok || !Array.isArray(body) || body.length === 0) {
    throw new Error('UserNotFoundError')
  }
  const authUserId = body[0].auth_user_id

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
  return await profile(authUserId)
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors })
  }
  try {
    await requireAdmin(req)
    const payload = await req.json().catch(() => ({}))
    switch (payload.action) {
      case 'create':
        return json(await createUser(payload))
      case 'update':
        return json(await updateUser(payload))
      default:
        return json({ message: 'Unknown action' }, 400)
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : 'InternalError'
    const status = message === 'AdminRequiredError'
      ? 403
      : message === 'InvalidTokenError' || message === 'AuthenticationError'
      ? 401
      : 400
    return json({ message }, status)
  }
})
