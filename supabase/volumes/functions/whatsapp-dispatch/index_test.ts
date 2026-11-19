// Tests for the message payload of whatsapp-dispatch (no network).

import { assert, assertEquals } from 'jsr:@std/assert@^1'
import { buildMessagePayload, type PendingMessage } from './index.ts'

const templates = {
  pass_expiry: 'pass_expiry',
  pass_renewal_link: 'pass_renewal_link',
}

const message: PendingMessage = {
  id: 1,
  to_phone: '573001112233',
  template: 'pass_renewal_link',
  language: 'es',
  params: ['Ana', 'ABC123', '24/11/2026', '$80.000'],
  attempts: 0,
  button_param: 'a'.repeat(48),
}

Deno.test('whatsapp-dispatch adds the url button when button_param is set', () => {
  const { payload, error } = buildMessagePayload(message, templates)
  assert(error === undefined)
  const components = (payload!.template as { components: unknown[] }).components
  assertEquals(components.length, 2)
  const button = components[1] as Record<string, unknown>
  assertEquals(button.type, 'button')
  assertEquals(button.sub_type, 'url')
  assertEquals(button.index, '0')
  assertEquals((button.parameters as Array<{ text: string }>)[0].text, 'a'.repeat(48))
})

Deno.test('whatsapp-dispatch no button without button_param', () => {
  const { payload } = buildMessagePayload(
    { ...message, button_param: null },
    templates,
  )
  const components = (payload!.template as { components: unknown[] }).components
  assertEquals(components.length, 1)
  assertEquals((components[0] as { type: string }).type, 'body')
})

Deno.test('whatsapp-dispatch unknown template still fails the row', () => {
  const { payload, error } = buildMessagePayload(
    { ...message, template: 'not_approved' },
    templates,
  )
  assertEquals(payload, undefined)
  assertEquals(error, 'Unknown template: not_approved')
})
