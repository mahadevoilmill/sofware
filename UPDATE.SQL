-- SQL Update Script for Mahadev Oil Mill ERP
-- Run this in your Supabase SQL Editor

-- 1. Create table for company/vendor settings
CREATE TABLE IF NOT EXISTS company_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name TEXT DEFAULT 'MAHADEV OIL MILL',
    address TEXT DEFAULT '902 NAGARDAS NI KHADKI, VASAD',
    gstin TEXT DEFAULT '24ADIFS2075H1Z2',
    pan TEXT DEFAULT 'ADHFS2075H',
    state_name TEXT DEFAULT 'Gujarat',
    state_code TEXT DEFAULT '24',
    contact_no TEXT DEFAULT '9879944395',
    bank_name TEXT DEFAULT 'Nutan Nagarik Sahakari Bank Ltd.',
    account_no TEXT DEFAULT '003138230010434',
    branch_ifsc TEXT DEFAULT 'VASAD & NNSB0128003',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Enable Row Level Security (RLS)
ALTER TABLE company_settings ENABLE ROW LEVEL SECURITY;

-- 3. Allow authenticated users to manage company settings
-- If this policy already exists, the script will skip this step
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'company_settings' 
        AND policyname = 'Authenticated users can CRUD company settings'
    ) THEN
        CREATE POLICY "Authenticated users can CRUD company settings" 
        ON company_settings FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;
END $$;

-- 4. Insert initial default data if table is empty
INSERT INTO company_settings (company_name) 
SELECT 'MAHADEV OIL MILL' 
WHERE NOT EXISTS (SELECT 1 FROM company_settings LIMIT 1);

-- 5. Add payment_mode and payment_details to sales table
ALTER TABLE sales ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'Cash';
ALTER TABLE sales ADD COLUMN IF NOT EXISTS payment_details TEXT;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS hsn_sac TEXT;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS gst_rate numeric DEFAULT 0;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS gst_amount numeric DEFAULT 0;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS total_with_gst numeric DEFAULT 0;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS state_name TEXT DEFAULT 'Gujarat';
ALTER TABLE customers ADD COLUMN IF NOT EXISTS state_code TEXT DEFAULT '24';
CREATE TABLE IF NOT EXISTS purchases (
  id uuid default gen_random_uuid() primary key,
  purchase_number text unique not null,
  supplier_name text,
  product_item uuid references inventory(id),
  product_name text,
  quantity numeric not null,
  rate numeric not null,
  gst_rate numeric default 5,
  cgst numeric not null,
  sgst numeric not null,
  total_amount numeric not null,
  purchase_date date default current_date,
  payment_mode text default 'Cash',
  payment_details text,
  is_done boolean default false,
  created_at timestamp with time zone default now()
);
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'purchases' 
        AND policyname = 'Authenticated users can CRUD purchases'
    ) THEN
        CREATE POLICY "Authenticated users can CRUD purchases" 
        ON purchases FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;
END $$;
ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS upi_id TEXT DEFAULT '8849735425@upi';
ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS fssai_code TEXT;

-- 6. Create suppliers table
CREATE TABLE IF NOT EXISTS suppliers (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  address text,
  city text,
  state_name text default 'Gujarat',
  state_code text default '24',
  mobile text,
  gst_number text,
  partner_name text,
  partner_mobile text,
  created_at timestamp with time zone default now()
);

ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'suppliers' 
        AND policyname = 'Authenticated users can CRUD suppliers'
    ) THEN
        CREATE POLICY "Authenticated users can CRUD suppliers" 
        ON suppliers FOR ALL 
        USING (auth.role() = 'authenticated');
    END IF;
END $$;

-- 7. Create storage bucket for company assets (if not exists)
INSERT INTO storage.buckets (id, name, public)
VALUES ('company-assets', 'company-assets', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies - skip if already exists
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'company-assets') THEN
        -- Bucket exists, policies should be handled manually if needed
        NULL;
    END IF;
END $$;

-- 8. Voucher Entry Tables
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vouchers') THEN
        CREATE TABLE vouchers (
          id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
          voucher_type TEXT NOT NULL,
          name TEXT,
          voucher_number TEXT UNIQUE NOT NULL,
          voucher_date DATE DEFAULT CURRENT_DATE,
          total_amount NUMERIC NOT NULL DEFAULT 0,
          gst_amount NUMERIC DEFAULT 0,
          narration TEXT,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'voucher_entries') THEN
        CREATE TABLE voucher_entries (
          id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
          voucher_id UUID REFERENCES vouchers(id) ON DELETE CASCADE,
          ledger_name TEXT NOT NULL,
          debit NUMERIC DEFAULT 0,
          credit NUMERIC DEFAULT 0,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'ledgers') THEN
        CREATE TABLE ledgers (
          id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          ledger_type TEXT DEFAULT 'general',
          opening_balance NUMERIC DEFAULT 0,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
    END IF;
END $$;

-- Insert default ledgers
INSERT INTO ledgers (name, ledger_type) VALUES
  ('Cash', 'cash'),
  ('Bank', 'bank'),
  ('Sales', 'income'),
  ('Purchase', 'expense'),
  ('GST Output', 'liability'),
  ('GST Input', 'asset')
ON CONFLICT (name) DO NOTHING;

-- Enable RLS
ALTER TABLE vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE voucher_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledgers ENABLE ROW LEVEL SECURITY;

-- Create policies
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'vouchers' AND policyname = 'Authenticated users can CRUD vouchers') THEN
        CREATE POLICY "Authenticated users can CRUD vouchers" ON vouchers FOR ALL USING (auth.role() = 'authenticated');
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'voucher_entries' AND policyname = 'Authenticated users can CRUD voucher_entries') THEN
        CREATE POLICY "Authenticated users can CRUD voucher_entries" ON voucher_entries FOR ALL USING (auth.role() = 'authenticated');
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'ledgers' AND policyname = 'Authenticated users can CRUD ledgers') THEN
        CREATE POLICY "Authenticated users can CRUD ledgers" ON ledgers FOR ALL USING (auth.role() = 'authenticated');
    END IF;
END $$;

-- Add name column to vouchers if not exists
ALTER TABLE vouchers ADD COLUMN IF NOT EXISTS name TEXT;
