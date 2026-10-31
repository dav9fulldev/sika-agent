import type { AgReportState, AgWidgetLayoutState } from 'ag-studio';

import type { SikaRegistry } from './widgets';

const heading = (text: string) => ({
  type: 'text' as const,
  dataMapping: {},
  format: { style: { text, typography: { fontSize: 20, fontWeight: 'bold' as const } } },
});
const titled = (text: string) => ({ title: { enabled: true, text, typography: { fontSize: 15, fontWeight: 'bold' as const } } });
const at = (xTrack: number, yTrack: number, xSpan: number, ySpan: number): AgWidgetLayoutState => ({ xTrack, yTrack, xSpan, ySpan });

/** Rapport de départ : deux pages prêtes, une page vide pour l'assistant. */
export function initialReport(firstName: string): AgReportState<SikaRegistry> {
  return {
    selectedPageId: 'money',
    panels: { filters: { collapsed: true }, data: { collapsed: true }, edit: { collapsed: true } },
    pages: [
      {
        id: 'money',
        widgets: {
          heading: heading(firstName ? `${firstName}'s payments with SIKA` : 'Your payments with SIKA'),
          'kpi-paid': {
            type: 'value',
            dataMapping: { value: [{ id: 'totalPaid' }] },
            format: { caption: { enabled: true, text: 'Paid through PayPal' } },
          },
          'kpi-count': {
            type: 'value',
            dataMapping: { value: [{ id: 'paymentCount' }] },
            format: { caption: { enabled: true, text: 'Payments prepared' } },
          },
          authorization: {
            type: 'sika-authorization-meter',
            dataMapping: {
              spent: [{ id: 'authorization.spentToday', aggregation: 'sum' }],
              limit: [{ id: 'authorization.dailyLimit', aggregation: 'max' }],
              perPurchase: [{ id: 'authorization.maxPerPurchase', aggregation: 'max' }],
            },
          },
          journey: {
            type: 'sika-payment-journey',
            dataMapping: {
              status: [{ id: 'payments.status' }],
              count: [{ id: 'paymentCount' }],
            },
            format: titled('Payment journey'),
          },
          'by-category': {
            type: 'donut-chart',
            dataMapping: {
              categoryKey: [{ id: 'payments.category' }],
              valueKey: [{ id: 'totalPaid' }],
            },
            format: titled('Spending by category'),
          },
          'who-confirmed': {
            type: 'column-chart-grouped',
            dataMapping: {
              categoryKey: [{ id: 'payments.confirmedBy' }],
              valueKey: [{ id: 'totalPaid' }],
              tooltipKey: [],
            },
            format: titled('Who confirmed the purchase'),
          },
          payments: {
            type: 'grid',
            dataMapping: {
              cols: [
                { id: 'payments.date' },
                { id: 'payments.product' },
                { id: 'payments.amount' },
                { id: 'payments.status' },
                { id: 'payments.confirmedBy' },
                { id: 'payments.paymentMethod' },
              ],
            },
            sort: [{ field: { id: 'payments.date' }, direction: 'desc' }],
            format: titled('All payments'),
          },
        },
        widgetLayout: {
          heading: at(0, 0, 24, 3),
          'kpi-paid': at(0, 3, 6, 8),
          'kpi-count': at(6, 3, 6, 8),
          authorization: at(12, 3, 12, 8),
          journey: at(0, 11, 24, 11),
          'by-category': at(0, 22, 10, 22),
          'who-confirmed': at(10, 22, 14, 22),
          payments: at(0, 44, 24, 20),
        },
        filter: { page: [] },
      },
      {
        id: 'watch',
        widgets: {
          heading: heading('Prices SIKA keeps an eye on'),
          'kpi-followed': {
            type: 'value',
            dataMapping: { value: [{ id: 'followedCount' }] },
            format: { caption: { enabled: true, text: 'Products followed' } },
          },
          'kpi-changes': {
            type: 'value',
            dataMapping: { value: [{ id: 'changeCount' }] },
            format: { caption: { enabled: true, text: 'Changes noticed' } },
          },
          changes: {
            type: 'grid',
            dataMapping: {
              cols: [
                { id: 'price_changes.date' },
                { id: 'price_changes.product' },
                { id: 'price_changes.change' },
                { id: 'price_changes.merchant' },
                { id: 'price_changes.previousPrice', aggregation: 'max' },
                { id: 'price_changes.price', aggregation: 'max' },
                { id: 'price_changes.changePercent', aggregation: 'max' },
              ],
            },
            sort: [{ field: { id: 'price_changes.date' }, direction: 'desc' }],
            format: titled('What changed'),
          },
          followed: {
            type: 'grid',
            dataMapping: {
              cols: [
                { id: 'followed_products.product' },
                { id: 'followed_products.bestPrice', aggregation: 'min' },
                { id: 'followed_products.bestMerchant' },
                { id: 'followed_products.followedBy' },
                { id: 'followed_products.followedUntil' },
              ],
            },
            format: titled('Followed products'),
          },
        },
        widgetLayout: {
          heading: at(0, 0, 24, 3),
          'kpi-followed': at(0, 3, 12, 8),
          'kpi-changes': at(12, 3, 12, 8),
          changes: at(0, 11, 24, 26),
          followed: at(0, 37, 24, 26),
        },
        filter: { page: [] },
      },
      { id: 'ask', widgets: {}, widgetLayout: {}, filter: { page: [] } },
    ],
  } as AgReportState<SikaRegistry>;
}
