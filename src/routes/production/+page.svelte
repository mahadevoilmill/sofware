<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations, financialYear, getFYDateRange } from '$lib/i18n';
  import { Factory, Plus, Download, CheckCircle, Circle } from 'lucide-svelte';
  import jsPDF from 'jspdf';
  import autoTable from 'jspdf-autotable';

  const t = $derived(translations[$language]);

  let inventory = $state<any[]>([]);
  let logs = $state<any[]>([]);
  let showExportForm = $state(false);
  let exportFromDate = $state<string>('');
  let exportToDate = $state<string>(new Date().toISOString().split('T')[0]);

  let production = $state({
    input_item: '',
    input_qty: 0,
    output_oil_item: '',
    output_oil_qty: 0,
    output_khali_qty: 0,
    production_date: new Date().toISOString().split('T')[0]
  });

  onMount(async () => {
    await fetchData();
  });

  $effect(() => {
    if ($financialYear) {
      fetchData();
    }
  });

  async function fetchData() {
    const { start, end } = getFYDateRange($financialYear);
    const { data: invData } = await supabase.from('inventory').select('*');
    inventory = invData || [];

    const { data: logData } = await supabase.from('production')
      .select('*, in:inventory!input_item(item_name, unit), out:inventory!output_oil_item(item_name, unit)')
      .gte('production_date', start)
      .lte('production_date', end)
      .order('production_date', { ascending: false });
    logs = logData || [];
  }

  async function handleAddProduction() {
    if (!production.input_item || !production.output_oil_item || production.input_qty <= 0) {
      alert('Please fill all required fields');
      return;
    }

    const { error } = await supabase.from('production').insert({
      input_item: production.input_item,
      input_qty: production.input_qty,
      output_oil_item: production.output_oil_item,
      output_oil_qty: production.output_oil_qty,
      output_khali_qty: production.output_khali_qty,
      production_date: production.production_date
    });

    if (!error) {
      // Update inventory (Subtract input, add output)
      const inputItem = inventory.find(i => i.id === production.input_item);
      const oilItem = inventory.find(i => i.id === production.output_oil_item);
      const khaliItem = inventory.find(i => i.item_name === 'Khali');

      if (inputItem) await supabase.from('inventory').update({ quantity: inputItem.quantity - production.input_qty }).eq('id', production.input_item);
      if (oilItem) await supabase.from('inventory').update({ quantity: oilItem.quantity + production.output_oil_qty }).eq('id', production.output_oil_item);
      if (khaliItem) await supabase.from('inventory').update({ quantity: khaliItem.quantity + production.output_khali_qty }).eq('item_name', 'Khali');

      production = { 
        input_item: '', 
        input_qty: 0, 
        output_oil_item: '', 
        output_oil_qty: 0, 
        output_khali_qty: 0,
        production_date: new Date().toISOString().split('T')[0]
      };
      await fetchData();
    }
  }

  async function fetchProductionByDateRange(fromDate: string, toDate: string) {
    const { data } = await supabase
      .from('production')
      .select(`
        *,
        in:inventory!input_item(item_name, unit),
        out:inventory!output_oil_item(item_name, unit)
      `)
      .gte('production_date', fromDate)
      .lte('production_date', toDate)
      .order('production_date', { ascending: false });
    
    return data || [];
  }

  async function exportReport(e: Event) {
    e.preventDefault();
    
    if (!exportFromDate || !exportToDate) {
      alert('Please select both from and to dates');
      return;
    }

    if (exportFromDate > exportToDate) {
      alert('From date cannot be after to date');
      return;
    }

    const data = await fetchProductionByDateRange(exportFromDate, exportToDate);
    
    if (data.length === 0) {
      alert('No production records found for this date range');
      return;
    }

    // Prepare table data
    const tableData = data.map(p => [
      p.production_date,
      p.in.item_name,
      p.input_qty.toString(),
      p.in.unit,
      p.out.item_name,
      p.output_oil_qty.toString(),
      p.output_khali_qty.toString()
    ]);

    // Create PDF
    const doc = new jsPDF();
    doc.setFontSize(16);
    doc.text('Production Report', 20, 15);
    
    doc.setFontSize(10);
    doc.text(`From: ${exportFromDate} To: ${exportToDate}`, 20, 25);

    autoTable(doc, {
      head: [['Date', 'Raw Material', 'Input Qty', 'Unit', 'Oil Type', 'Oil (L)', 'Khali (kg)']],
      body: tableData,
      startY: 35,
      didDrawPage: function(pageDoc) {
        const pageSize = pageDoc.internal.pageSize;
        const pageHeight = pageSize.getHeight();
        pageDoc.setFontSize(8);
        pageDoc.text(
          'Generated on: ' + new Date().toLocaleString(),
          20,
          pageHeight - 10
        );
      }
    });

    doc.save(`production-report-${exportFromDate}-to-${exportToDate}.pdf`);
    showExportForm = false;
    exportFromDate = '';
    exportToDate = new Date().toISOString().split('T')[0];
  }

  async function exportCSV() {
    if (!exportFromDate || !exportToDate) {
      alert('Please select both dates');
      return;
    }

    const data = await fetchProductionByDateRange(exportFromDate, exportToDate);
    
    if (data.length === 0) {
      alert('No production records found');
      return;
    }

    let csv = 'Date,Raw Material,Input Qty,Unit,Oil Type,Oil Produced (L),Khali Produced (kg)\n';
    data.forEach(p => {
      csv += `${p.production_date},"${p.in.item_name}",${p.input_qty},"${p.in.unit}","${p.out.item_name}",${p.output_oil_qty},${p.output_khali_qty}\n`;
    });

    const blob = new Blob([csv], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `production-report-${exportFromDate}-to-${exportToDate}.csv`;
    a.click();
    window.URL.revokeObjectURL(url);
  }

  async function toggleProductionDone(prodId: string, currentDone: boolean) {
    const { error } = await supabase
      .from('production')
      .update({ is_done: !currentDone })
      .eq('id', prodId);

    if (!error) {
      await fetchData();
    }
  }
</script>

<div class="production-container">
  <div class="header">
    <h2>{t.production}</h2>
    <button class="btn-export" onclick={() => showExportForm = !showExportForm}>
      <Download size={20} /> Download Report
    </button>
  </div>

  {#if showExportForm}
    <div class="export-form">
      <form onsubmit={exportReport}>
        <div class="form-row">
          <div class="form-group">
            <label for="from-date">From Date</label>
            <input type="date" id="from-date" bind:value={exportFromDate} required />
          </div>

          <div class="form-group">
            <label for="to-date">To Date</label>
            <input type="date" id="to-date" bind:value={exportToDate} required />
          </div>
        </div>

        <div class="form-actions">
          <button type="submit" class="btn-submit">Export as PDF</button>
          <button type="button" class="btn-csv" onclick={exportCSV}>Export as CSV</button>
          <button type="button" class="btn-cancel" onclick={() => showExportForm = false}>Cancel</button>
        </div>
      </form>
    </div>
  {/if}

  <div class="production-form-card">
    <h3>Log New Production Batch</h3>
    <div class="form-grid">
      <div class="input-group">
        <label>Production Date</label>
        <input type="date" bind:value={production.production_date} />
      </div>

      <div class="input-group">
        <label>Raw Material Input</label>
        <select bind:value={production.input_item}>
          <option value="">Select Raw Material</option>
          {#each inventory.filter(i => i.item_name.includes('Raw')) as item}
            <option value={item.id}>{item.item_name} ({item.unit})</option>
          {/each}
        </select>
      </div>

      <div class="input-group">
        <label>Input Quantity (kg)</label>
        <input type="number" bind:value={production.input_qty} step="0.01" />
      </div>

      <div class="input-group">
        <label>Produced Oil Type</label>
        <select bind:value={production.output_oil_item}>
          <option value="">Select Oil Type</option>
          {#each inventory.filter(i => i.item_name.includes('Oil')) as item}
            <option value={item.id}>{item.item_name} ({item.unit})</option>
          {/each}
        </select>
      </div>

      <div class="input-group">
        <label>Oil Produced (liter)</label>
        <input type="number" bind:value={production.output_oil_qty} step="0.01" />
      </div>

      <div class="input-group">
        <label>Khali Produced (kg)</label>
        <input type="number" bind:value={production.output_khali_qty} step="0.01" />
      </div>
    </div>
    <button class="add-btn" onclick={handleAddProduction}>
      <Plus size={18} /> Record Production
    </button>
  </div>

  <div class="logs-list">
    <h3>Production History</h3>
    <table>
      <thead>
        <tr>
          <th>Date</th>
          <th>Input</th>
          <th>Output (Oil)</th>
          <th>Output (Khali)</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        {#each logs as log}
          <tr class={log.is_done ? 'done' : ''}>
            <td>{log.production_date}</td>
            <td>{log.input_qty} kg {log.in?.item_name}</td>
            <td>{log.output_oil_qty} liter {log.out?.item_name}</td>
            <td>{log.output_khali_qty} kg Khali</td>
            <td class="status-cell">
              <button 
                class="done-btn"
                onclick={() => toggleProductionDone(log.id, log.is_done)}
                title={log.is_done ? 'Mark as pending' : 'Mark as done'}
              >
                {#if log.is_done}
                  <CheckCircle size={18} />
                {:else}
                  <Circle size={18} />
                {/if}
              </button>
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
</div>

<style>
  .production-container h2 {
    margin-bottom: 30px;
    color: #2c3e50;
  }

  .production-form-card {
    background: white;
    padding: 25px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    margin-bottom: 30px;
  }

  .form-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    gap: 20px;
    margin-bottom: 20px;
  }

  .input-group label {
    display: block;
    margin-bottom: 5px;
    font-size: 0.9rem;
    color: #666;
  }

  .input-group select, .input-group input {
    width: 100%;
    padding: 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
  }

  .add-btn {
    background-color: #3498db;
    color: white;
    border: none;
    padding: 12px 24px;
    border-radius: 4px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .logs-list {
    background: white;
    padding: 25px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
  }

  table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 15px;
  }

  th, td {
    padding: 12px;
    text-align: left;
    border-bottom: 1px solid #eee;
  }

  th {
    color: #7f8c8d;
    font-size: 0.9rem;
    text-transform: uppercase;
  }

  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 30px;
  }

  .header h2 {
    margin: 0;
    color: #2c3e50;
  }

  .btn-export {
    background: #3498db;
    color: white;
    border: none;
    padding: 10px 20px;
    border-radius: 6px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 14px;
    font-weight: 600;
  }

  .btn-export:hover {
    background: #2980b9;
  }

  .export-form {
    background: #f8f9fa;
    border: 1px solid #e0e0e0;
    border-radius: 8px;
    padding: 20px;
    margin-bottom: 30px;
  }

  .export-form .form-row {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 15px;
    margin-bottom: 15px;
  }

  .export-form .form-group {
    display: flex;
    flex-direction: column;
  }

  .export-form .form-group label {
    font-size: 13px;
    font-weight: 600;
    color: #2c3e50;
    margin-bottom: 8px;
  }

  .export-form .form-group input {
    padding: 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 14px;
    font-family: inherit;
  }

  .export-form .form-group input:focus {
    outline: none;
    border-color: #3498db;
    box-shadow: 0 0 0 2px rgba(52, 152, 219, 0.1);
  }

  .form-actions {
    display: flex;
    gap: 10px;
  }

  .btn-submit,
  .btn-csv,
  .btn-cancel {
    padding: 10px 20px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-weight: 600;
    font-size: 14px;
  }

  .btn-submit {
    background: #27ae60;
    color: white;
  }

  .btn-submit:hover {
    background: #229954;
  }

  .btn-csv {
    background: #e67e22;
    color: white;
  }

  .btn-csv:hover {
    background: #d35400;
  }

  .btn-cancel {
    background: #bdc3c7;
    color: #2c3e50;
  }

  .btn-cancel:hover {
    background: #95a5a6;
  }

  tr.done {
    background-color: #ecf0f1;
    opacity: 0.7;
  }

  tr.done td {
    text-decoration: line-through;
    color: #95a5a6;
  }

  .status-cell {
    text-align: center;
  }

  .done-btn {
    background: none;
    border: none;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #95a5a6;
    padding: 5px;
    border-radius: 4px;
    transition: all 0.3s ease;
  }

  .done-btn:hover {
    background: rgba(46, 204, 113, 0.1);
    color: #27ae60;
  }

  tr.done .done-btn {
    color: #27ae60;
  }

  tr.done .done-btn:hover {
    color: #229954;
  }
</style>
