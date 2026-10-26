// Sends pending notifications to Firebase Cloud Messaging (FCM HTTP v1).
//
// Supabase itself does not deliver push: this function is the bridge. It is
// protected by the service-role key, so only a trusted scheduler/admin can
// invoke it:
//
//   curl -X POST http://localhost:8000/functions/v1/push-dispatch \
//     -H "Authorization: Bearer $SERVICE_ROLE_KEY"
//
// Without FCM_SERVICE_ACCOUNT_JSON it is a safe no-op; in-app notifications
// still arrive through Supabase Realtime.

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FCM_RAW = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON') ?? ''
const VAPID_PUBLIC = Deno.env.get('VAPID_PUBLIC_KEY') ?? ''
const VAPID_PRIVATE = Deno.env.get('VAPID_PRIVATE_KEY') ?? ''
const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') ?? 'mailto:admin@parking.local'

const jsonHeaders = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json',
}

type ServiceAccount = {
  project_id: string
  client_email: string
  private_key: string
  token_uri?: string
}

type WebSubscription = {
  id: number
  endpoint: string
  p256dh: string
  auth: string
}

type PendingNotification = {
  id: number
  user_id: number
  title: string
  body: string
  data: Record<string, unknown>
  push_attempts: number
}

let cachedToken: { value: string; expiresAt: number } | null = null

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

function serviceAccount(): ServiceAccount | null {
  if (!FCM_RAW) return null
  try {
    return JSON.parse(FCM_RAW) as ServiceAccount
  } catch {
    console.error('FCM_SERVICE_ACCOUNT_JSON is not valid JSON')
    return null
  }
}

function b64url(value: Uint8Array | string): string {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '')
}

function pemToBytes(pem: string): Uint8Array {
  const body = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '')
  const binary = atob(body)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes
}

async function accessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cachedToken && cachedToken.expiresAt > now + 60) return cachedToken.value

  const tokenUri = account.token_uri ?? 'https://oauth2.googleapis.com/token'
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const claims = b64url(
    JSON.stringify({
      iss: account.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: tokenUri,
      iat: now,
      exp: now + 3600,
    }),
  )
  const input = `${header}.${claims}`
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBytes(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(input),
  )
  const assertion = `${input}.${b64url(new Uint8Array(signature))}`

  const response = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  })
  if (!response.ok) {
    throw new Error(`FCM token exchange failed: ${await response.text()}`)
  }
  const payload = await response.json()
  cachedToken = {
    value: payload.access_token,
    expiresAt: now + Number(payload.expires_in ?? 3600),
  }
  return cachedToken.value
}

async function rest(path: string, init: RequestInit = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: { ...jsonHeaders, ...(init.headers ?? {}) },
  })
  const text = await response.text()
  return { response, body: text ? JSON.parse(text) : null }
}

async function deviceTokens(userId: number): Promise<{ id: number; token: string }[]> {
  const { response, body } = await rest(
    `device_tokens?user_id=eq.${userId}&select=id,token`,
  )
  if (!response.ok || !Array.isArray(body)) return []
  return body
}

async function sendToToken(
  access: string,
  projectId: string,
  token: string,
  notification: PendingNotification,
): Promise<{ ok: boolean; unregistered: boolean }> {
  const data: Record<string, string> = {}
  for (const [key, value] of Object.entries(notification.data ?? {})) {
    data[key] = typeof value === 'string' ? value : JSON.stringify(value)
  }
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${access}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: notification.title, body: notification.body },
          data,
          android: { priority: 'high' },
        },
      }),
    },
  )
  if (response.ok) return { ok: true, unregistered: false }
  const error = await response.text()
  const unregistered =
    response.status === 404 || error.includes('UNREGISTERED') || error.includes('NOT_FOUND')
  console.error(`FCM send failed (${response.status}): ${error}`)
  return { ok: false, unregistered }
}

async function markPushed(id: number) {
  await rest(`notifications?id=eq.${id}`, {
    method: 'PATCH',
    body: JSON.stringify({ pushed_at: new Date().toISOString() }),
  })
}

async function recordFailure(notification: PendingNotification) {
  const attempts = notification.push_attempts + 1
  await rest(`notifications?id=eq.${notification.id}`, {
    method: 'PATCH',
    body: JSON.stringify({
      push_attempts: attempts,
      pushed_at: attempts >= 3 ? new Date().toISOString() : null,
    }),
  })
}

// Web Push (VAPID) is loaded lazily so the function still boots without the
// npm module when only FCM is configured.
type WebPushModule = {
  setVapidDetails(subject: string, publicKey: string, privateKey: string): void
  sendNotification(
    subscription: { endpoint: string; keys: { p256dh: string; auth: string } },
    payload: string,
  ): Promise<{ statusCode?: number }>
}

let webPushModule: WebPushModule | null = null

async function webPush(): Promise<WebPushModule | null> {
  if (!VAPID_PUBLIC || !VAPID_PRIVATE) return null
  if (webPushModule) return webPushModule
  try {
    const module = await import('npm:web-push@3.6.7')
    const push = (module.default ?? module) as unknown as WebPushModule
    push.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE)
    webPushModule = push
    return push
  } catch (error) {
    console.error('web-push could not be loaded', error)
    return null
  }
}

async function webSubscriptions(userId: number): Promise<WebSubscription[]> {
  const { response, body } = await rest(
    `web_push_subscriptions?user_id=eq.${userId}&select=id,endpoint,p256dh,auth`,
  )
  if (!response.ok || !Array.isArray(body)) return []
  return body
}

async function sendWebPush(
  push: WebPushModule,
  subscription: WebSubscription,
  notification: PendingNotification,
): Promise<{ ok: boolean; gone: boolean }> {
  try {
    await push.sendNotification(
      {
        endpoint: subscription.endpoint,
        keys: { p256dh: subscription.p256dh, auth: subscription.auth },
      },
      JSON.stringify({
        title: notification.title,
        body: notification.body,
        data: { ...notification.data, id: notification.id },
      }),
    )
    return { ok: true, gone: false }
  } catch (error) {
    const status = (error as { statusCode?: number }).statusCode
    const gone = status === 404 || status === 410
    console.error(`web push failed (${status ?? 'unknown'})`)
    return { ok: false, gone }
  }
}

Deno.serve(async (req) => {
  const started = Date.now()
  const done = (body: Record<string, unknown>, status = 200) => {
    console.log(
      JSON.stringify({
        fn: 'push-dispatch',
        status,
        ms: Date.now() - started,
        ...body,
      }),
    )
    return json(body, status)
  }

  if (req.method !== 'POST') return done({ message: 'Method not allowed' }, 405)
  if (req.headers.get('authorization') !== `Bearer ${SERVICE_KEY}`) {
    return done({ message: 'Forbidden' }, 403)
  }

  const account = serviceAccount()
  const push = await webPush()
  if (!account && !push) {
    return done({ configured: false, sent: 0, failed: 0 })
  }

  const { response, body } = await rest(
    'notifications?pushed_at=is.null&push_attempts=lt.3' +
      '&select=id,user_id,title,body,data,push_attempts&order=created_at&limit=50',
  )
  if (!response.ok || !Array.isArray(body)) {
    return done({ configured: true, error: 'Could not read notifications' }, 500)
  }
  const pending = body as PendingNotification[]
  if (pending.length === 0) {
    return done({ configured: true, sent: 0, failed: 0, pending: 0 })
  }

  const access = account ? await accessToken(account) : null
  let sent = 0
  let failed = 0

  for (const notification of pending) {
    let delivered = false

    if (account && access) {
      const tokens = await deviceTokens(notification.user_id)
      for (const device of tokens) {
        const result = await sendToToken(
          access,
          account.project_id,
          device.token,
          notification,
        )
        if (result.ok) {
          delivered = true
          sent++
        } else {
          failed++
          if (result.unregistered) {
            await rest(`device_tokens?id=eq.${device.id}`, { method: 'DELETE' })
          }
        }
      }
    }

    if (push) {
      const subscriptions = await webSubscriptions(notification.user_id)
      for (const subscription of subscriptions) {
        const result = await sendWebPush(push, subscription, notification)
        if (result.ok) {
          delivered = true
          sent++
        } else {
          failed++
          if (result.gone) {
            await rest(`web_push_subscriptions?id=eq.${subscription.id}`, {
              method: 'DELETE',
            })
          }
        }
      }
    }

    if (delivered) {
      await markPushed(notification.id)
    } else {
      await recordFailure(notification)
    }
  }

  return done({
    configured: true,
    channels: { fcm: Boolean(account), web: Boolean(push) },
    sent,
    failed,
    pending: pending.length,
  })
})
