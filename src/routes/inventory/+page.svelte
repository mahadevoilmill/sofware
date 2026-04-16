<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations } from '$lib/i18n';
  import { Package, AlertTriangle, Plus, Minus, Download, CheckCircle, Circle } from 'lucide-svelte';
  import jsPDF from 'jspdf';
  import autoTable from 'jspdf-autotable';

  const t = $derived(translations[$language]);
  let inventory = $state<any[]>([]);
  let showForm = $state(false);
  let selectedItem = $state<string>('');
  let transactionType = $state<'stock_in' | 'stock_out'>('stock_in');
  let quantity = $state<number>(0);
  let notes = $state<string>('');
  let transactionDate = $state<string>(new Date().toISOString().split('T')[0]);
  let viewFromDate = $state<string>(new Date().toISOString().split('T')[0]);
  let viewToDate = $state<string>(new Date().toISOString().split('T')[0]);
  let todayTransactions = $state<any[]>([]);
  let showExportForm = $state(false);
  let exportFromDate = $state<string>('');
  let exportToDate = $state<string>(new Date().toISOString().split('T')[0]);
  let allTransactions = $state<any[]>([]);

  onMount(async () => {
    await fetchInventory();
    await fetchTransactions();
  });

  async function fetchInventory() {
    const { data } = await supabase.from('inventory').select('*').order('item_name');
    inventory = data || [];
  }

  async function fetchTransactions() {
    let query = supabase
      .from('inventory_transactions')
      .select(`
        *,
        inventory:inventory_id(item_name, unit)
      `)
      .order('transaction_date', { ascending: false })
      .order('created_at', { ascending: false });

    if (viewFromDate) {
      query = query.gte('transaction_date', viewFromDate);
    }
    if (viewToDate) {
      query = query.lte('transaction_date', viewToDate);
    }
    
    const { data } = await query;
    todayTransactions = data || [];
  }

  async function fetchTransactionsByDateRange(fromDate: string, toDate: string) {
    const { data } = await supabase
      .from('inventory_transactions')
      .select(`
        *,
        inventory:inventory_id(item_name, unit)
      `)
      .gte('transaction_date', fromDate)
      .lte('transaction_date', toDate)
      .order('transaction_date', { ascending: false });
    
    return data || [];
  }

  async function addTransaction(e: Event) {
    e.preventDefault();
    
    if (!selectedItem || quantity <= 0) {
      alert('Please select item and enter quantity');
      return;
    }

    const item = inventory.find(i => i.id === selectedItem);
    if (!item) return;

    // Add transaction
    const { error: transError } = await supabase
      .from('inventory_transactions')
      .insert({
        inventory_id: selectedItem,
        transaction_type: transactionType,
        quantity,
        notes,
        transaction_date: transactionDate
      });

    if (!transError) {
      // Update inventory quantity
      const newQty = transactionType === 'stock_in' 
        ? item.quantity + quantity 
        : Math.max(0, item.quantity - quantity);
      
      await supabase
        .from('inventory')
        .update({ quantity: newQty })
        .eq('id', selectedItem);

      // Reset form
      selectedItem = '';
      quantity = 0;
      notes = '';
      transactionDate = new Date().toISOString().split('T')[0];
      showForm = false;

      // Refresh data
      await fetchInventory();
      await fetchTransactions();
    }
  }

  function getSummary(item: any) {
    const stockIn = todayTransactions
      .filter(t => t.inventory_id === item.id && t.transaction_type === 'stock_in')
      .reduce((sum, t) => sum + t.quantity, 0);
    
    const stockOut = todayTransactions
      .filter(t => t.inventory_id === item.id && t.transaction_type === 'stock_out')
      .reduce((sum, t) => sum + t.quantity, 0);

    return { stockIn, stockOut };
  }

  function formatDateDisplay() {
    if (viewFromDate === viewToDate) {
      try {
        return new Date(viewFromDate + 'T00:00:00').toLocaleDateString();
      } catch {
        return viewFromDate;
      }
    }
    return `${viewFromDate} to ${viewToDate}`;
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

    // Fetch transactions for the date range
    const transactions = await fetchTransactionsByDateRange(exportFromDate, exportToDate);
    
    if (transactions.length === 0) {
      alert('No transactions found for this date range');
      return;
    }

    // Prepare data for PDF
    const tableData = transactions.map(t => [
      t.transaction_date,
      t.inventory.item_name,
      t.transaction_type === 'stock_in' ? '📥 IN' : '📤 OUT',
      t.quantity.toString(),
      t.inventory.unit,
      t.notes || '-'
    ]);

    // Create PDF
    const doc = new jsPDF();
    doc.setFontSize(16);
    doc.text('Inventory Report', 20, 15);
    
    doc.setFontSize(10);
    doc.text(`From: ${exportFromDate} To: ${exportToDate}`, 20, 25);

    autoTable(doc, {
      head: [['Date', 'Item', 'Type', 'Qty', 'Unit', 'Notes']],
      body: tableData,
      startY: 35,
      didDrawPage: function(data) {
        // Footer
        const pageSize = doc.internal.pageSize;
        const pageHeight = pageSize.getHeight();
        doc.setFontSize(8);
        doc.text(
          'Generated on: ' + new Date().toLocaleString(),
          20,
          pageHeight - 10
        );
      }
    });

    doc.save(`inventory-report-${exportFromDate}-to-${exportToDate}.pdf`);
    showExportForm = false;
    exportFromDate = '';
    exportToDate = new Date().toISOString().split('T')[0];
  }

  function exportCSV() {
    const transactions = allTransactions;
    
    if (transactions.length === 0) {
      alert('No transactions found for this date range');
      return;
    }

    let csv = 'Date,Item,Type,Quantity,Unit,Notes\n';
    transactions.forEach(t => {
      csv += `${t.transaction_date},"${t.inventory.item_name}","${t.transaction_type}",${t.quantity},"${t.inventory.unit}","${t.notes || ''}"\n`;
    });

    const blob = new Blob([csv], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `inventory-report-${exportFromDate}-to-${exportToDate}.csv`;
    a.click();
    window.URL.revokeObjectURL(url);
  }

  async function toggleTransactionDone(transId: string, currentDone: boolean) {
    const { error } = await supabase
      .from('inventory_transactions')
      .update({ is_done: !currentDone })
      .eq('id', transId);

    if (!error) {
      await fetchTransactions();
    }
  }
</script>

<div class="inventory-container">
  <div class="header">
    <h2>{t.inventory}</h2>
    <div class="header-actions">
      <button class="btn-add" onclick={() => showForm = !showForm}>
        <Plus size={20} /> Add Transaction
      </button>
      <button class="btn-export" onclick={() => showExportForm = !showExportForm}>
        <Download size={20} /> Export Report
      </button>
    </div>
  </div>

  {#if showForm}
    <div class="form-container">
      <form onsubmit={addTransaction}>
        <div class="form-row">
          <div class="form-group">
            <label for="item">Item</label>
            <select id="item" bind:value={selectedItem} required>
              <option value="">Select Item</option>
              {#each inventory as item}
                <option value={item.id}>{item.item_name} ({item.unit})</option>
              {/each}
            </select>
          </div>

          <div class="form-group">
            <label for="type">Type</label>
            <select id="type" bind:value={transactionType}>
              <option value="stock_in">📥 Stock In</option>
              <option value="stock_out">📤 Stock Out</option>
            </select>
          </div>

          <div class="form-group">
            <label for="qty">Quantity</label>
            <input type="number" id="qty" bind:value={quantity} step="0.01" required />
          </div>

          <div class="form-group">
            <label for="date">Date</label>
            <input type="date" id="date" bind:value={transactionDate} required />
          </div>
        </div>

        <div class="form-group">
          <label for="notes">Notes</label>
          <input type="text" id="notes" bind:value={notes} placeholder="Optional notes" />
        </div>

        <div class="form-actions">
          <button type="submit" class="btn-submit">Submit</button>
          <button type="button" class="btn-cancel" onclick={() => showForm = false}>Cancel</button>
        </div>
      </form>
    </div>
  {/if}

  {#if showExportForm}
    <div class="form-container">
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
          <button type="button" class="btn-csv" onclick={async () => {
            if (exportFromDate && exportToDate && exportFromDate <= exportToDate) {
              allTransactions = await fetchTransactionsByDateRange(exportFromDate, exportToDate);
              exportCSV();
            }
          }}>Export as CSV</button>
          <button type="button" class="btn-cancel" onclick={() => showExportForm = false}>Cancel</button>
        </div>
      </form>
    </div>
  {/if}

  <!-- Filter and Transactions -->
  <div class="today-section">
    <div class="section-header">
      <h3>Transactions for {formatDateDisplay()}</h3>
      <div class="filter-range">
        <div class="filter-group">
          <label for="view-from">From</label>
          <input type="date" id="view-from" bind:value={viewFromDate} onchange={fetchTransactions} />
        </div>
        <div class="filter-group">
          <label for="view-to">To</label>
          <input type="date" id="view-to" bind:value={viewToDate} onchange={fetchTransactions} />
        </div>
      </div>
    </div>
    
    {#if todayTransactions.length > 0}
      <div class="transactions-list">
        {#each todayTransactions as trans}
          <div class="transaction-item {trans.transaction_type} {trans.is_done ? 'done' : ''}">
            <div class="trans-icon">
              {#if trans.transaction_type === 'stock_in'}
                <Plus size={18} />
              {:else}
                <Minus size={18} />
              {/if}
            </div>
            <div class="trans-info">
              <div class="trans-meta">
                <span class="item-name">{trans.inventory.item_name}</span>
                <span class="trans-date">{new Date(trans.transaction_date).toLocaleDateString()}</span>
              </div>
              <span class="qty-unit">{trans.quantity} {trans.inventory.unit}</span>
              {#if trans.notes}
                <span class="notes">{trans.notes}</span>
              {/if}
            </div>
            <button 
              class="done-btn"
              onclick={() => toggleTransactionDone(trans.id, trans.is_done)}
              title={trans.is_done ? 'Mark as pending' : 'Mark as verified'}
            >
              {#if trans.is_done}
                <CheckCircle size={18} />
              {:else}
                <Circle size={18} />
              {/if}
            </button>
          </div>
        {/each}
      </div>
    {:else}
      <p class="no-data">No transactions found for this range</p>
    {/if}
  </div>

  <!-- Inventory Summary -->
  <div class="inventory-grid">
    {#each inventory as item}
      {@const summary = getSummary(item)}
      <div class="inventory-card">
        <div class="card-header">
          <Package size={20} />
          <h3>{item.item_name}</h3>
        </div>
        
        <div class="card-body">
          <div class="total-stock">
            <span class="label">Total Stock</span>
            <span class="value {item.quantity < 50 ? 'low-stock' : ''}">{item.quantity}</span>
            <span class="unit">{item.unit}</span>
          </div>

          <div class="stock-breakdown">
            <div class="breakdown-item in">
              <span class="label">In (Range)</span>
              <span class="value">+{summary.stockIn}</span>
            </div>
            <div class="breakdown-item out">
              <span class="label">Out (Range)</span>
              <span class="value">-{summary.stockOut}</span>
            </div>
          </div>

          {#if item.quantity < 50}
            <div class="alert">
              <AlertTriangle size={14} /> Low Stock Alert
            </div>
          {/if}
        </div>
      </div>
    {/each}
  </div>
</div>

<style>
  .inventory-container {
    max-width: 1400px;
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

  .header-actions {
    display: flex;
    gap: 10px;
  }

  .btn-add,
  .btn-export {
    border: none;
    padding: 10px 20px;
    border-radius: 6px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 14px;
    font-weight: 600;
    transition: all 0.3s ease;
  }

  .btn-add {
    background: #27ae60;
    color: white;
  }

  .btn-add:hover {
    background: #229954;
  }

  .btn-export {
    background: #3498db;
    color: white;
  }

  .btn-export:hover {
    background: #2980b9;
  }

  /* Form Styles */
  .form-container {
    background: #f8f9fa;
    border: 1px solid #e0e0e0;
    border-radius: 8px;
    padding: 20px;
    margin-bottom: 30px;
  }

  .form-row {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 15px;
    margin-bottom: 15px;
  }

  .form-group {
    display: flex;
    flex-direction: column;
  }

  .form-group label {
    font-size: 13px;
    font-weight: 600;
    color: #2c3e50;
    margin-bottom: 8px;
  }

  .form-group input,
  .form-group select {
    padding: 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 14px;
    font-family: inherit;
  }

  .form-group input:focus,
  .form-group select:focus {
    outline: none;
    border-color: #27ae60;
    box-shadow: 0 0 0 2px rgba(39, 174, 96, 0.1);
  }

  .form-actions {
    display: flex;
    gap: 10px;
  }

  .btn-submit,
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

  .btn-cancel {
    background: #bdc3c7;
    color: #2c3e50;
  }

  .btn-cancel:hover {
    background: #95a5a6;
  }

  .btn-csv {
    background: #e67e22;
    color: white;
    padding: 10px 20px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-weight: 600;
    font-size: 14px;
  }

  .btn-csv:hover {
    background: #d35400;
  }

  /* Today's Transactions */
  .today-section {
    background: white;
    border-radius: 8px;
    padding: 20px;
    margin-bottom: 30px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
  }

  .section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 2px solid #ecf0f1;
    padding-bottom: 15px;
    margin-bottom: 15px;
    flex-wrap: wrap;
    gap: 15px;
  }

  .section-header h3 {
    margin: 0;
    color: #2c3e50;
  }

  .filter-range {
    display: flex;
    gap: 15px;
  }

  .filter-group {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .filter-group label {
    font-size: 12px;
    font-weight: 600;
    color: #7f8c8d;
    text-transform: uppercase;
  }

  .filter-group input {
    padding: 5px 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 13px;
  }

  .transactions-list {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .transaction-item {
    display: flex;
    align-items: center;
    gap: 15px;
    padding: 12px;
    background: #f8f9fa;
    border-left: 4px solid #95a5a6;
    border-radius: 4px;
  }

  .transaction-item.stock_in {
    border-left-color: #27ae60;
  }

  .transaction-item.stock_out {
    border-left-color: #e74c3c;
  }

  .trans-icon {
    width: 40px;
    height: 40px;
    background: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .transaction-item.stock_in .trans-icon {
    color: #27ae60;
  }

  .transaction-item.stock_out .trans-icon {
    color: #e74c3c;
  }

  .trans-info {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .trans-meta {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .item-name {
    font-weight: 600;
    color: #2c3e50;
  }

  .trans-date {
    font-size: 11px;
    color: #95a5a6;
    background: #eee;
    padding: 2px 6px;
    border-radius: 10px;
  }

  .qty-unit {
    font-size: 13px;
    color: #7f8c8d;
  }

  .notes {
    font-size: 12px;
    color: #95a5a6;
    font-style: italic;
  }

  .no-data {
    color: #7f8c8d;
    text-align: center;
    padding: 20px;
    margin: 0;
  }

  /* Inventory Grid */
  .inventory-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 20px;
  }

  .inventory-card {
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    overflow: hidden;
    display: flex;
    flex-direction: column;
    transition: box-shadow 0.3s ease;
  }

  .inventory-card:hover {
    box-shadow: 0 4px 8px rgba(0,0,0,0.1);
  }

  .card-header {
    padding: 15px 20px;
    background-color: #f8f9fa;
    border-bottom: 1px solid #eee;
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .card-header h3 {
    margin: 0;
    font-size: 1rem;
    color: #2c3e50;
  }

  .card-body {
    padding: 20px;
    flex-grow: 1;
    display: flex;
    flex-direction: column;
    gap: 15px;
  }

  .total-stock {
    text-align: center;
    padding: 15px;
    background: #ecf0f1;
    border-radius: 6px;
  }

  .total-stock .label {
    display: block;
    font-size: 12px;
    color: #7f8c8d;
    margin-bottom: 8px;
    text-transform: uppercase;
    font-weight: 600;
  }

  .total-stock .value {
    display: inline-block;
    font-size: 28px;
    font-weight: bold;
    color: #2c3e50;
  }

  .total-stock .value.low-stock {
    color: #e74c3c;
  }

  .total-stock .unit {
    display: block;
    font-size: 13px;
    color: #95a5a6;
    margin-top: 5px;
  }

  .stock-breakdown {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
  }

  .breakdown-item {
    padding: 12px;
    border-radius: 6px;
    text-align: center;
  }

  .breakdown-item.in {
    background: rgba(39, 174, 96, 0.1);
  }

  .breakdown-item.out {
    background: rgba(231, 76, 60, 0.1);
  }

  .breakdown-item .label {
    display: block;
    font-size: 11px;
    color: #7f8c8d;
    margin-bottom: 6px;
    text-transform: uppercase;
    font-weight: 600;
  }

  .breakdown-item .value {
    display: block;
    font-size: 18px;
    font-weight: bold;
  }

  .breakdown-item.in .value {
    color: #27ae60;
  }

  .breakdown-item.out .value {
    color: #e74c3c;
  }

  .alert {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px;
    background: #ffe0e0;
    color: #c0392b;
    border-radius: 4px;
    font-size: 13px;
    font-weight: 600;
  }

  .transaction-item.done {
    background-color: #ecf0f1;
    opacity: 0.7;
    border-left-color: #27ae60 !important;
  }

  .transaction-item.done .item-name,
  .transaction-item.done .qty-unit {
    text-decoration: line-through;
    color: #95a5a6;
  }

  .done-btn {
    background: none;
    border: none;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #95a5a6;
    padding: 8px;
    border-radius: 4px;
    transition: all 0.3s ease;
    flex-shrink: 0;
    margin-left: auto;
  }

  .done-btn:hover {
    background: rgba(46, 204, 113, 0.1);
    color: #27ae60;
  }

  .transaction-item.done .done-btn {
    color: #27ae60;
  }

  .transaction-item.done .done-btn:hover {
    color: #229954;
  }
</style>
