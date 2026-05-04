-- Profiles table for users (Admin/Staff)
create table profiles (
  id uuid references auth.users not null primary key,
  full_name text,
  role text check (role in ('admin', 'staff')) default 'staff',
  updated_at timestamp with time zone default now()
);

-- Customers table
create table customers (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  address text,
  mobile text,
  gst_number text,
  created_at timestamp with time zone default now()
);

-- Inventory table
create table inventory (
  id uuid default gen_random_uuid() primary key,
  item_name text not null unique,
  quantity numeric not null default 0,
  unit text not null,
  new_stock numeric not null default 0,
  old_stock numeric not null default 0,
  updated_at timestamp with time zone default now()
);

-- Inventory transactions (track daily in/out)
create table inventory_transactions (
  id uuid default gen_random_uuid() primary key,
  inventory_id uuid references inventory(id) not null,
  transaction_type text check (transaction_type in ('stock_in', 'stock_out')) not null,
  quantity numeric not null,
  notes text,
  transaction_date date default current_date,
  is_done boolean default false,
  created_at timestamp with time zone default now()
);

-- Production table
create table production (
  id uuid default gen_random_uuid() primary key,
  production_date date default current_date,
  input_item uuid references inventory(id),
  input_qty numeric not null,
  output_oil_item uuid references inventory(id),
  output_oil_qty numeric not null,
  output_khali_qty numeric not null,
  is_done boolean default false,
  created_at timestamp with time zone default now()
);

-- Sales table (Invoices)
create table sales (
  id uuid default gen_random_uuid() primary key,
  invoice_number text unique not null,
  customer_id uuid references customers(id),
  product_item uuid references inventory(id),
  product_name text,
  quantity numeric not null,
  rate numeric not null,
  cgst numeric not null, -- 2.5%
  sgst numeric not null, -- 2.5%
  total_amount numeric not null,
  sales_date date default current_date,
  is_done boolean default false,
  created_at timestamp with time zone default now()
);

-- Expenses table
create table expenses (
  id uuid default gen_random_uuid() primary key,
  expense_date date default current_date,
  description text not null,
  amount numeric not null,
  category text check (category in ('electricity', 'labor', 'transport', 'other')),
  is_done boolean default false,
  created_at timestamp with time zone default now()
);

-- RLS (Row Level Security) - Simplified for this demo
alter table profiles enable row level security;
alter table customers enable row level security;
alter table inventory enable row level security;
alter table production enable row level security;
alter table sales enable row level security;
alter table expenses enable row level security;

-- Policies (Allow all for authenticated users for now, can be restricted by role later)
create policy "Public profiles are viewable by everyone." on profiles for select using (true);
create policy "Users can insert their own profile." on profiles for insert with check (auth.uid() = id);
create policy "Users can update own profile." on profiles for update using (auth.uid() = id);

create policy "Authenticated users can CRUD customers" on customers for all using (auth.role() = 'authenticated');
create policy "Authenticated users can CRUD inventory" on inventory for all using (auth.role() = 'authenticated');
create policy "Authenticated users can CRUD production" on production for all using (auth.role() = 'authenticated');
create policy "Authenticated users can CRUD sales" on sales for all using (auth.role() = 'authenticated');
create policy "Authenticated users can CRUD expenses" on expenses for all using (auth.role() = 'authenticated');

-- Function to handle auto-incrementing invoice number MAHADEV-001
create sequence if not exists sales_invoice_seq;
create or replace function next_invoice_number() 
returns text as $$
declare
  seq_val int;
begin
  select nextval('sales_invoice_seq') into seq_val;
  return 'MAHADEV-' || lpad(seq_val::text, 3, '0');
end;
$$ language plpgsql;

-- Default inventory items
insert into inventory (item_name, quantity, unit) values
('Groundnut Raw', 0, 'kg'),
('Sesame Raw', 0, 'kg'),
('Groundnut Oil', 0, 'liter'),
('Sesame Oil', 0, 'liter'),
('Khali', 0, 'kg')
on conflict (item_name) do nothing;

-- Added payment columns
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'Cash';
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS payment_details TEXT;
