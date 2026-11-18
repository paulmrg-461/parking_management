export type Emit = (event: string, data: unknown) => void

export function encodeEvent(event: string, data: unknown): string {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`
}

export function sseResponse(
  producer: (emit: Emit, signal: AbortSignal) => Promise<void>,
): Response {
  const encoder = new TextEncoder()
  const controller = new AbortController()
  let closed = false
  const body = new ReadableStream({
    async start(stream) {
      const keepalive = setInterval(() => {
        if (!closed) {
          stream.enqueue(encoder.encode(': keepalive\n\n'))
        }
      }, 15_000)
      try {
        await producer((event, data) => {
          if (!closed) {
            stream.enqueue(encoder.encode(encodeEvent(event, data)))
          }
        }, controller.signal)
      } finally {
        closed = true
        clearInterval(keepalive)
        stream.close()
      }
    },
    cancel() {
      closed = true
      controller.abort()
    },
  })
  return new Response(body, {
    status: 200,
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-store',
      Connection: 'keep-alive',
    },
  })
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
