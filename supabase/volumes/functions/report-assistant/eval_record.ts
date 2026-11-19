// Re-record the replay fixtures from a live model run (design task 3.8).
//
// Manual only: it spends tokens and needs DEEPSEEK_API_KEY. It runs each
// fixture against the real model and rewrites only `model_script`, leaving the
// question, the recorded RPC output and the expected figures untouched. A
// fixture is written only when the run ends `ok`; a failure leaves the file as
// it was and makes the task exit non-zero.
//
//   DEEPSEEK_API_KEY=... deno task eval:record
//   DEEPSEEK_API_KEY=... deno task eval:record case_05.json

import { join } from 'jsr:@std/path@^1'
import { loadConfig } from '../_shared/ai/config.ts'
import { createModelClient } from '../_shared/ai/deepseek.ts'
import { evalRefusal } from '../_shared/ai/eval_guard.ts'
import { run, type AgentDeps } from './agent.ts'
import { replaceScript, type RecordedTurn } from './eval/script.ts'

const env = Deno.env.toObject()
const refusal = evalRefusal(env, 'eval:record')
if (refusal !== null) {
  console.error(refusal)
  Deno.exit(1)
}

const cfg = loadConfig(env)
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

let failed = 0
for (const file of files) {
  const path = join(dir, file.name)
  const fixture = JSON.parse(Deno.readTextFileSync(path)) as Record<string, unknown>
  const turns: RecordedTurn[] = []
  const client = createModelClient(cfg)
  const deps: AgentDeps = {
    cfg,
    model: {
      name: client.name,
      create: async (params, signal) => {
        const result = await client.create(params, signal)
        turns.push({
          content: result.content as unknown[],
          stop_reason: result.stop_reason,
        })
        return result
      },
    },
    rpcGet: (name, args) => {
      const outputs = (fixture.rpc_outputs ?? {}) as Record<string, unknown>
      const key = args['p_start_date'] !== undefined
        ? `${name}|${args['p_start_date']}`
        : name
      return Promise.resolve({ ok: true, body: outputs[key] ?? outputs[name] ?? {} })
    },
    restGet: () =>
      Promise.resolve([{ business_timezone: 'America/Bogota', currency: 'COP' }]),
    now: () => new Date(`${String(fixture.today ?? '2026-11-10')}T12:00:00Z`),
  }
  const outcome = await run(
    {
      question: String(fixture.question),
      locale: fixture.locale as 'es' | 'en',
      history: [],
    },
    deps,
    () => {},
    { requestId: 1 },
  )
  if (outcome.status !== 'ok') {
    failed += 1
    console.error(
      `FAIL ${file.name}: ${outcome.status}/${outcome.errorCode} (file untouched)`,
    )
    continue
  }
  Deno.writeTextFileSync(
    path,
    `${JSON.stringify(replaceScript(fixture, turns), null, 2)}\n`,
  )
  console.log(`ok   ${file.name}: ${turns.length} turn(s), ${outcome.usage.total} tokens`)
}

if (failed > 0) {
  Deno.exit(1)
}
