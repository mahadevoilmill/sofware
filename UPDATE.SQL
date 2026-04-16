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
