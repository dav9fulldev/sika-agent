// Appels au backend SIKA. Le jeton est limité au tableau de bord (lecture seule) et gardé pour l'onglet seulement.
const TOKEN_KEY = 'sika-dashboard-token';

export type Row = Record<string, string | number | boolean | null>;

export interface DashboardData {
  user: { first_name: string };
  generated_at: string;
  tables: {
    payments: Row[];
    followed_products: Row[];
    price_changes: Row[];
    subscriptions: Row[];
    authorization: Row[];
  };
}

export class ApiError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export function getToken(): string | null {
  try {
    return sessionStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

export function clearToken(): void {
  try {
    sessionStorage.removeItem(TOKEN_KEY);
  } catch {
    /* stockage indisponible : rien à effacer */
  }
}

async function call<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = getToken();
  const response = await fetch(path, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(init.headers || {}),
    },
  });
  if (!response.ok) {
    let code = 'HTTP_' + response.status;
    let message = 'The SIKA server could not answer.';
    try {
      const body = await response.json();
      code = body?.detail?.error_code ?? code;
      message = body?.detail?.message ?? message;
    } catch {
      /* réponse sans JSON */
    }
    if (response.status === 401) clearToken();
    throw new ApiError(response.status, code, message);
  }
  return response.json() as Promise<T>;
}

export async function signInWithCode(code: string): Promise<void> {
  const res = await call<{ access_token: string }>('/api/v1/dashboard/session', {
    method: 'POST',
    body: JSON.stringify({ code }),
  });
  try {
    sessionStorage.setItem(TOKEN_KEY, res.access_token);
  } catch {
    throw new ApiError(0, 'STORAGE', 'This browser blocks session storage. Allow it for this site and try again.');
  }
}

export const fetchConfig = () => call<{ ag_studio_license: string; ai_enabled: boolean }>('/api/v1/dashboard/config');
export const fetchData = () => call<DashboardData>('/api/v1/dashboard/data');
export const postLlmTurn = (body: unknown, signal?: AbortSignal) =>
  call<unknown>('/api/v1/dashboard/llm', { method: 'POST', body: JSON.stringify(body), signal });
