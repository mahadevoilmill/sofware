INSERT INTO inventory (item_name, quantity, unit, hsn_sac) VALUES
('Soyabean Oil', 0, 'liter', '1507'),
('Groundnut Oil', 0, 'liter', '1508'),
('Olive Oil', 0, 'liter', '1509'),
('Palm Oil', 0, 'liter', '1511'),
('Sunflower Oil', 0, 'liter', '1512'),
('Coconut Oil', 0, 'liter', '1513')
ON CONFLICT (item_name) DO UPDATE SET hsn_sac = EXCLUDED.hsn_sac;
