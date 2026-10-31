import type { AgDataSourcesDefinition, AgStudioTheme, AgWidgetsConfig } from 'ag-studio';
import { AgStudioAiModule, studioTheme } from 'ag-studio';
import { AgStudio, AgStudioProvider, createWidgets } from 'ag-studio-react';
import { useCallback, useEffect, useMemo, useState } from 'react';
import type { FormEvent } from 'react';

import { sikaAi } from './ai';
import { ApiError, clearToken, fetchConfig, fetchData, getToken, signInWithCode } from './api';
import type { DashboardData } from './api';
import { buildSources } from './data';
import { initialReport } from './report';
import type { SikaRegistry } from './widgets';
import { AuthorizationMeter, PaymentJourney } from './widgets';

const theme: AgStudioTheme = studioTheme.withParams({
  accentColor: '#1463FF',
  backgroundColor: '#F4F7FD',
  foregroundColor: '#0D1B3E',
  fontFamily: "'Outfit Variable', system-ui, sans-serif",
  // Palette des graphiques tirée du logo (bleu action, cyan, bleu roi), puis des couleurs d'état de l'app
  chartPaletteFills1Color: '#1463FF',
  chartPaletteFills2Color: '#06C1E0',
  chartPaletteFills3Color: '#0A3BB5',
  chartPaletteFills4Color: '#0E9F6E',
  chartPaletteFills5Color: '#F2A93B',
  chartPaletteFills6Color: '#7B61FF',
  chartPaletteFills7Color: '#E5527A',
  chartPaletteFills8Color: '#5B6886',
});

function Brand() {
  return (
    <div className="brand">
      <img src="/dashboard/sika-mark.png" alt="" width={30} height={30} />
      <span className="brand-name">
        SIKA <span>Pay</span>
      </span>
    </div>
  );
}

function SignIn({ onSignedIn }: { onSignedIn: () => void }) {
  const [code, setCode] = useState('');
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError(undefined);
    try {
      await signInWithCode(code);
      onSignedIn();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'The SIKA server could not be reached. Check your connection.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <main className="signin">
      <form className="signin-card" onSubmit={submit}>
        <Brand />
        <h1>Open your dashboard</h1>
        <p>
          In the SIKA Pay app, go to <b>Profile → Settings → Web dashboard</b> and enter the code it shows. The code works
          once, for 10 minutes.
        </p>
        <label htmlFor="code">Code from the app</label>
        <input
          id="code"
          value={code}
          onChange={(e) => setCode(e.target.value.toUpperCase())}
          placeholder="ABCD-EFGH"
          autoComplete="one-time-code"
          autoCapitalize="characters"
          spellCheck={false}
          maxLength={12}
          autoFocus
        />
        {error && <div className="signin-error" role="alert">{error}</div>}
        <button type="submit" disabled={busy || code.replace(/[^A-Z0-9]/g, '').length < 8}>
          {busy ? 'Opening…' : 'Open dashboard'}
        </button>
        <p className="signin-note">Read-only: the dashboard cannot make payments. PayPal sandbox, no real money moves.</p>
      </form>
    </main>
  );
}

function Dashboard({ data, license, onSignOut }: { data: DashboardData; license: string; onSignOut: () => void }) {
  const sources = useMemo<AgDataSourcesDefinition<SikaRegistry>>(() => buildSources(data), [data]);
  const report = useMemo(() => initialReport(data.user.first_name), [data.user.first_name]);
  const ai = useMemo(() => sikaAi(), []);
  const widgets = useMemo(
    () => (defaults: AgWidgetsConfig) =>
      createWidgets<SikaRegistry>({
        additionalTypes: [
          {
            id: 'sika-authorization-meter',
            label: 'SIKA authorization',
            icon: { url: '/dashboard/sika-mark.png' },
            dataMapping: {
              spent: { type: 'field', supportedRoles: ['numeric'], requires: { cardinality: 'one' }, required: true },
              limit: { type: 'field', supportedRoles: ['numeric'], requires: { cardinality: 'one' }, required: true },
              perPurchase: { type: 'field', supportedRoles: ['numeric'], requires: { cardinality: 'one' } },
            },
            form: (params) =>
              params.createDefaults({
                dataMappingItems: [
                  { key: 'spent', label: 'Spent today' },
                  { key: 'limit', label: 'Daily limit' },
                  { key: 'perPurchase', label: 'Max per purchase' },
                ],
              }),
            comp: AuthorizationMeter,
            defaultSize: { width: 480, height: 200 },
            minSize: { width: 300, height: 160 },
            ai: { description: 'A gauge of what SIKA confirmed today against the daily limit the user set.' },
          },
          {
            id: 'sika-payment-journey',
            label: 'Payment journey',
            icon: { url: '/dashboard/sika-mark.png' },
            dataMapping: {
              status: { type: 'field', supportedRoles: ['category'], requires: { cardinality: 'many' }, required: true },
              count: { type: 'field', supportedRoles: ['numeric'], requires: { per: 'dataMapping.status', cardinality: 'one' }, required: true },
            },
            form: (params) =>
              params.createDefaults({
                dataMappingItems: [
                  { key: 'status', label: 'Status' },
                  { key: 'count', label: 'Count' },
                ],
              }),
            comp: PaymentJourney,
            defaultSize: { width: 900, height: 220 },
            minSize: { width: 420, height: 180 },
            ai: { description: 'The steps of a payment: prepared by SIKA, waiting for PayPal, paid; plus payments stopped on the way.' },
          },
        ],
        menu: [...defaults.menu, { label: 'SIKA Pay', widgetIds: ['sika-authorization-meter', 'sika-payment-journey'] }],
      }),
    [],
  );

  return (
    <AgStudioProvider licenseKey={license || undefined} modules={[AgStudioAiModule]}>
      <div className="shell">
        <header className="topbar">
          <Brand />
          <span className="topbar-note">Read-only · PayPal sandbox, no real money moves</span>
          <button className="link" onClick={onSignOut}>
            Sign out
          </button>
        </header>
        <div className="studio">
          <AgStudio<SikaRegistry>
            style={{ height: '100%', width: '100%' }}
            data={sources}
            initialState={report}
            widgets={widgets}
            mode="edit"
            theme={theme}
            ai={ai}
          />
        </div>
      </div>
    </AgStudioProvider>
  );
}

type State =
  | { kind: 'loading' }
  | { kind: 'signin' }
  | { kind: 'ready'; data: DashboardData; license: string }
  | { kind: 'error'; message: string };

export default function App() {
  const [state, setState] = useState<State>({ kind: 'loading' });

  const load = useCallback(async () => {
    if (!getToken()) {
      setState({ kind: 'signin' });
      return;
    }
    setState({ kind: 'loading' });
    try {
      const [config, data] = await Promise.all([fetchConfig(), fetchData()]);
      setState({ kind: 'ready', data, license: config.ag_studio_license });
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) setState({ kind: 'signin' });
      else setState({ kind: 'error', message: err instanceof Error ? err.message : 'The SIKA server could not be reached.' });
    }
  }, []);

  useEffect(() => {
    // Lien ouvert depuis l'app : …/dashboard/#code=ABCD-EFGH (le fragment n'est jamais envoyé au serveur)
    const match = window.location.hash.match(/code=([A-Za-z0-9-]+)/);
    if (match) {
      history.replaceState(null, '', window.location.pathname);
      signInWithCode(match[1]).then(load, () => setState({ kind: 'signin' }));
      return;
    }
    load();
  }, [load]);

  const signOut = () => {
    clearToken();
    setState({ kind: 'signin' });
  };

  if (state.kind === 'signin') return <SignIn onSignedIn={load} />;
  if (state.kind === 'ready') return <Dashboard data={state.data} license={state.license} onSignOut={signOut} />;
  return (
    <main className="signin">
      <div className="signin-card">
        <Brand />
        {state.kind === 'loading' ? (
          <p>Loading your data…</p>
        ) : (
          <>
            <p className="signin-error">{state.message}</p>
            <button onClick={load}>Try again</button>
          </>
        )}
      </div>
    </main>
  );
}
