create table if not exists bank_payment_vouchers (
  id uuid primary key default gen_random_uuid(),
  department text,
  person text,
  voucher_no text,
  date date,
  debit_accounts jsonb,
  credit_accounts jsonb,
  amount_paid numeric,
  cheque_details jsonb,
  created_at timestamp default now()
);
