<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations } from '$lib/i18n';
  import { FileSpreadsheet, TrendingUp, TrendingDown } from 'lucide-svelte';

  const t = $derived(translations[$language]);

  let sales = $state<any[]>([]);
  let expenses = $state<any[]>([]);
  
  let selectedMonth = $state(new Date().toISOString().slice(0, 7));

  let filteredSales = $derived(sales
    .filter(s => s.sales_date?.startsWith(selectedMonth))
    .sort((a, b) => new Date(a.sales_date).getTime() - new Date(b.sales_date).getTime()));
  let filteredExpenses = $derived(expenses
    .filter(e => e.expense_date?.startsWith(selectedMonth))
    .sort((a, b) => new Date(e.expense_date).getTime() - new Date(b.expense_date).getTime()));
  
  let salesTotals = $derived(filteredSales.reduce((acc, curr) => ({
    rate: acc.rate + (curr.rate || 0),
    cgst: acc.cgst + (curr.cgst || 0),
    sgst: acc.sgst + (curr.sgst || 0),
    total: acc.total + (curr.total_amount || 0)
  }), { rate: 0, cgst: 0, sgst: 0, total: 0 }));

  let totalSales = $derived(filteredSales.reduce((acc, curr) => acc + (curr.total_amount || 0), 0));
  let totalExpenses = $derived(filteredExpenses.reduce((acc, curr) => acc + (curr.amount || 0), 0));
  let netProfit = $derived(totalSales - totalExpenses);

  onMount(async () => {
    const { data: sData } = await supabase.from('sales').select('*, customers(name)');
    sales = sData || [];

    const { data: eData } = await supabase.from('expenses').select('*');
    expenses = eData || [];
  });

  function exportToCSV() {
    const salesHeaders = ['Date', 'Invoice #', 'Customer', 'Product', 'HSN/SAC', 'Quantity', 'Unit', 'Rate', 'CGST', 'SGST', 'Total Amount', 'Selling Partner', 'Payment Mode', 'Payment Details'];
    const expenseHeaders = ['Date', 'Description', 'Category', 'Amount', 'Payment Mode', 'Payment Details'];
    
    const salesRows = filteredSales.map(s => [
      new Date(s.sales_date).toLocaleDateString("en-IN"),
      s.invoice_number,
      (s.customers as any)?.name || 'N/A',
      s.product_name || s.inventory?.item_name || 'N/A',
      s.hsn_sac || '',
      s.quantity,
      s.unit,
      s.rate.toFixed(2),
      s.cgst.toFixed(2),
      s.sgst.toFixed(2),
      s.total_amount.toFixed(2),
      s.selling_partner || '',
      s.payment_mode || '',
      s.payment_details || ''
    ]);

    const salesTotal = filteredSales.reduce((acc, curr) => acc + (curr.total_amount || 0), 0);
    const salesTotalRow = ['', '', '', '', '', '', '', salesTotals.rate.toFixed(2), salesTotals.cgst.toFixed(2), salesTotals.sgst.toFixed(2), salesTotal.toFixed(2), '', '', ''];

    const expenseRows = filteredExpenses.map(e => [
      new Date(e.expense_date).toLocaleDateString("en-IN"),
      e.description,
      e.category || '',
      e.amount.toFixed(2),
      e.payment_mode || '',
      e.payment_details || ''
    ]);

    const expenseTotal = filteredExpenses.reduce((acc, curr) => acc + (curr.amount || 0), 0);
    const expenseTotalRow = ['', '', 'TOTAL:', expenseTotal.toFixed(2), '', ''];
    
    const csvContent = [
      '--- SALES ---',
      salesHeaders.join(','),
      ...salesRows.map(r => r.map(cell => `"${cell}"`).join(',')),
      salesTotalRow.map(cell => `"${cell}"`).join(','),
      '',
      '--- EXPENSES ---',
      expenseHeaders.join(','),
      ...expenseRows.map(r => r.map(cell => `"${cell}"`).join(',')),
      expenseTotalRow.map(cell => `"${cell}"`).join(',')
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `mahadev_full_report_${selectedMonth}.csv`;
    a.click();
  }
</script>

<div class="reports-container">
  <div class="header">
    <h2>{t.reports}</h2>
    <div style="display: flex; gap: 10px; align-items: center;">
      <input type="month" bind:value={selectedMonth} />
      <button class="export-btn" onclick={exportToCSV}>
        <FileSpreadsheet size={18} /> Export CSV
      </button>
    </div>
  </div>

  <div class="summary-cards">
    <div class="summary-card profit">
      <h3>Net Profit</h3>
      <p>₹{netProfit.toLocaleString()}</p>
      {#if netProfit >= 0}
        <TrendingUp color="#2ecc71" />
      {:else}
        <TrendingDown color="#e74c3c" />
      {/if}
    </div>

    <div class="summary-card">
      <h3>Revenue</h3>
      <p>₹{totalSales.toLocaleString()}</p>
    </div>

    <div class="summary-card">
      <h3>Expenses</h3>
      <p>₹{totalExpenses.toLocaleString()}</p>
    </div>
  </div>

  <div class="report-details">
    <h3>Transaction History ({selectedMonth})</h3>
    <table>
      <thead>
        <tr>
          <th>Description</th>
          <th>Date</th>
          <th>Customer</th>
          <th>Type</th>
          <th>Rate</th>
          <th>CGST</th>
          <th>SGST</th>
          <th>Amount</th>
        </tr>
      </thead>
      <tbody>
        {#each filteredSales as sale}
          <tr>
            <td>{sale.invoice_number}</td>
            <td>{new Date(sale.sales_date).toLocaleDateString("en-IN")}</td>
            <td>{(sale.customers as any)?.name || 'N/A'}</td>
            <td>Sale</td>
            <td>{sale.rate.toFixed(2)}</td>
            <td>{sale.cgst.toFixed(2)}</td>
            <td>{sale.sgst.toFixed(2)}</td>
            <td class="amt-pos">₹{sale.total_amount.toLocaleString()}</td>
          </tr>
        {/each}
        {#each filteredExpenses as expense}
          <tr>
            <td>{expense.description}</td>
            <td>{new Date(expense.expense_date).toLocaleDateString("en-IN")}</td>
            <td>N/A</td>
            <td>Expense</td>
            <td>-</td>
            <td>-</td>
            <td>-</td>
            <td class="amt-neg">₹{expense.amount.toLocaleString()}</td>
          </tr>
        {/each}
      </tbody>
      <tfoot>
        <tr style="font-weight: bold; background-color: #f9f9f9;">
          <td colspan="4">TOTALS</td>
          <td>{salesTotals.rate.toFixed(2)}</td>
          <td>{salesTotals.cgst.toFixed(2)}</td>
          <td>{salesTotals.sgst.toFixed(2)}</td>
          <td class="amt-pos">₹{salesTotals.total.toLocaleString()}</td>
        </tr>
      </tfoot>
    </table>
  </div>
</div>

<style>
  .reports-container .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 30px;
  }

  .export-btn {
    background-color: #2ecc71;
    color: white;
    border: none;
    padding: 10px 20px;
    border-radius: 4px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .summary-cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 20px;
    margin-bottom: 40px;
  }

  .summary-card {
    background: white;
    padding: 25px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    text-align: center;
  }

  .summary-card h3 {
    margin: 0;
    font-size: 0.9rem;
    color: #7f8c8d;
    text-transform: uppercase;
  }

  .summary-card p {
    font-size: 2rem;
    font-weight: bold;
    margin: 10px 0;
    color: #2c3e50;
  }

  .report-details {
    background: white;
    padding: 25px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
  }

  table {
    width: 100%;
    border-collapse: collapse;
  }

  th, td {
    padding: 12px;
    text-align: left;
    border-bottom: 1px solid #eee;
  }

  .amt-pos { color: #2ecc71; font-weight: 500; }
  .amt-neg { color: #e74c3c; font-weight: 500; }
</style>
