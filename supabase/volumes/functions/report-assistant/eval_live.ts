// Live evaluation of the report assistant against the real model.
//
// Manual only: it costs money and needs DEEPSEEK_API_KEY in the environment.
// It reuses the committed replay fixtures (question + recorded RPC output +
// the figures the design table expects) but replaces the scripted model with
// the real client, so it measures the model's tool selection, date arithmetic
// and figure resolution. The pass bar is the design's: at least 17 of the 18
// cases fully correct and every expected figure resolved to the exact value.
//
//   DEEPSEEK_API_KEY=... deno task eval:live
//   DEEPSEEK_API_KEY=... deno task eval:live case_05.json
//
// Never wired into CI.

import { isConfigured, loadConfig } from '../_shared/ai/config.ts'
import { createModelClient } from '../_shared/ai/deepseek.ts'
import { run, type AgentDeps } from './agent.ts'
import { join } from 'jsr:@std/path@^1'

type Fixture = {
  case: string
  question: string
  locale: string
  today?: string
  rpc_outputs: Record<string, unknown>
  expected: {
    tools: Array<{ tool: string; args?: Record<string, unknown> }>
    answer: {
      status: string
      figures?: Array<{ id: string; value?: number }>
      question_redacted?: boolean
    }
  }
}

const cfg = loadConfig(Deno.env.toObject())
if (!isConfigured(cfg)) {
  console.error(
    'eval:live needs DEEPSEEK_API_KEY (manual run only; it spends tokens).',
  )
  Deno.exit(1)
}

const dir = join(import.meta.dirname!, 'fixtures')
const only = Deno.args[0]
const files = [...Deno.readDirSync(dir)]
  .filter((file) => file.name.endsWith('.json'))
  .filter((file) => only === undefined || file.name === only)
  .sort((a, b) => a.name.localeCompare(b.name))
if (files.length === 0) {
  console.error(`no fixture matches ${only ?? '(all)'}`)
  Deno.exit(1)
}

type Score = {
  file: string
  case: string
  ok: boolean
  problems: string[]
  tools: string[]
  tokens: number
}

const scores: Score[] = []
for (const file of files) {
  const fixture = JSON.parse(
    Deno.readTextFileSync(join(dir, file.name)),
  ) as Fixture
  const called: Array<{ tool: string; args: Record<string, unknown> }> = []
  const deps: AgentDeps = {
    cfg,
    model: createModelClient(cfg),
    rpcGet: (name, args) => {
      // Two calls to one RPC (period comparisons) are recorded under
      // "name|start_date"; fall back to the plain name.
      const key = args['p_start_date'] !== undefined
        ? `${name}|${args['p_start_date']}`
        : name
      const body = fixture.rpc_outputs[key] ?? fixture.rpc_outputs[name] ?? {}
      return Promise.resolve({ ok: true, body })
    },
    restGet: () =>
      Promise.resolve([{ business_timezone: 'America/Bogota', currency: 'COP' }]),
    now: () => new Date(`${fixture.today ?? '2026-11-10'}T12:00:00Z`),
  }
  let answer: Record<string, unknown> | undefined
  const outcome = await run(
    {
      question: fixture.question,
      locale: fixture.locale as 'es' | 'en',
      history: [],
    },
    deps,
    (event, data) => {
      if (event === 'tool') {
        const payload = data as Record<string, unknown>
        if (payload['state'] === 'running' && payload['tool'] !== 'submit_answer') {
          called.push({
            tool: String(payload['tool']),
            args: (payload['args'] ?? {}) as Record<string, unknown>,
          })
        }
      }
      if (event === 'answer') answer = data as Record<string, unknown>
    },
    { requestId: 1 },
  )

  const problems: string[] = []
  if (outcome.status !== 'ok') {
    problems.push(`outcome ${outcome.status}/${outcome.errorCode}`)
  }
  const expectedNames = fixture.expected.tools.map((item) => item.tool)
  const allowed = new Set([...expectedNames, 'get_capacity_now'])
  const calledNames = called.map((item) => item.tool)
  for (const name of expectedNames) {
    if (!calledNames.includes(name)) problems.push(`missing tool ${name}`)
  }
  for (const name of calledNames) {
    if (!allowed.has(name)) problems.push(`unexpected tool ${name}`)
  }
  for (const item of fixture.expected.tools) {
    if (!item.args) continue
    const match = called.find((call) => call.tool === item.tool)
    if (!match) continue
    for (const [key, value] of Object.entries(item.args)) {
      if (String(match.args[key] ?? '') !== String(value)) {
        problems.push(`${item.tool} ${key}=${match.args[key]} (want ${value})`)
      }
    }
  }
  if (answer === undefined) {
    problems.push('no answer')
  } else {
    if (answer['status'] !== fixture.expected.answer.status) {
      problems.push(`status ${answer['status']}`)
    }
    const figures = (answer['figures'] ?? []) as Array<Record<string, unknown>>
    for (const expected of fixture.expected.answer.figures ?? []) {
      const found = figures.find((figure) => figure['id'] === expected.id)
      if (found === undefined) {
        problems.push(`missing figure ${expected.id}`)
      } else if (found['value'] !== expected.value) {
        problems.push(`${expected.id}=${found['value']} (want ${expected.value})`)
      }
    }
    if (fixture.expected.answer.question_redacted === true &&
        answer['question_redacted'] !== true) {
      problems.push('question not redacted')
    }
  }

  scores.push({
    file: file.name,
    case: fixture.case,
    ok: problems.length === 0,
    problems,
    tools: calledNames,
    tokens: outcome.usage.total,
  })
  const mark = problems.length === 0 ? 'ok  ' : 'FAIL'
  console.log(
    `${mark} ${file.name}: ${fixture.case} [${calledNames.join(', ') || '-'}]`,
  )
  for (const problem of problems) console.log(`       ${problem}`)
}

const passed = scores.filter((score) => score.ok).length
const tokens = scores.reduce((total, score) => total + score.tokens, 0)
console.log(
  `\n${passed}/${scores.length} cases correct (bar: >= 17/18), ${tokens} tokens`,
)
// A filtered run is scored against its own size; the full table must reach 17.
if (passed < Math.min(17, scores.length)) {
  Deno.exit(1)
}
