// Replay harness: runs the recorded model scripts against recorded RPC output
// and asserts the agent resolved the figures the design's table expects. No
// network: `rpcGet` serves the fixture payloads.

import { assertEquals } from 'jsr:@std/assert@^1'
import { join } from 'jsr:@std/path'
import { run, type AgentDeps } from './agent.ts'
import type { ContentBlock, ModelResult } from '../_shared/ai/types.ts'
import { loadConfig } from '../_shared/ai/config.ts'

type Fixture = {
  case: string
  question: string
  locale: string
  rpc_outputs: Record<string, unknown>
  model_script: Array<{ content: ContentBlock[]; stop_reason: string }>
  expected: {
    tools: Array<{ tool: string; args?: Record<string, unknown> }>
    answer: {
      status: string
      figures?: Array<{ id: string; value?: number }>
      question_redacted?: boolean
    }
  }
}

class ScriptedModel {
  calls = 0
  constructor(private readonly script: Fixture['model_script']) {}
  create(): Promise<ModelResult> {
    const next = this.script[this.calls]
    this.calls += 1
    if (!next) throw new Error('script exhausted')
    return Promise.resolve({
      content: next.content,
      stop_reason: next.stop_reason as ModelResult['stop_reason'],
      usage: { input: 100, output: 50, cacheRead: 0, cacheWrite: 0, total: 150 },
      model: 'scripted',
    })
  }
}

const fixtureDir = join(import.meta.dirname!, 'fixtures')

for (const file of Deno.readDirSync(fixtureDir)) {
  if (!file.name.endsWith('.json')) continue
  const fixture = JSON.parse(
    Deno.readTextFileSync(join(fixtureDir, file.name)),
  ) as Fixture

  Deno.test(`replay ${file.name}: ${fixture.case}`, async () => {
    const rpcNames: string[] = []
    const model = new ScriptedModel(fixture.model_script)
    const deps: AgentDeps = {
      cfg: loadConfig({ DEEPSEEK_API_KEY: 'test' }),
      model: {
        name: 'scripted',
        create: () => model.create(),
      },
      rpcGet: (name, args) => {
        rpcNames.push(name)
        // Two calls to the same RPC (period comparisons) need two recorded
        // bodies: prefer the "name|start_date" key, fall back to "name".
        const key = args['p_start_date'] !== undefined
          ? `${name}|${args['p_start_date']}`
          : name
        const body = fixture.rpc_outputs[key] ?? fixture.rpc_outputs[name] ?? {}
        return Promise.resolve({ ok: true, body })
      },
      restGet: () =>
        Promise.resolve([{ business_timezone: 'America/Bogota', currency: 'COP' }]),
      now: () => new Date('2026-11-10T12:00:00Z'),
    }

    const events: Array<{ event: string; data: Record<string, unknown> }> = []
    await run(
      { question: fixture.question, locale: fixture.locale as 'es' | 'en', history: [] },
      deps,
      (event, data) => events.push({ event, data: data as Record<string, unknown> }),
      { requestId: 1 },
    )

    assertEquals(rpcNames.length, fixture.expected.tools.length)
    if (fixture.expected.answer.question_redacted !== undefined) {
      assertEquals(
        events.find((item) => item.event === 'answer') !== undefined,
        true,
      )
    }
    const answer = events.find((item) => item.event === 'answer')?.data
    assertEquals(answer !== undefined, true)
    if (answer !== undefined) {
      assertEquals(answer['status'], fixture.expected.answer.status)
      const figures = answer['figures'] as Array<Record<string, unknown>>
      for (const expectedFigure of fixture.expected.answer.figures ?? []) {
        const found = figures.find((figure) => figure['id'] === expectedFigure.id)
        assertEquals(found !== undefined, true)
        assertEquals(found?.['value'], expectedFigure.value)
      }
      if (fixture.expected.answer.question_redacted === true) {
        assertEquals(answer['question_redacted'], true)
      }
    }
  })
}
