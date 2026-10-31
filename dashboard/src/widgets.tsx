import type {
  AgBaseRegistry,
  AgBaseWidgetDefinition,
  AgDefaultWidgetDefinition,
  AgWidgetDataFormat,
  AgWidgetFieldReference,
  AgWidgetParams,
} from 'ag-studio';
import { useEffect, useRef, useState } from 'react';

// ---------------------------------------------------------------------------
// Types des widgets SIKA (registre AG Studio)
// ---------------------------------------------------------------------------

export interface AuthorizationMeterDef {
  type: 'sika-authorization-meter';
  dataMapping: { spent: AgWidgetFieldReference[]; limit: AgWidgetFieldReference[]; perPurchase: AgWidgetFieldReference[] };
  format?: AgWidgetDataFormat<Record<string, never>>;
}

export interface PaymentJourneyDef {
  type: 'sika-payment-journey';
  dataMapping: { status: AgWidgetFieldReference[]; count: AgWidgetFieldReference[] };
  format?: AgWidgetDataFormat<Record<string, never>>;
}

export interface SikaRegistry extends AgBaseRegistry {
  widgets: readonly (
    | AgDefaultWidgetDefinition
    | AgBaseWidgetDefinition<'sika-authorization-meter', AuthorizationMeterDef>
    | AgBaseWidgetDefinition<'sika-payment-journey', PaymentJourneyDef>
  )[];
}

const usd = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });

// ---------------------------------------------------------------------------
// Jauge de l'autorisation : ce que SIKA a confirmé aujourd'hui, face à la limite que l'utilisateur a fixée
// ---------------------------------------------------------------------------

export function AuthorizationMeter({ dataMapping, widgetApi }: AgWidgetParams<AuthorizationMeterDef>) {
  const [values, setValues] = useState<{ spent: number; limit: number | null; perPurchase: number | null }>();
  const loaded = useRef(false);

  useEffect(() => {
    const spent = dataMapping.spent?.at(0);
    const limit = dataMapping.limit?.at(0);
    const perPurchase = dataMapping.perPurchase?.at(0);
    if (!spent || !limit) {
      widgetApi.setDisplayState('incompleteDataMapping');
      return;
    }
    let cancelled = false;
    (async () => {
      widgetApi.setDisplayState('loading', { prominent: !loaded.current });
      const fields = [spent, limit, ...(perPurchase ? [perPurchase] : [])];
      const response = await widgetApi.getData({ fields });
      if (cancelled) return;
      const row = response.results.rows.at(0) ?? {};
      const num = (v: unknown) => (typeof v === 'number' ? v : null);
      setValues({
        spent: num(row[spent.key]) ?? 0,
        limit: num(row[limit.key]),
        perPurchase: perPurchase ? num(row[perPurchase.key]) : null,
      });
      loaded.current = true;
      widgetApi.setDisplayState('displayed');
    })();
    return () => {
      cancelled = true;
    };
  }, [dataMapping, widgetApi]);

  if (!values) return null;
  if (!values.limit) {
    return (
      <div className="sika-meter">
        <div className="sika-meter-label">SIKA authorization</div>
        <div className="sika-meter-off">Off: you confirm every purchase yourself.</div>
      </div>
    );
  }
  const ratio = Math.min(values.spent / values.limit, 1);
  const tone = ratio >= 0.9 ? 'high' : ratio >= 0.6 ? 'mid' : 'low';
  return (
    <div className="sika-meter">
      <div className="sika-meter-label">SIKA authorization · today</div>
      <div className="sika-meter-figures">
        <span className="sika-meter-spent">{usd.format(values.spent)}</span>
        <span className="sika-meter-limit">of {usd.format(values.limit)}</span>
      </div>
      <div className={`sika-meter-track sika-meter-${tone}`} role="meter" aria-valuemin={0} aria-valuemax={values.limit} aria-valuenow={values.spent}>
        <div className="sika-meter-fill" style={{ width: `${ratio * 100}%` }} />
      </div>
      <div className="sika-meter-note">
        {values.perPurchase ? `Up to ${usd.format(values.perPurchase)} per purchase. ` : ''}
        The server refuses anything above these limits, whatever the AI says.
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Parcours d'un paiement : préparé par SIKA → approuvé sur PayPal → encaissé, et les paiements arrêtés en route
// ---------------------------------------------------------------------------

const JOURNEY = [
  { label: 'Prepared by SIKA', statuses: ['Awaiting your confirmation'] },
  { label: 'Waiting for PayPal', statuses: ['Awaiting PayPal approval', 'Approved on PayPal', 'Capturing', 'Being verified', 'Pending at PayPal'] },
  { label: 'Paid', statuses: ['Paid'] },
];

export function PaymentJourney({ dataMapping, widgetApi }: AgWidgetParams<PaymentJourneyDef>) {
  const [counts, setCounts] = useState<Map<string, number>>();
  const loaded = useRef(false);

  useEffect(() => {
    const status = dataMapping.status?.at(0);
    const count = dataMapping.count?.at(0);
    if (!status || !count) {
      widgetApi.setDisplayState('incompleteDataMapping');
      return;
    }
    let cancelled = false;
    (async () => {
      widgetApi.setDisplayState('loading', { prominent: !loaded.current });
      const response = await widgetApi.getData({ fields: [status, count] });
      if (cancelled) return;
      const map = new Map<string, number>();
      for (const row of response.results.rows) {
        map.set(String(row[status.key]), Number(row[count.key]) || 0);
      }
      setCounts(map);
      loaded.current = true;
      widgetApi.setDisplayState(map.size ? 'displayed' : 'noData');
    })();
    return () => {
      cancelled = true;
    };
  }, [dataMapping, widgetApi]);

  if (!counts) return null;
  const known = new Set(JOURNEY.flatMap((s) => s.statuses));
  const stopped = [...counts.entries()].filter(([s]) => !known.has(s));
  return (
    <div className="sika-journey">
      <div className="sika-journey-steps">
        {JOURNEY.map((step, i) => {
          const n = step.statuses.reduce((sum, s) => sum + (counts.get(s) ?? 0), 0);
          return (
            <div key={step.label} className={`sika-journey-step ${i === JOURNEY.length - 1 ? 'is-final' : ''}`}>
              <div className="sika-journey-count">{n}</div>
              <div className="sika-journey-label">{step.label}</div>
            </div>
          );
        })}
      </div>
      {stopped.length > 0 && (
        <div className="sika-journey-stopped">
          {stopped.map(([s, n]) => (
            <span key={s} className="sika-journey-chip">
              {s} · {n}
            </span>
          ))}
        </div>
      )}
      <div className="sika-journey-note">A payment counts as paid only after PayPal confirms the capture.</div>
    </div>
  );
}
