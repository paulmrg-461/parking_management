// Guards for the manual live evaluation. Kept pure so the refusals are
// tested without spending a token.

export function evalRefusal(
  env: Record<string, string | undefined>,
): string | null {
  if ((env.CI ?? '').trim().toLowerCase() === 'true') {
    return 'eval:live is manual only and refuses to run in CI'
  }
  if ((env.DEEPSEEK_API_KEY ?? '').trim() === '') {
    return 'eval:live needs DEEPSEEK_API_KEY (it spends tokens)'
  }
  return null
}
