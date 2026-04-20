<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations, financialYear, getFYDateRange } from '$lib/i18n';
  import { Package, AlertTriangle, Plus, Minus, Download, CheckCircle, Circle, Edit, Trash2, Eye, X } from 'lucide-svelte';
  import jsPDF from 'jspdf';
  import autoTable from 'jspdf-autotable';

  const t = $derived(translations[$language]);
  let inventory = $state<any[]>([]);
  let showForm = $state(false);
  let showItemForm = $state(false);
  let showDetailsModal = $state(false);
  
  // Transaction state
  let selectedItem = $state<string>('');
  let transactionType = $state<'stock_in' | 'stock_out'>('stock_in');
  let quantity = $state<number>(0);
  let notes = $state<string>('');
  let transactionDate = $state<string>(new Date().toISOString().split('T')[0]);
  let editingTransaction = $state<any>(null);

  // Item state
  let newItemName = $state('');
  let newItemUnit = $state('kg');
  let newItemHsnSac = $state(''); // New field
  let editingItem = $state<any>(null);
  let selectedItemForDetails = $state<any>(null);
  let itemTransactions = $state<any[]>([]);

  // Date Filtering
  const currentYear = new Date().getFullYear();
  let selectedYear = $state<number>(currentYear);
  let filterFromDate = $state<string>(`${selectedYear}-01-01`);
  let filterToDate = $state<string>(`${selectedYear}-12-31`);
  let viewFromDate = $state<string>(`${selectedYear}-01-01`);
  let viewToDate = $state<string>(`${selectedYear}-12-31`);

  let todayTransactions = $state<any[]>([]);
  let showExportForm = $state(false);
  let exportFromDate = $state<string>(`${selectedYear}-01-01`);
  let exportToDate = $state<string>(`${selectedYear}-12-31`);
  let allTransactions = $state<any[]>([]);

  // Function to update filter dates based on selected year
  function updateDateFilters() {
    filterFromDate = `${selectedYear}-01-01`;
    filterToDate = `${selectedYear}-12-31`;
    viewFromDate = `${selectedYear}-01-01`;
    viewToDate = `${selectedYear}-12-31`;
    exportFromDate = `${selectedYear}-01-01`;
    exportToDate = `${selectedYear}-12-31`;
    fetchInventory(); // Re-fetch inventory as well, though it might not change per year.
    fetchTransactions(); // Refetch transactions with new date range
  }

  onMount(async () => {
    // updateDateFilters(); // No longer needed as $effect will handle it
    await fetchInventory();
    await fetchTransactions();
  });

  $effect(() => {
    if ($financialYear) {
      const { start, end } = getFYDateRange($financialYear);
      viewFromDate = start;
      viewToDate = end;
      exportFromDate = start;
      exportToDate = end;
      fetchTransactions();
    }
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

    // Apply date range filters
    if (filterFromDate) {
      query = query.gte('transaction_date', filterFromDate);
    }
    if (filterToDate) {
      query = query.lte('transaction_date', filterToDate);
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

  async function handleInventoryItem(e: Event) {
    e.preventDefault();
    if (!newItemName || !newItemUnit) return;

    if (editingItem) {
      const { error } = await supabase
        .from('inventory')
        .update({ item_name: newItemName, unit: newItemUnit, hsn_sac: newItemHsnSac })
        .eq('id', editingItem.id);
      
      if (!error) {
        editingItem = null;
      } else {
        alert(error.message);
      }
    } else {
      const { error } = await supabase
        .from('inventory')
        .insert({ item_name: newItemName, unit: newItemUnit, quantity: 0, hsn_sac: newItemHsnSac });
      
      if (error) {
        alert(error.message);
      }
    }

    newItemName = '';
    newItemUnit = 'kg';
    newItemHsnSac = '';
    showItemForm = false;
    await fetchInventory();
  }

  async function deleteInventoryItem(id: string) {
    if (!confirm('Are you sure? This will delete all associated transactions.')) return;

    // Delete transactions first (or handle via cascade if set up in DB)
    const { error: tError } = await supabase.from('inventory_transactions').delete().eq('inventory_id', id);
    if (tError) {
      alert('Error deleting transactions: ' + tError.message);
      return;
    }

    const { error } = await supabase.from('inventory').delete().eq('id', id);
    if (error) {
      alert(error.message);
    } else {
      await fetchInventory();
      await fetchTransactions();
    }
  }

  function editItem(item: any) {
    editingItem = item;
    newItemName = item.item_name;
    newItemUnit = item.unit;
    newItemHsnSac = item.hsn_sac || '';
    showItemForm = true;
  }

  async function addTransaction(e: Event) {
    e.preventDefault();
    
    if (!selectedItem || quantity <= 0) {
      alert('Please select item and enter quantity');
      return;
    }

    const item = inventory.find(i => i.id === selectedItem);
    if (!item) return;

    if (editingTransaction) {
      // Revert old quantity first
      const oldItem = inventory.find(i => i.id === editingTransaction.inventory_id);
      if (oldItem) {
        const revertedQty = editingTransaction.transaction_type === 'stock_in'
          ? oldItem.quantity - editingTransaction.quantity
          : oldItem.quantity + editingTransaction.quantity;
        
        await supabase.from('inventory').update({ quantity: revertedQty }).eq('id', oldItem.id);
      }

      // Update transaction
      const { error: transError } = await supabase
        .from('inventory_transactions')
        .update({
          inventory_id: selectedItem,
          transaction_type: transactionType,
          quantity,
          notes,
          transaction_date: transactionDate
        })
        .eq('id', editingTransaction.id);

      if (!transError) {
        // Apply new quantity
        const updatedItem = (await supabase.from('inventory').select('*').eq('id', selectedItem).single()).data;
        const newQty = transactionType === 'stock_in' 
          ? updatedItem.quantity + quantity 
          : Math.max(0, updatedItem.quantity - quantity);
        
        await supabase.from('inventory').update({ quantity: newQty }).eq('id', selectedItem);
      }
    } else {
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
      }
    }

    // Reset form
    resetTransactionForm();
    await fetchInventory();
    await fetchTransactions();
  }

  function resetTransactionForm() {
    selectedItem = '';
    quantity = 0;
    notes = '';
    transactionDate = new Date().toISOString().split('T')[0];
    showForm = false;
    editingTransaction = null;
  }

  async function deleteTransaction(trans: any) {
    if (!confirm('Are you sure you want to delete this transaction?')) return;

    const item = inventory.find(i => i.id === trans.inventory_id);
    if (item) {
      const newQty = trans.transaction_type === 'stock_in'
        ? Math.max(0, item.quantity - trans.quantity)
        : item.quantity + trans.quantity;
      
      await supabase.from('inventory').update({ quantity: newQty }).eq('id', item.id);
    }

    const { error } = await supabase.from('inventory_transactions').delete().eq('id', trans.id);
    if (!error) {
      await fetchInventory();
      await fetchTransactions();
    }
  }

  function editTransaction(trans: any) {
    editingTransaction = trans;
    selectedItem = trans.inventory_id;
    transactionType = trans.transaction_type;
    quantity = trans.quantity;
    notes = trans.notes || '';
    transactionDate = trans.transaction_date;
    showForm = true;
  }

  async function showDetails(item: any) {
    selectedItemForDetails = item;
    const { data } = await supabase
      .from('inventory_transactions')
      .select('*')
      .eq('inventory_id', item.id)
      .order('transaction_date', { ascending: false });
    itemTransactions = data || [];
    showDetailsModal = true;
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
      <button class="btn-item" onclick={() => { showItemForm = true; editingItem = null; newItemName = ''; }}>
        <Plus size={20} /> New Item
      </button>
      <button class="btn-add" onclick={() => { showForm = !showForm; editingTransaction = null; }}>
        <Plus size={20} /> Add Stock
      </button>
      <button class="btn-export" onclick={() => showExportForm = !showExportForm}>
        <Download size={20} /> Export Report
      </button>
    </div>
  </div>

  {#if showItemForm}
    <div class="modal-overlay">
      <div class="modal-content">
        <div class="modal-header">
          <h3>{editingItem ? 'Edit Item' : 'Add New Item'}</h3>
          <button class="close-btn" onclick={() => showItemForm = false}><X size={20} /></button>
        </div>
        <form onsubmit={handleInventoryItem}>
          <div class="form-group">
            <label for="itemName">Item Name</label>
            <input type="text" id="itemName" bind:value={newItemName} required placeholder="e.g. Groundnut Oil" />
          </div>
          <div class="form-group">
            <label for="itemUnit">Unit</label>
            <select id="itemUnit" bind:value={newItemUnit}>
              <option value="kg">kg</option>
              <option value="liter">liter</option>
              <option value="bag">bag</option>
              <option value="tin">tin</option>
            </select>
          </div>
          <div class="form-group">
            <label for="itemHsn">HSN/SAC Code</label>
            <input type="text" id="itemHsn" bind:value={newItemHsnSac} placeholder="e.g. 1508" />
          </div>
          <div class="form-actions">
            <button type="submit" class="btn-submit">{editingItem ? 'Update' : 'Add'}</button>
            <button type="button" class="btn-cancel" onclick={() => showItemForm = false}>Cancel</button>
          </div>
        </form>
      </div>
    </div>
  {/if}

  {#if showForm}
    <div class="form-container">
      <div class="section-header">
        <h3>{editingTransaction ? 'Edit Transaction' : 'Add Stock Transaction'}</h3>
      </div>
      <form onsubmit={addTransaction}>
        <div class="form-row">
          <div class="form-group">
            <label for="item">Item</label>
            <select id="item" bind:value={selectedItem} required disabled={!!editingTransaction}>
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
          <button type="submit" class="btn-submit">{editingTransaction ? 'Update' : 'Submit'}</button>
          <button type="button" class="btn-cancel" onclick={resetTransactionForm}>Cancel</button>
        </div>
      </form>
    </div>
  {/if}

  {#if showExportForm}
    <div class="form-container">
      <form onsubmit={exportReport}>
        <div class="form-row">
          <div class="form-group">
            <label for="export-from-date">From Date</label>
            <input type="date" id="export-from-date" bind:value={exportFromDate} required />
          </div>

          <div class="form-group">
            <label for="export-to-date">To Date</label>
            <input type="date" id="export-to-date" bind:value={exportToDate} required />
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

  {#if showDetailsModal && selectedItemForDetails}
    <div class="modal-overlay">
      <div class="modal-content details-modal">
        <div class="modal-header">
          <h3>Full History: {selectedItemForDetails.item_name}</h3>
          <button class="close-btn" onclick={() => showDetailsModal = false}><X size={20} /></button>
        </div>
        <div class="details-body">
          <div class="current-status">
            <p><strong>Current Stock:</strong> {selectedItemForDetails.quantity} {selectedItemForDetails.unit}</p>
          </div>
          <div class="table-container">
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Type</th>
                  <th>Quantity</th>
                  <th>Notes</th>
                </tr>
              </thead>
              <tbody>
                {#each itemTransactions as trans}
                  <tr>
                    <td>{new Date(trans.transaction_date).toLocaleDateString()}</td>
                    <td class={trans.transaction_type}>
                      {trans.transaction_type === 'stock_in' ? '📥 IN' : '📤 OUT'}
                    </td>
                    <td>{trans.quantity} {selectedItemForDetails.unit}</td>
                    <td>{trans.notes || '-'}</td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        </div>
      </div>
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
            <div class="trans-actions">
              <button class="action-btn edit" onclick={() => editTransaction(trans)} title="Edit">
                <Edit size={16} />
              </button>
              <button class="action-btn delete" onclick={() => deleteTransaction(trans)} title="Delete">
                <Trash2 size={16} />
              </button>
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
          <div class="header-left">
            <Package size={20} />
            <h3>{item.item_name}</h3>
          </div>
          <div class="header-right">
            <button class="icon-btn edit" onclick={() => editItem(item)} title="Edit Item">
              <Edit size={16} />
            </button>
            <button class="icon-btn delete" onclick={() => deleteInventoryItem(item.id)} title="Delete Item">
              <Trash2 size={16} />
            </button>
          </div>
        </div>
        
        <div class="card-body">
          <div class="total-stock">
            <span class="label">Total Stock</span>
            <span class="value {item.quantity < 50 ? 'low-stock' : ''}">{item.quantity}</span>
            <span class="unit">{item.unit}</span>
          </div>

          <div class="hsn-sac">
            <span class="label">HSN/SAC:</span>
            <span class="value">{item.hsn_sac || '-'}</span>
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
          
          <button class="btn-details" onclick={() => showDetails(item)}>
            <Eye size={16} /> Full Details
          </button>
        </div>
      </div>
    {/each}
  </div>
</div>

<style>
  .inventory-container {
    max-width: 1400px;
    padding: 20px;
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
  .btn-export,
  .btn-item {
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

  .btn-item {
    background: #8e44ad;
    color: white;
  }

  .btn-item:hover {
    background: #7d3c98;
  }

  .btn-export {
    background: #3498db;
    color: white;
  }

  .btn-export:hover {
    background: #2980b9;
  }

  /* Modal Styles */
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0,0,0,0.5);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 1000;
  }

  .modal-content {
    background: white;
    padding: 25px;
    border-radius: 8px;
    width: 90%;
    max-width: 500px;
    box-shadow: 0 10px 25px rgba(0,0,0,0.2);
  }

  .details-modal {
    max-width: 800px;
    max-height: 90vh;
    overflow-y: auto;
  }

  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
    border-bottom: 1px solid #eee;
    padding-bottom: 10px;
  }

  .modal-header h3 {
    margin: 0;
    color: #2c3e50;
  }

  .close-btn {
    background: none;
    border: none;
    cursor: pointer;
    color: #7f8c8d;
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
    margin-bottom: 15px;
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

  .form-actions {
    display: flex;
    gap: 10px;
    margin-top: 10px;
  }

  .btn-submit,
  .btn-cancel,
  .btn-csv {
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

  .btn-cancel {
    background: #bdc3c7;
    color: #2c3e50;
  }

  .btn-csv {
    background: #e67e22;
    color: white;
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

  .transaction-item.stock_in { border-left-color: #27ae60; }
  .transaction-item.stock_out { border-left-color: #e74c3c; }

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

  .trans-actions {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .action-btn {
    background: none;
    border: none;
    cursor: pointer;
    padding: 5px;
    border-radius: 4px;
    color: #7f8c8d;
    transition: all 0.2s;
  }

  .action-btn.edit:hover { color: #3498db; background: rgba(52, 152, 219, 0.1); }
  .action-btn.delete:hover { color: #e74c3c; background: rgba(231, 76, 60, 0.1); }

  .done-btn {
    background: none;
    border: none;
    cursor: pointer;
    color: #95a5a6;
  }

  .transaction-item.done {
    background-color: #ecf0f1;
    opacity: 0.7;
    border-left-color: #27ae60 !important;
  }

  .transaction-item.done .item-name,
  .transaction-item.done .qty-unit {
    text-decoration: line-through;
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
    transition: transform 0.2s, box-shadow 0.2s;
  }

  .inventory-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(0,0,0,0.1);
  }

  .card-header {
    padding: 15px 20px;
    background-color: #f8f9fa;
    border-bottom: 1px solid #eee;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .header-left {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .card-header h3 {
    margin: 0;
    font-size: 1rem;
    color: #2c3e50;
  }

  .header-right {
    display: flex;
    gap: 5px;
  }

  .icon-btn {
    background: none;
    border: none;
    cursor: pointer;
    padding: 4px;
    border-radius: 4px;
    color: #95a5a6;
    transition: all 0.2s;
  }

  .icon-btn.edit:hover { color: #3498db; background: rgba(52, 152, 219, 0.1); }
  .icon-btn.delete:hover { color: #e74c3c; background: rgba(231, 76, 60, 0.1); }

  .card-body {
    padding: 20px;
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

  .hsn-sac {
    display: flex;
    justify-content: center;
    gap: 5px;
    font-size: 0.85rem;
    color: #7f8c8d;
    background: #f8f9fa;
    padding: 5px;
    border-radius: 4px;
  }

  .hsn-sac .label { font-weight: 600; }

  .total-stock .label {
    display: block;
    font-size: 11px;
    color: #7f8c8d;
    margin-bottom: 4px;
    text-transform: uppercase;
    font-weight: 600;
  }

  .total-stock .value {
    font-size: 24px;
    font-weight: bold;
    color: #2c3e50;
  }

  .total-stock .value.low-stock { color: #e74c3c; }

  .stock-breakdown {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
  }

  .breakdown-item {
    padding: 10px;
    border-radius: 6px;
    text-align: center;
  }

  .breakdown-item.in { background: rgba(39, 174, 96, 0.1); color: #27ae60; }
  .breakdown-item.out { background: rgba(231, 76, 60, 0.1); color: #e74c3c; }

  .breakdown-item .value { font-weight: bold; }

  .btn-details {
    width: 100%;
    padding: 10px;
    border: 1px solid #3498db;
    background: white;
    color: #3498db;
    border-radius: 6px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    font-weight: 600;
    transition: all 0.2s;
  }

  .btn-details:hover {
    background: #3498db;
    color: white;
  }

  /* Table styles for history */
  .table-container {
    margin-top: 15px;
    overflow-x: auto;
  }

  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 14px;
  }

  th, td {
    padding: 12px;
    text-align: left;
    border-bottom: 1px solid #eee;
  }

  th {
    background: #f8f9fa;
    font-weight: 600;
    color: #2c3e50;
  }

  .stock_in { color: #27ae60; }
  .stock_out { color: #e74c3c; }
</style>
