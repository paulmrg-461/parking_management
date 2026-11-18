import { assertEquals } from 'jsr:@std/assert@^1'
import { loadConfig } from './config.ts'
import { DeepSeekClient } from './deepseek.ts'

const params = {
  model: 'deepseek-chat',
  max_tokens: 100,
  system: 'system',
  messages: [{
    role: 'user' as const,
    content: 'question',
  }, {
    role: 'assistant' as const,
    content: [{
      type: 'tool_use' as const,
      id: 'call1',
      name: 'get_revenue_report',
      input: { start_date: '2026-10-01' },
    }],
  }, {
    role: 'user' as const,
    content: [{
      type: 'tool_result' as const,
      tool_use_id: 'call1',
      content: '{"total":1}',
    }],
  }],
  tools: [{
    name: 'get_revenue_report',
    description: 'd',
    input_schema: { type: 'object' },
  }],
  tool_choice: 'auto' as const,
}

Deno.test('deepseek translates request and response', async () => {
  const captured: { url: string; body: any }[] = []
  const original = globalThis.fetch
  globalThis.fetch = ((url: string, init: RequestInit) => {
    captured.push({ url, body: JSON.parse(String(init.body)) })
    return Promise.resolve(new Response(JSON.stringify({
      model: 'deepseek-chat',
      choices: [{
        finish_reason: 'tool_calls',
        message: {
          content: null,
          tool_calls: [{
            id: 'call2',
            function: { name: 'submit_answer', arguments: '{"status":"answered"}' },
          }],
        },
      }],
      usage: { prompt_tokens: 10, completion_tokens: 5 },
    }), { status: 200, headers: { 'Content-Type': 'application/json' } }))
  }) as typeof fetch
  try {
    const client = new DeepSeekClient({
      ...loadConfig({ DEEPSEEK_API_KEY: 'secret' }),
      baseUrl: 'https://provider.test',
    })
    const result = await client.create(params)
    assertEquals(captured[0].url, 'https://provider.test/chat/completions')
    assertEquals(captured[0].body.messages[0].role, 'system')
    assertEquals(captured[0].body.messages[1].content, 'question')
    assertEquals(captured[0].body.messages[2].tool_calls[0].id, 'call1')
    assertEquals(captured[0].body.messages[3].role, 'tool')
    assertEquals(captured[0].body.tools[0].function.name, 'get_revenue_report')
    assertEquals(result.stop_reason, 'tool_use')
    assertEquals(result.usage.input, 10)
    assertEquals((result.content[0] as { id: string }).id, 'call2')
    assertEquals(JSON.stringify(captured[0].body).includes('secret'), false)
  } finally {
    globalThis.fetch = original
  }
})
