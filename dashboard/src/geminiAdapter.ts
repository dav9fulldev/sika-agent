import type { AgAiEvent, AgAiOutputItem, AgLlmAdapter, AgLlmResponse } from 'ag-studio';

import { postLlmTurn } from './api';

/**
 * Adaptateur AG Studio → Gemini. Chaque tour part vers le backend SIKA (/api/v1/dashboard/llm), qui appelle
 * Gemini sur Vertex AI avec les identifiants du serveur : aucune clé dans le navigateur. Le backend renvoie la
 * réponse complète ; on la rejoue ici sous forme d'événements AG-UI pour le panneau de discussion.
 */
export function sikaGeminiAdapter(): AgLlmAdapter {
  return {
    executeTurn(request, options) {
      const complete: Promise<AgLlmResponse> = postLlmTurn(request, options?.signal)
        .then((r) => r as AgLlmResponse)
        .catch((e: unknown) => ({
          id: `resp_${Date.now()}`,
          createdAt: Date.now(),
          status: 'failed' as const,
          output: [],
          error: { code: 'NETWORK', message: e instanceof Error ? e.message : 'The SIKA server could not be reached.' },
        }));

      async function* events(): AsyncGenerator<AgAiEvent> {
        const response = await complete;
        for (const item of response.output as AgAiOutputItem[]) {
          if (item.type === 'message') {
            const text = item.content.map((c) => (c.type === 'text' ? c.text : '')).join('');
            yield { type: 'TEXT_MESSAGE_START', messageId: item.id, role: 'assistant' };
            yield { type: 'TEXT_MESSAGE_CONTENT', messageId: item.id, delta: text };
            yield { type: 'TEXT_MESSAGE_END', messageId: item.id };
          } else if (item.type === 'function_call') {
            yield { type: 'TOOL_CALL_START', toolCallId: item.callId, toolCallName: item.name };
            yield { type: 'TOOL_CALL_ARGS', toolCallId: item.callId, delta: item.arguments };
            yield { type: 'TOOL_CALL_END', toolCallId: item.callId };
          }
        }
      }

      return { stream: events(), complete };
    },
  };
}
