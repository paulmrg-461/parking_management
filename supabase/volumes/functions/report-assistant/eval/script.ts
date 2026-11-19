// Pure helper for the manual recorder: swap a fixture's recorded model turns
// while keeping every other field (question, RPC output, expectations) intact.

export type RecordedTurn = {
  content: unknown[]
  stop_reason: string
}

export function replaceScript(
  fixture: Record<string, unknown>,
  turns: RecordedTurn[],
): Record<string, unknown> {
  if (turns.length === 0) {
    throw new Error('refusing to write an empty model script')
  }
  return { ...fixture, model_script: turns }
}
