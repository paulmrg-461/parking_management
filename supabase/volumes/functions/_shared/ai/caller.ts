import { AiError } from './errors.ts'

export type CallerContext = {
  authorization: string
  lotId: string
  apikey: string
}

export function callerFrom(req: Request, anonKey: string): CallerContext {
  const authorization = req.headers.get('Authorization')?.trim() ?? ''
  if (authorization === '') {
    throw new AiError('InvalidTokenError', 401)
  }
  const lotId = req.headers.get('x-lot-id')?.trim() ?? ''
  if (lotId === '') {
    throw new AiError('LotRequiredError', 400)
  }
  return { authorization, lotId, apikey: anonKey }
}

export function callerHeaders(ctx: CallerContext): Record<string, string> {
  return {
    apikey: ctx.apikey,
    Authorization: ctx.authorization,
    'x-lot-id': ctx.lotId,
    Accept: 'application/json',
    'Content-Type': 'application/json',
  }
}
