import { writable } from 'svelte/store';

export type Language = 'en' | 'gu';

export const language = writable<Language>('en');

// Financial Year Logic
function getCurrentFY() {
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth(); // 0-indexed, 3 is April
  // If before April, we are in the previous year's FY
  const startYear = month >= 3 ? year : year - 1;
  return `${startYear}-${(startYear + 1).toString().slice(-2)}`;
}

export const financialYear = writable<string>(getCurrentFY());

export function getFYDateRange(fy: string) {
  const startYear = parseInt(fy.split('-')[0]);
  const endYear = startYear + 1;
  return {
    start: `${startYear}-04-01`,
    end: `${endYear}-03-31`
  };
}

export const translations = {
  en: {
    dashboard: 'Dashboard',
    inventory: 'Inventory',
    production: 'Production',
    sales: 'Sales / Billing',
    expenses: 'Expenses',
    customers: 'Customers',
    suppliers: 'Suppliers',
    banking: 'Banking',
    reports: 'Reports',
    settings: 'Vendor Info',
    purchases: 'Purchases',
    logout: 'Logout',
    login: 'Login',
    total_sales: 'Total Sales',
    total_purchases: 'Total Purchases',
    total_stock: 'Total Stock',
    total_expenses: 'Total Expenses',
    net_profit: 'Net Profit',
    customer_name: 'Customer Name',
    gst_no: 'GST Number',
    product: 'Product',
    quantity: 'Quantity',
    rate: 'Rate',
    invoice: 'Invoice',
    generate_pdf: 'Generate PDF',
    raw_materials: 'Raw Materials',
    oil_stock: 'Oil Stock',
    khali: 'Khali',
    electricity: 'Electricity',
    labor: 'Labor',
    transport: 'Transport',
    other: 'Other'
  },
  gu: {
    dashboard: 'ડેશબોર્ડ',
    inventory: 'ઈન્વેન્ટરી',
    production: 'ઉત્પાદન',
    sales: 'વેચાણ / બિલિંગ',
    expenses: 'ખર્ચ',
    customers: 'ગ્રાહકો',
    suppliers: 'સપ્લાયર્સ',
    banking: 'બેંકિંગ',
    reports: 'રિપોર્ટ્સ',
    settings: 'વેન્ડર માહિતી',
    purchases: 'ખરીદી',
    logout: 'લોગઆઉટ',
    login: 'લોગિન',
    total_sales: 'કુલ વેચાણ',
    total_purchases: 'કુલ ખરીદી',
    total_stock: 'કુલ સ્ટોક',
    total_expenses: 'કુલ ખર્ચ',
    net_profit: 'ચોખ્ખો નફો',
    customer_name: 'ગ્રાહકનું નામ',
    gst_no: 'GST નંબર',
    product: 'પ્રોડક્ટ',
    quantity: 'જથ્થો',
    rate: 'ભાવ',
    invoice: 'ભરતિયું',
    generate_pdf: 'PDF બનાવો',
    raw_materials: 'કાચો માલ',
    oil_stock: 'તેલનો સ્ટોક',
    khali: 'ખોળ',
    electricity: 'વીજળી',
    labor: 'મજૂરી',
    transport: 'ટ્રાન્સપોર્ટ',
    other: 'અન્ય'
  }
};
