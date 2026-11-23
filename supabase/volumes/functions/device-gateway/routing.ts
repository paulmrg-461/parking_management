// Route table for the device gateway. Paths arrive with the function prefix
// (`/functions/v1/device-gateway/v1/...`), so a route matches the tail of the
// pathname; `:name` segments capture one value and extra segments never match.

export type RouteName =
  | 'time'
  | 'heartbeat'
  | 'lpr_config'
  | 'lpr_reads'
  | 'lpr_snapshot'
  | 'barrier_config'
  | 'barrier_next'
  | 'barrier_ack'
  | 'barrier_event'
  | 'barrier_firmware'
  | 'barrier_image'
  | 'bays_config'
  | 'bays_report'
  | 'bays_firmware'
  | 'bays_image'

type Route = {
  method: string
  name: RouteName
  segments: string[]
}

export type MatchedRoute = {
  name: RouteName
  params: Record<string, string>
}

const ROUTES: Route[] = [
  { method: 'GET', name: 'time', segments: ['v1', 'time'] },
  { method: 'POST', name: 'heartbeat', segments: ['v1', 'heartbeat'] },
  { method: 'GET', name: 'lpr_config', segments: ['v1', 'lpr', 'config'] },
  { method: 'POST', name: 'lpr_reads', segments: ['v1', 'lpr', 'reads'] },
  {
    method: 'PUT',
    name: 'lpr_snapshot',
    segments: ['v1', 'lpr', 'events', ':id', 'snapshot'],
  },
  {
    method: 'GET',
    name: 'barrier_config',
    segments: ['v1', 'barrier', 'config'],
  },
  {
    method: 'GET',
    name: 'barrier_next',
    segments: ['v1', 'barrier', 'commands', 'next'],
  },
  {
    method: 'POST',
    name: 'barrier_ack',
    segments: ['v1', 'barrier', 'commands', ':id', 'ack'],
  },
  {
    method: 'POST',
    name: 'barrier_event',
    segments: ['v1', 'barrier', 'events'],
  },
  {
    method: 'GET',
    name: 'barrier_firmware',
    segments: ['v1', 'barrier', 'firmware'],
  },
  {
    method: 'GET',
    name: 'barrier_image',
    segments: ['v1', 'barrier', 'firmware', ':version', 'image'],
  },
  {
    method: 'GET',
    name: 'bays_config',
    segments: ['v1', 'bays', 'config'],
  },
  {
    method: 'POST',
    name: 'bays_report',
    segments: ['v1', 'bays', 'report'],
  },
  {
    method: 'GET',
    name: 'bays_firmware',
    segments: ['v1', 'bays', 'firmware'],
  },
  {
    method: 'GET',
    name: 'bays_image',
    segments: ['v1', 'bays', 'firmware', ':version', 'image'],
  },
]

export function matchRoute(
  method: string,
  pathname: string,
): MatchedRoute | null {
  const parts = pathname.split('/').filter((part) => part !== '')
  for (const route of ROUTES) {
    if (route.method !== method) continue
    if (parts.length < route.segments.length) continue
    const tail = parts.slice(parts.length - route.segments.length)
    const params: Record<string, string> = {}
    let matched = true
    for (let index = 0; index < route.segments.length; index++) {
      const segment = route.segments[index]
      if (segment.startsWith(':')) {
        params[segment.slice(1)] = tail[index]
      } else if (segment !== tail[index]) {
        matched = false
        break
      }
    }
    if (matched) return { name: route.name, params }
  }
  return null
}
