// Guards for the manual live evaluations (they spend tokens). Pure so the
// refusals are tested without a network call.

export function evalRefusal(
  env: Record<string, string | undefined>,
  task: string,
): string | null {
  if ((env.CI ?? '').trim().toLowerCase() === 'true') {
    return `${task} is manual only and refuses to run in CI`
  }
  if ((env.DEEPSEEK_API_KEY ?? '').trim() === '') {
    return `${task} needs DEEPSEEK_API_KEY (it spends tokens)`
  }
  return null
}
