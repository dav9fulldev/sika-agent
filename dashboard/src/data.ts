import type { AgDataSourcesDefinition, AgExpressionFieldDefinition, AgFieldDefinition } from 'ag-studio';

import type { DashboardData, Row } from './api';
import type { SikaRegistry } from './widgets';

type Field = AgFieldDefinition<SikaRegistry>;

const usd = { format: new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }) };

const text = (id: string, name: string, description: string, extra: Partial<Field> = {}): Field => ({
  id, name, description, format: 'textFormat', ...extra,
});
const money = (id: string, name: string, description: string): Field => ({
  id, name, description, format: 'currencyFormat', formatOptions: usd,
});
const when = (id: string, name: string, description: string): Field => ({
  id, name, description, format: 'dateTimeFormat',
});

// Les dates arrivent en ISO ; le moteur de Studio les lit le plus vite en millisecondes UTC
function withDates(rows: Row[], fields: string[]): Row[] {
  return rows.map((row) => {
    const copy = { ...row };
    for (const f of fields) {
      const value = copy[f];
      copy[f] = typeof value === 'string' ? Date.parse(value) : null;
    }
    return copy;
  });
}

const expressions: AgExpressionFieldDefinition<SikaRegistry>[] = [
  {
    id: 'totalPaid',
    name: 'Total paid',
    description: 'Sum of payments captured by PayPal (only payments PayPal confirmed).',
    isMeasure: true,
    format: 'currencyFormat',
    formatOptions: usd,
    expression: { id: 'payments.paidAmount', aggregation: 'sum' },
  },
  {
    id: 'paymentCount',
    name: 'Payments',
    description: 'Number of payments SIKA prepared, whatever their status.',
    isMeasure: true,
    format: 'integerFormat',
    expression: { id: 'payments.paymentId', aggregation: 'count' },
  },
  {
    id: 'followedCount',
    name: 'Products followed',
    description: 'Number of web products SIKA follows for the user.',
    isMeasure: true,
    format: 'integerFormat',
    expression: { id: 'followed_products.product', aggregation: 'count' },
  },
  {
    id: 'changeCount',
    name: 'Changes noticed',
    description: 'Number of price or stock changes SIKA noticed on followed products.',
    isMeasure: true,
    format: 'integerFormat',
    expression: { id: 'price_changes.product', aggregation: 'count' },
  },
];

export function buildSources(data: DashboardData): AgDataSourcesDefinition<SikaRegistry> {
  const t = data.tables;
  return {
    description:
      "SIKA Pay data for the signed-in user (PayPal sandbox, no real money). Payments prepared by SIKA and paid with PayPal, " +
      'products SIKA follows on real merchant sites, the price and stock changes it noticed, PayPal subscriptions, ' +
      'and the spending authorization the user granted to SIKA. Amounts are USD unless the currency field says otherwise.',
    sources: [
      {
        id: 'payments',
        name: 'Payments',
        description: 'One row per purchase SIKA prepared. paidAmount is non-zero only when PayPal confirmed the capture.',
        data: withDates(t.payments, ['date']),
        fields: [
          text('paymentId', 'Payment ID', 'SIKA reference of the payment.', { hide: true }),
          when('date', 'Date', 'When SIKA prepared the payment.'),
          text('product', 'Product', 'What was bought.'),
          text('category', 'Category', 'Catalog category of the product.'),
          text('merchant', 'Merchant', 'Store that sold the product.'),
          { id: 'quantity', name: 'Quantity', description: 'Units bought.', format: 'integerFormat' },
          money('amount', 'Amount', 'Order total (captured amount for paid orders).'),
          money('paidAmount', 'Paid amount', 'Amount PayPal captured; 0 when the payment did not complete.'),
          text('currency', 'Currency', 'Currency of the payment.'),
          text('status', 'Status', 'Paid, Awaiting PayPal approval, Cancelled, Expired, Declined…'),
          text('confirmedBy', 'Confirmed by', 'Who confirmed the purchase: the user, or SIKA within the authorization.'),
          text('paymentMethod', 'Payment method', 'PayPal approval each time, or the saved PayPal account.'),
          money('budget', 'Budget', 'Budget the user gave SIKA for this purchase, if any.'),
          { id: 'isPaid', name: 'Paid', description: 'True when PayPal confirmed the capture.', format: 'booleanFormat' },
        ],
      },
      {
        id: 'followed_products',
        name: 'Followed products',
        description: 'Web products SIKA follows: shown by SIKA (30 days) or with a price alert the user asked for.',
        data: withDates(t.followed_products, ['followedSince', 'followedUntil']),
        fields: [
          text('product', 'Product', 'Product name.'),
          text('followedBy', 'Followed by', 'SIKA (automatic) or Your price alert.'),
          text('status', 'Status', 'Following or Alert triggered.'),
          money('bestPrice', 'Best price', 'Lowest price SIKA knows across merchants.'),
          text('bestMerchant', 'Best merchant', 'Merchant with the lowest known price.'),
          money('targetPrice', 'Target price', 'Price the user asked to be alerted at, if any.'),
          text('currency', 'Currency', 'Currency of the prices.'),
          when('followedSince', 'Followed since', 'When SIKA started following the product.'),
          when('followedUntil', 'Followed until', 'End of an automatic follow.'),
        ],
      },
      {
        id: 'price_changes',
        name: 'Price changes',
        description: 'Changes SIKA noticed and told the user about.',
        data: withDates(t.price_changes, ['date']),
        fields: [
          when('date', 'Date', 'When the change was noticed.'),
          text('product', 'Product', 'Product name.'),
          text('change', 'Change', 'Price drop, Price increase, Back in stock, Out of stock, Cheaper offer, Offer removed, Target price reached.'),
          text('merchant', 'Merchant', 'Merchant concerned.'),
          money('price', 'New price', 'Price after the change.'),
          money('previousPrice', 'Previous price', 'Price before the change.'),
          { id: 'changePercent', name: 'Change %', description: 'Relative price change (negative = cheaper).', format: 'percentageFormat' },
          text('currency', 'Currency', 'Currency of the prices.'),
        ],
      },
      {
        id: 'subscriptions',
        name: 'Subscriptions',
        description: 'PayPal subscriptions prepared by SIKA.',
        data: withDates(t.subscriptions, ['startedOn']),
        fields: [
          text('plan', 'Plan', 'Subscription plan.'),
          money('price', 'Price', 'Price per billing cycle.'),
          text('currency', 'Currency', 'Currency.'),
          text('status', 'Status', 'Subscription status.'),
          text('nextBilling', 'Next billing', 'Next billing date reported by PayPal.'),
          when('startedOn', 'Started on', 'When the subscription was prepared.'),
        ],
      },
      {
        id: 'authorization',
        name: 'SIKA authorization',
        description: 'Spending authorization the user granted: SIKA may confirm purchases within these limits only.',
        data: withDates(t.authorization, ['expiresAt']),
        fields: [
          { id: 'active', name: 'Active', description: 'Whether SIKA may confirm purchases for the user.', format: 'booleanFormat' },
          money('maxPerPurchase', 'Max per purchase', 'Highest amount SIKA may confirm in one purchase.'),
          money('dailyLimit', 'Daily limit', 'Highest total SIKA may confirm per day.'),
          money('spentToday', 'Spent today', 'Total SIKA confirmed today.'),
          money('remainingToday', 'Remaining today', 'What SIKA may still confirm today.'),
          text('currency', 'Currency', 'Currency of the limits.'),
          when('expiresAt', 'Expires', 'When the authorization ends.'),
        ],
      },
    ],
    expressions,
  };
}
