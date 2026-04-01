# Cockpit Dashboard — Kartra Data Rebuild Implementation Spec

## Overview

This document contains the exact code changes needed to rebuild the Cockpit
dashboard's data layer using Paul's recommendation: one relational database
table as the single source of truth, imported from the Kartra CSV export.

**Feed this entire document to Claude Code (or your AI coding tool) in the
cockpit project directory.**

---

## Context

- The dashboard currently uses a complicated multi-layer data pipeline (CSV →
  JSON → Redis → in-memory) that produces inaccurate numbers
- We have a Kartra CSV export with 348,917 transactions from June 2020 to
  April 2026
- The CSV is at: `./kartra-transactions.csv` in the project root
- The database is Supabase PostgreSQL (connection string in .env as DATABASE_URL)
- The app uses Prisma ORM and Next.js

### Current problems
- Churn shows 0%
- Active users shows ~3,829 when Kartra says ~5,502
- Revenue numbers don't account for refunds

### Transaction types in the CSV (and counts)
- Rebill: 173,237 (recurring subscription payments)
- Failed: 63,836 (payment failures)
- Sale: 47,786 (new purchases)
- Cancellation: 40,694 (subscriber left)
- Request Can.: 14,143 (cancellation pending)
- Refund: 8,288 (money returned)
- Revert Can.: 644 (un-canceled / came back)
- Partial refund: 149
- Chargeback: 139

### CSV columns
ID, Transaction_Type, Date, Product, Price_point, Quantity, Seller_username,
Buyer_Username, Buyer_Name, Buyer_Company, Sales_Tax_ID, Buyer_Email,
Buyer_Country, Buyer_State, Buyer_City, Buyer_ZIP, Buyer_Address,
Buyer_Phone_Country, Buyer_Phone, Buyer_IP, Amount (USD), Base_Price (USD),
Sales_tax (USD), Shipping_cost (USD), Coupon_code, Coupon_discount (USD),
Revenue (USD), Affiliate_Username, Affiliate_Name, Affiliate_Email,
Affiliate_Revenue (USD), JV_Username, JV_Name, JV_Email, JV_Revenue (USD),
Your_Net_Profit (USD), Tracking_link, TrackingID1, TrackingID2, Landing_page,
Processor, Processor_transaction_id, Processor_subscription_id,
subscription_id, lead_id, affiliate_id, jv_id, Shipping_Name,
Shipping_Address, Shipping_City, Shipping_ZIP, Shipping_Country,
Shipping_State, Trial, Automatic_Cancellation, Subscription_payment_number,
Rebill_reattempt

---

## Step 1: Add Prisma Schema

Add this model to `prisma/schema.prisma` (keep all existing models):

```prisma
model KartraTransaction {
  id                      Int       @id
  transactionType         String    @map("transaction_type")
  date                    DateTime
  product                 String
  pricePoint              String?   @map("price_point")
  quantity                Int       @default(1)
  buyerUsername            String?   @map("buyer_username")
  buyerName               String?   @map("buyer_name")
  buyerEmail              String?   @map("buyer_email")
  buyerCountry            String?   @map("buyer_country")
  buyerState              String?   @map("buyer_state")
  amount                  Decimal   @db.Decimal(10, 2)
  basePrice               Decimal   @db.Decimal(10, 2) @map("base_price")
  salesTax                Decimal   @db.Decimal(10, 2) @default(0) @map("sales_tax")
  couponCode              String?   @map("coupon_code")
  couponDiscount          Decimal   @db.Decimal(10, 2) @default(0) @map("coupon_discount")
  revenue                 Decimal   @db.Decimal(10, 2)
  affiliateUsername       String?   @map("affiliate_username")
  affiliateRevenue        Decimal   @db.Decimal(10, 2) @default(0) @map("affiliate_revenue")
  netProfit               Decimal   @db.Decimal(10, 2) @map("net_profit")
  processor               String?
  processorTransactionId  String?   @map("processor_transaction_id")
  processorSubscriptionId String?   @map("processor_subscription_id")
  subscriptionId          String?   @map("subscription_id")
  leadId                  String?   @map("lead_id")
  trial                   Boolean   @default(false)
  automaticCancellation   Boolean   @default(false) @map("automatic_cancellation")
  subscriptionPaymentNum  Int?      @map("subscription_payment_number")
  rebillReattempt         Boolean   @default(false) @map("rebill_reattempt")
  createdAt               DateTime  @default(now()) @map("created_at")

  @@map("kartra_transactions")
  @@index([transactionType])
  @@index([date])
  @@index([product])
  @@index([buyerEmail])
  @@index([subscriptionId])
}
```

Then run:
```bash
npx prisma db push
```

---

## Step 2: Create CSV Import Script

Create file: `scripts/import-kartra-csv.ts`

This script should:
1. Read `./kartra-transactions.csv` using a streaming CSV parser (use `csv-parse` package)
2. Parse each row and map columns to the Prisma model
3. Use `prisma.kartraTransaction.upsert()` with the `id` field to avoid duplicates
4. Process in batches of 500 rows using `prisma.$transaction()` for performance
5. Log progress every 10,000 rows
6. Handle data type conversions:
   - `Transaction_Type` → string as-is
   - `Date` → parse as DateTime
   - `Amount (USD)` → parse as Decimal
   - `Trial` → "Yes" = true, anything else = false
   - `Automatic_Cancellation` → "Yes" = true, anything else = false
   - `Rebill_reattempt` → "1" = true, "0" = false
   - `subscription_id` → store as string
   - Empty strings → null

Install needed packages:
```bash
npm install csv-parse
```

Add to package.json scripts:
```json
"import:kartra": "npx tsx scripts/import-kartra-csv.ts"
```

Run with:
```bash
npm run import:kartra
```

---

## Step 3: Update Dashboard Queries

Replace the existing dashboard data fetching in `src/lib/dashboard.ts` (or
wherever the dashboard data is loaded) with queries against the new
`kartraTransaction` table.

### Active Subscribers (should be ~5,502)

Active subscribers = unique subscription_ids where:
- The subscription has at least one "Sale" or "Rebill" transaction
- AND the subscription does NOT have a "Cancellation" as its most recent
  status-changing transaction
- AND "Request Can." without a following "Revert Can." should count as
  canceled

```sql
-- Conceptual query (implement via Prisma):
-- Find subscriptions whose last status event is NOT a cancellation
WITH latest_status AS (
  SELECT DISTINCT ON (subscription_id)
    subscription_id,
    transaction_type,
    date
  FROM kartra_transactions
  WHERE transaction_type IN ('Sale', 'Rebill', 'Cancellation', 'Request Can.', 'Revert Can.')
    AND subscription_id IS NOT NULL
    AND subscription_id != 'N/A'
  ORDER BY subscription_id, date DESC
)
SELECT COUNT(*) FROM latest_status
WHERE transaction_type IN ('Sale', 'Rebill', 'Revert Can.');
```

### Churn Rate

Monthly churn = (Cancellations in month) / (Active subscribers at start of month) × 100

```
- Count cancellations (type = "Cancellation") per month
- Count active subs at start of each month
- Divide
```

Also break down into:
- **Voluntary churn**: `Cancellation` where `automatic_cancellation` = false (or "No")
- **Involuntary churn**: `Cancellation` where `automatic_cancellation` = true (or "Yes")
  (These are failed-payment cancellations — what Paul was talking about)

### Revenue

```
Total Revenue = SUM(revenue) WHERE transaction_type IN ('Sale', 'Rebill')
Minus Refunds = SUM(revenue) WHERE transaction_type IN ('Refund', 'Partial refund')
Minus Chargebacks = SUM(revenue) WHERE transaction_type = 'Chargeback'
Net Revenue = Total Revenue - Refunds - Chargebacks
```

### New Customers (per period)

```
COUNT of unique buyer_email WHERE transaction_type = 'Sale'
  AND subscription_payment_number = 1
  AND date within period
```

### Failed Payments

```
COUNT WHERE transaction_type = 'Failed' AND date within period
```

This is important for the involuntary churn insight Paul mentioned.

---

## Step 4: Add Transaction Table View (for reconciliation)

Create a new page at: `src/app/admin/transactions/page.tsx`

This page should have:
1. A data table showing all transactions
2. Filters at the top:
   - Date range picker (start date → end date)
   - Transaction type dropdown (Sale, Rebill, Failed, Cancellation, Refund, etc.)
   - Product dropdown
   - Search by email
3. Sortable columns (click to sort by date, amount, etc.)
4. Pagination (50 rows per page)
5. Summary row at the top showing:
   - Total transactions matching filter
   - Total revenue matching filter
   - Total refunds matching filter

This is what Paul recommended for reconciliation — so Dominick can cross-check
the dashboard numbers against Kartra directly.

---

## Step 5: Keep the Webhook for Real-Time Updates

The existing Kartra webhook (IPN payments) should continue working, but
instead of writing to Redis/JSON, it should insert directly into the
`kartra_transactions` table.

Update the webhook handler at the API route (likely
`src/app/api/kartra-webhook/route.ts` or similar) to:

1. Receive the webhook payload
2. Map it to a KartraTransaction record
3. Use `prisma.kartraTransaction.upsert()` with the transaction ID
4. This way, real-time data and CSV imports use the same table

---

## Step 6: Data Validation Rules

When importing or receiving webhook data:

1. **Deduplication**: Use the Kartra `ID` field as the primary key. Upsert
   (insert or update) to prevent duplicate transactions.
2. **Required fields**: ID, Transaction_Type, Date, Amount must be present
3. **Date validation**: Must be a valid date, not in the future
4. **Amount validation**: Must be a valid number ≥ 0
5. **Skip rows with empty ID**: These are malformed

---

## Important Notes

- The CSV file (`kartra-transactions.csv`) contains customer PII. It is
  already in .gitignore (*.csv pattern). NEVER commit it to git.
- The import may take several minutes due to 348K rows. That's normal.
- After import, verify by checking: total active subs should be ~5,502
- If numbers still don't match Kartra, use the transaction table view
  (Step 4) to find discrepancies.
- The main product is "Crate Hackers" (316K of 349K transactions). Most
  dashboard metrics should focus on this product.
