CREATE OR REPLACE FUNCTION get_next_invoice_number(p_fy_prefix text) 
RETURNS text AS $$
DECLARE
  seq_val int;
  seq_name text;
BEGIN
  -- Create a sequence dynamically based on financial year if it doesn't exist
  seq_name := 'sales_invoice_seq_' || p_fy_prefix;
  
  -- Execute dynamic SQL to create sequence
  EXECUTE 'CREATE SEQUENCE IF NOT EXISTS ' || quote_ident(seq_name) || ' START 1';
  
  -- Get next value
  EXECUTE 'SELECT nextval(' || quote_literal(seq_name) || ')' INTO seq_val;
  
  RETURN 'MAHADEV-' || p_fy_prefix || '-' || lpad(seq_val::text, 3, '0');
END;
$$ LANGUAGE plpgsql;
