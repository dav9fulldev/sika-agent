import type { AgAiHarnessSetup, AgAiPromptStarter, AgStudioApi } from 'ag-studio';
import { createAiHarness, directLlmRunner } from 'ag-studio';

import { sikaGeminiAdapter } from './geminiAdapter';

const PROMPT_STARTERS: AgAiPromptStarter[] = [
  { label: 'Where did my money go?', prompt: 'Add a chart of what I paid by merchant and tell me the biggest one.' },
  { label: 'What did SIKA pay for me?', prompt: 'Show only the purchases SIKA confirmed within my authorization, with the total.' },
  { label: 'Price drops', prompt: 'Which followed products got cheaper, and by how much?' },
  { label: 'Payments that did not go through', prompt: 'List the payments that were cancelled, expired or declined, and explain each status.' },
];

function sikaInstructions(api: AgStudioApi): string {
  const { tables } = api.getAiContext().schema();
  return [
    'You are SIKA, the assistant of SIKA Pay. You help the user understand their own payments and the prices SIKA follows for them, by answering with numbers and by building or adjusting dashboard widgets.',
    'How you work:',
    '- Look at the schema and query the data before answering. Quote amounts with their currency, exactly as the data says.',
    "- For anything that changes the page (adding, placing or configuring widgets), delegate to the specialist agents: 'planning' for a multi-widget layout, 'page' to place widgets, 'widget' to configure one, 'data' for analysis. Prefer the blank 'ask' page for new widgets unless the user names a page.",
    '- A payment counts as paid only when its status is Paid (PayPal confirmed the capture). Never present another status as paid.',
    "- You are read-only on money: you cannot pay, refund, change SIKA's authorization or contact a merchant. If asked, say the user can do it in the SIKA Pay app.",
    '- Keep replies short: one or two sentences, then the result.',
    `Tables available: ${tables.map((t) => t.name).join(', ')}.`,
  ].join('\n');
}

/** Studio Agent Framework : l'agent SIKA mène la conversation et confie le travail de page aux agents intégrés de Studio, tous sur Gemini. */
export function sikaAi(): AgAiHarnessSetup {
  const adapter = sikaGeminiAdapter();
  return ({ api }) =>
    createAiHarness(api, ({ builtIn, tools }) => ({
      agents: [
        directLlmRunner({
          id: 'sika',
          name: 'SIKA',
          description: 'SIKA Pay assistant: explains your payments and followed prices, and builds widgets with the Studio team.',
          adapter,
          schema: (s) => s.undefined(),
          instructions: () => sikaInstructions(api),
          tools: () => [
            tools.studio.viewSchema(),
            tools.studio.viewPage(),
            tools.studio.executeQuery(),
            tools.delegateTo(['planning', 'data', 'page', 'widget']),
          ],
        }),
        ...Object.values(builtIn).map((definition) => directLlmRunner({ ...definition, adapter })),
      ],
      primary: 'sika',
      promptStarters: PROMPT_STARTERS,
    }));
}
