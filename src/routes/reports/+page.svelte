<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations } from '$lib/i18n';
  import { FileSpreadsheet, TrendingUp, TrendingDown } from 'lucide-svelte';

  const t = $derived(translations[$language]);

  let sales = $state<any[]>([]);
  let expenses = $state<any[]>([]);
  
  let totalSales = $derived(sales.reduce((acc, curr) => acc + (curr.total_amount || 0), 0));
  let totalExpenses = $derived(expenses.reduce((acc, curr) => acc + (curr.amount || 0), 0));
  let netProfit = $derived(totalSales - totalExpenses);

  onMount(async () => {
    const { data: sData } = await supabase.from('sales').select('*');
    sales = sData || [];

    const { data: eData } = await supabase.from('expenses').select('*');
    expenses = eData || [];
  });

  function exportToCSV() {
    const headers = ['Date', 'Type', 'Description', 'Amount'];
    const salesRows = sales.map(s => [new Date(s.created_at).toLocaleDateString("en-IN"), 'Sale', s.invoice_number, s.total_amount]);
    const expenseRows = expenses.map(e => [new Date(e.expense_date).toLocaleDateString("en-IN"), 'Expense', e.description, e.amount]);
    
    const csvContent = [
      headers.join(','),
      ...salesRows.map(r => r.join(',')),
      ...expenseRows.map(r => r.join(','))
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `mahadev_oil_mill_report_${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
  }
</script>

<div class="reports-container">
  <div class="header">
    <h2>{t.reports}</h2>
    <button class="export-btn" onclick={exportToCSV}>
      <FileSpreadsheet size={18} /> Export CSV
    </button>
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
    <h3>Transaction History</h3>
    <table>
      <thead>
        <tr>
          <th>Date</th>
          <th>Type</th>
          <th>Description</th>
          <th>Amount</th>
        </tr>
      </thead>
      <tbody>
        {#each sales as sale}
          <tr>
            <td>{new Date(sale.created_at).toLocaleDateString("en-IN")}</td>
            <td>Sale</td>
            <td>{sale.invoice_number}</td>
            <td class="amt-pos">₹{sale.total_amount.toLocaleString()}</td>
          </tr>
        {/each}
        {#each expenses as expense}
          <tr>
            <td>{new Date(expense.expense_date).toLocaleDateString("en-IN")}</td>
            <td>Expense</td>
            <td>{expense.description}</td>
            <td class="amt-neg">₹{expense.amount.toLocaleString()}</td>
          </tr>
        {/each}
      </tbody>
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
