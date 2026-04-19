<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations, financialYear, getFYDateRange } from '$lib/i18n';
  import jsPDF from 'jspdf';
  import { Plus, Download, Trash2, CheckCircle, Circle, Edit2, Truck } from 'lucide-svelte';

  const t = $derived(translations[$language]);

  let inventory = $state<any[]>([]);
  let suppliers = $state<any[]>([]);
  let purchases = $state<any[]>([]);
  let companySettings = $state<any>(null);
  let showManualProduct = $state(false);
  let showEditForm = $state(false);
  let editingPurchase = $state<any>(null);
  
  let newPurchase = $state({
    supplier_id: '',
    supplier_name: '',
    product_item: '',
    product_name: '',
    quantity: 0,
    rate: 0,
    gst_rate: 5,
    payment_mode: 'Cash',
    payment_details: '',
    purchase_date: new Date().toISOString().split('T')[0],
    bill_url: '',
    created_by: ''
  });

  let billFile = $state<File | null>(null);
  let uploading = $state(false);

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
    try {
      const { data: setts } = await supabase.from('company_settings').select('*');
      companySettings = setts?.[0] || null;

      const { data: invData } = await supabase.from('inventory').select('*').order('item_name');
      inventory = invData || [];

      const { data: supData } = await supabase.from('suppliers').select('*').order('name');
      suppliers = supData || [];

      const { data: purData, error: purError } = await supabase
        .from('purchases')
        .select(`
          *,
          inventory:product_item(item_name, unit),
          suppliers:supplier_id(name)
        `)
        .gte('purchase_date', start)
        .lte('purchase_date', end)
        .order('created_at', { ascending: false });
      
      if (!purError) {
        purchases = purData || [];
      }
    } catch (err) {
      console.error('Unexpected error in fetchData:', err);
    }
  }

  async function handleAddPurchase() {
    if (newPurchase.quantity <= 0 || newPurchase.rate <= 0) {
      alert('Please enter valid quantity and rate');
      return;
    }

    if (!newPurchase.supplier_id && !newPurchase.supplier_name) {
      alert('Please select or enter supplier');
      return;
    }

    if (!showManualProduct && !newPurchase.product_item) {
      alert('Please select a product');
      return;
    }

    uploading = true;
    let bill_path = '';

    // Upload file if selected
    if (billFile) {
      const fileExt = billFile.name.split('.').pop();
      const fileName = `${Date.now()}.${fileExt}`;
      const filePath = `bills/${fileName}`;

      const { data: uploadData, error: uploadError } = await supabase.storage
        .from('purchase-bills')
        .upload(filePath, billFile);

      if (uploadError) {
        alert('Error uploading bill: ' + uploadError.message);
        uploading = false;
        return;
      }
      bill_path = filePath;
    }

    const totalBase = newPurchase.quantity * newPurchase.rate;
    const cgst = (totalBase * (newPurchase.gst_rate / 2)) / 100;
    const sgst = (totalBase * (newPurchase.gst_rate / 2)) / 100;
    const total = totalBase + cgst + sgst;

    const { data: existingPurchases } = await supabase
      .from('purchases')
      .select('purchase_number')
      .order('created_at', { ascending: false })
      .limit(1);

    let nextNum = 1;
    if (existingPurchases && existingPurchases.length > 0) {
      const lastPur = existingPurchases[0].purchase_number;
      const lastNum = parseInt(lastPur.replace('PUR-', ''), 10);
      nextNum = isNaN(lastNum) ? 1 : lastNum + 1;
    }
    const purchase_number = `PUR-${nextNum.toString().padStart(3, '0')}`;

    const purchaseData: any = {
      purchase_number,
      supplier_id: newPurchase.supplier_id || null,
      supplier_name: newPurchase.supplier_id ? null : newPurchase.supplier_name,
      quantity: newPurchase.quantity,
      rate: newPurchase.rate,
      gst_rate: newPurchase.gst_rate,
      cgst,
      sgst,
      total_amount: total,
      is_done: false,
      purchase_date: newPurchase.purchase_date,
      payment_mode: newPurchase.payment_mode,
      payment_details: newPurchase.payment_details,
      bill_url: bill_path,
      created_by: newPurchase.created_by
    };

    if (!showManualProduct && newPurchase.product_item) {
      purchaseData.product_item = newPurchase.product_item;
    } else {
      purchaseData.product_name = newPurchase.product_name;
    }

    const { error } = await supabase.from('purchases').insert(purchaseData);

    if (error) {
      alert('Error adding purchase: ' + error.message);
    } else {
      // Update stock
      if (!showManualProduct && newPurchase.product_item) {
        const product = inventory.find(i => i.id === newPurchase.product_item);
        if (product) {
          await supabase.from('inventory')
            .update({ quantity: Number(product.quantity) + Number(newPurchase.quantity) })
            .eq('id', newPurchase.product_item);
        }
      }
      
      // Reset form
      newPurchase = { 
        supplier_id: '',
        supplier_name: '', 
        product_item: '', 
        product_name: '',
        quantity: 0, 
        rate: 0,
        gst_rate: 5,
        payment_mode: 'Cash',
        payment_details: '',
        purchase_date: new Date().toISOString().split('T')[0],
        bill_url: '',
        created_by: ''
      };
      billFile = null;
      uploading = false;
      await fetchData();
    }
  }

  function getBillUrl(path: string) {
    if (!path) return null;
    const { data } = supabase.storage.from('purchase-bills').getPublicUrl(path);
    return data.publicUrl;
  }

  async function deletePurchase(purchase: any) {
    if (!confirm(`Delete purchase ${purchase.purchase_number}?`)) return;

    const { error } = await supabase.from('purchases').delete().eq('id', purchase.id);
    if (!error) {
      // Note: In a real app, you might want to reverse the stock update
      await fetchData();
    }
  }

  async function toggleDone(purId: string, currentDone: boolean) {
    await supabase.from('purchases').update({ is_done: !currentDone }).eq('id', purId);
    await fetchData();
  }

  async function openEditForm(purchase: any) {
    editingPurchase = { ...purchase };
    showEditForm = true;
  }

  async function handleUpdatePurchase() {
    if (!editingPurchase) return;

    const totalBase = editingPurchase.quantity * editingPurchase.rate;
    const cgst = (totalBase * (editingPurchase.gst_rate / 2)) / 100;
    const sgst = (totalBase * (editingPurchase.gst_rate / 2)) / 100;
    const total = totalBase + cgst + sgst;

    const updateData: any = {
      supplier_id: editingPurchase.supplier_id || null,
      supplier_name: editingPurchase.supplier_id ? null : editingPurchase.supplier_name,
      quantity: editingPurchase.quantity,
      rate: editingPurchase.rate,
      gst_rate: editingPurchase.gst_rate,
      cgst,
      sgst,
      total_amount: total,
      purchase_date: editingPurchase.purchase_date,
      payment_mode: editingPurchase.payment_mode,
      payment_details: editingPurchase.payment_details,
      created_by: editingPurchase.created_by,
      product_item: editingPurchase.product_item || null,
      product_name: editingPurchase.product_item ? null : editingPurchase.product_name
    };

    const { error } = await supabase
      .from('purchases')
      .update(updateData)
      .eq('id', editingPurchase.id);

    if (!error) {
      showEditForm = false;
      editingPurchase = null;
      await fetchData();
      alert('Purchase updated successfully!');
    } else {
      alert('Error updating purchase: ' + error.message);
    }
  }
</script>

<div class="purchases-container">
  <h2><Truck size={32} style="vertical-align: middle; margin-right: 10px;" /> {t.purchases}</h2>

  <div class="purchase-form-card">
    <div class="form-header">
      <h3>Record New Purchase</h3>
      <label class="toggle-label">
        <input type="checkbox" bind:checked={showManualProduct} />
        <span>{showManualProduct ? 'Manual Product' : 'From Inventory'}</span>
      </label>
    </div>
    
    <div class="form-grid">
      <div class="input-group">
        <label>Supplier (From Directory)</label>
        <select bind:value={newPurchase.supplier_id}>
          <option value="">Manual Entry (below)</option>
          {#each suppliers as supplier}
            <option value={supplier.id}>{supplier.name}</option>
          {/each}
        </select>
      </div>

      {#if !newPurchase.supplier_id}
        <div class="input-group">
          <label>Manual Supplier Name</label>
          <input type="text" bind:value={newPurchase.supplier_name} placeholder="Enter Supplier Name" />
        </div>
      {/if}

      {#if showManualProduct}
        <div class="input-group">
          <label>Product Name</label>
          <input type="text" bind:value={newPurchase.product_name} placeholder="Enter product name" />
        </div>
      {:else}
        <div class="input-group">
          <label>{t.product}</label>
          <select bind:value={newPurchase.product_item}>
            <option value="">Select Product</option>
            {#each inventory as item}
              <option value={item.id}>{item.item_name} ({item.quantity} {item.unit} in stock)</option>
            {/each}
          </select>
        </div>
      {/if}

      <div class="input-group">
        <label>{t.quantity}</label>
        <input type="number" bind:value={newPurchase.quantity} min="0.01" step="0.01" />
      </div>

      <div class="input-group">
        <label>{t.rate}</label>
        <input type="number" bind:value={newPurchase.rate} min="0.01" step="0.01" />
      </div>

      <div class="input-group">
        <label>GST Rate (%)</label>
        <select bind:value={newPurchase.gst_rate}>
          <option value={0}>0%</option>
          <option value={5}>5%</option>
          <option value={12}>12%</option>
          <option value={18}>18%</option>
          <option value={28}>28%</option>
        </select>
      </div>

      <div class="input-group">
        <label>Purchase Date</label>
        <input type="date" bind:value={newPurchase.purchase_date} />
      </div>

      <div class="input-group">
        <label>Recorded By (Partner)</label>
        <select bind:value={newPurchase.created_by}>
          <option value="">Select Partner</option>
          {#if companySettings?.partner1_name}
            <option value={companySettings.partner1_name}>{companySettings.partner1_name}</option>
          {/if}
          {#if companySettings?.partner2_name}
            <option value={companySettings.partner2_name}>{companySettings.partner2_name}</option>
          {/if}
        </select>
      </div>

      <div class="input-group">
        <label>Payment Mode</label>
        <select bind:value={newPurchase.payment_mode}>
          <option value="Cash">Cash</option>
          <option value="Bank">Bank / Cheque</option>
          <option value="Online">Online / UPI</option>
          <option value="Credit">Credit</option>
        </select>
      </div>

      <div class="input-group">
        <label>Upload Purchase Bill (PDF/Image)</label>
        <input type="file" accept="image/*,.pdf" onchange={(e) => billFile = e.currentTarget.files?.[0] || null} />
      </div>

      {#if newPurchase.payment_mode === 'Bank'}
        <div class="input-group">
          <label>Cheque Number / Ref</label>
          <input type="text" bind:value={newPurchase.payment_details} placeholder="Enter cheque number" />
        </div>
      {:else if newPurchase.payment_mode === 'Online'}
        <div class="input-group">
          <label>Transaction ID / UPI Ref</label>
          <input type="text" bind:value={newPurchase.payment_details} placeholder="Enter transaction ID" />
        </div>
      {/if}
    </div>
    <button class="add-btn" onclick={handleAddPurchase} disabled={uploading}>
      <Plus size={18} /> {uploading ? 'Uploading...' : 'Add Purchase'}
    </button>
  </div>

  {#if showEditForm && editingPurchase}
    <div class="edit-form-card">
      <div class="form-header">
        <h3>Edit Purchase: {editingPurchase.purchase_number}</h3>
        <button class="close-btn" onclick={() => { showEditForm = false; editingPurchase = null; }}>✕</button>
      </div>
      
      <div class="form-grid">
        <div class="input-group">
          <label>Supplier (Directory)</label>
          <select bind:value={editingPurchase.supplier_id}>
            <option value="">Manual Entry (below)</option>
            {#each suppliers as supplier}
              <option value={supplier.id}>{supplier.name}</option>
            {/each}
          </select>
        </div>

        {#if !editingPurchase.supplier_id}
          <div class="input-group">
            <label>Manual Supplier Name</label>
            <input type="text" bind:value={editingPurchase.supplier_name} />
          </div>
        {/if}

        <div class="input-group">
          <label>Product (Inventory)</label>
          <select bind:value={editingPurchase.product_item}>
            <option value="">Manual Entry (below)</option>
            {#each inventory as item}
              <option value={item.id}>{item.item_name}</option>
            {/each}
          </select>
        </div>

        {#if !editingPurchase.product_item}
          <div class="input-group">
            <label>Product Name (Manual)</label>
            <input type="text" bind:value={editingPurchase.product_name} />
          </div>
        {/if}

        <div class="input-group">
          <label>Quantity</label>
          <input type="number" bind:value={editingPurchase.quantity} step="0.01" />
        </div>

        <div class="input-group">
          <label>Rate</label>
          <input type="number" bind:value={editingPurchase.rate} step="0.01" />
        </div>

        <div class="input-group">
          <label>GST Rate (%)</label>
          <select bind:value={editingPurchase.gst_rate}>
            <option value={0}>0%</option>
            <option value={5}>5%</option>
            <option value={12}>12%</option>
            <option value={18}>18%</option>
            <option value={28}>28%</option>
          </select>
        </div>

        <div class="input-group">
          <label>Date</label>
          <input type="date" bind:value={editingPurchase.purchase_date} />
        </div>

        <div class="input-group">
          <label>Recorded By (Partner)</label>
          <select bind:value={editingPurchase.created_by}>
            <option value="">Select Partner</option>
            {#if companySettings?.partner1_name}
              <option value={companySettings.partner1_name}>{companySettings.partner1_name}</option>
            {/if}
            {#if companySettings?.partner2_name}
              <option value={companySettings.partner2_name}>{companySettings.partner2_name}</option>
            {/if}
          </select>
        </div>

        <div class="input-group">
          <label>Payment Mode</label>
          <select bind:value={editingPurchase.payment_mode}>
            <option value="Cash">Cash</option>
            <option value="Bank">Bank / Cheque</option>
            <option value="Online">Online / UPI</option>
            <option value="Credit">Credit</option>
          </select>
        </div>

        {#if editingPurchase.payment_mode === 'Bank'}
          <div class="input-group">
            <label>Cheque No / Ref</label>
            <input type="text" bind:value={editingPurchase.payment_details} />
          </div>
        {:else if editingPurchase.payment_mode === 'Online'}
          <div class="input-group">
            <label>Transaction ID / UPI</label>
            <input type="text" bind:value={editingPurchase.payment_details} />
          </div>
        {/if}
      </div>
      <div class="form-actions">
        <button class="btn-submit" onclick={handleUpdatePurchase}>Update Purchase</button>
        <button class="btn-cancel" onclick={() => { showEditForm = false; editingPurchase = null; }}>Cancel</button>
      </div>
    </div>
  {/if}

  <div class="purchases-list">
    <h3>Recent Purchases</h3>
    <table>
      <thead>
        <tr>
          <th>ID</th>
          <th>Date</th>
          <th>Supplier</th>
          <th>Product</th>
          <th>Qty</th>
          <th>Total</th>
          <th>Bill</th>
          <th>Status</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        {#each purchases as pur}
          <tr class={pur.is_done ? 'done' : ''}>
            <td>{pur.purchase_number}</td>
            <td>{new Date(pur.purchase_date).toLocaleDateString()}</td>
            <td>{pur.suppliers?.name || pur.supplier_name || 'N/A'}</td>
            <td>{pur.product_name || pur.inventory?.item_name || 'N/A'}</td>
            <td>{pur.quantity} {pur.inventory?.unit || ''}</td>
            <td>₹{pur.total_amount.toLocaleString()}</td>
            <td>
              {#if pur.bill_url}
                <a href={getBillUrl(pur.bill_url)} target="_blank" class="view-bill-link">
                  <FileText size={16} /> View
                </a>
              {:else}
                <span class="no-bill">-</span>
              {/if}
            </td>
            <td class="status-cell">
              <button class="done-btn" onclick={() => toggleDone(pur.id, pur.is_done)}>
                {#if pur.is_done}
                  <CheckCircle size={18} />
                {:else}
                  <Circle size={18} />
                {/if}
              </button>
            </td>
            <td class="actions">
              <button onclick={() => openEditForm(pur)} class="edit-btn" title="Edit Purchase">
                <Edit2 size={16} />
              </button>
              <button onclick={() => deletePurchase(pur)} class="delete-btn">
                <Trash2 size={16} />
              </button>
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
</div>

<style>
  .purchases-container h2 {
    margin-bottom: 30px;
    color: #2c3e50;
  }

  .purchase-form-card, .edit-form-card {
    background: white;
    padding: 25px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    margin-bottom: 30px;
  }

  .edit-form-card {
    border: 2px solid #e67e22;
  }

  .form-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
    border-bottom: 2px solid #ecf0f1;
    padding-bottom: 10px;
  }

  .close-btn {
    background: none;
    border: none;
    font-size: 20px;
    cursor: pointer;
    color: #95a5a6;
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
    font-weight: 600;
    color: #666;
  }

  .input-group select, .input-group input, .input-group textarea {
    width: 100%;
    padding: 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-family: inherit;
  }

  .input-group textarea {
    height: 60px;
    resize: vertical;
  }

  .full-width {
    grid-column: 1 / -1;
  }

  .add-btn {
    background-color: #e67e22;
    color: white;
    border: none;
    padding: 12px 24px;
    border-radius: 4px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 8px;
    font-weight: bold;
  }

  .form-actions {
    display: flex;
    gap: 10px;
  }

  .btn-submit {
    background: #27ae60;
    color: white;
    padding: 10px 20px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-weight: bold;
  }

  .btn-cancel {
    background: #bdc3c7;
    color: #2c3e50;
    padding: 10px 20px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
  }

  .toggle-label {
    display: flex;
    align-items: center;
    gap: 8px;
    cursor: pointer;
  }

  .purchases-list {
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

  .actions {
    display: flex;
    gap: 10px;
  }

  .view-bill-link {
    display: flex;
    align-items: center;
    gap: 4px;
    color: #3498db;
    text-decoration: none;
    font-size: 0.85rem;
    font-weight: 600;
  }

  .view-bill-link:hover {
    text-decoration: underline;
  }

  .no-bill {
    color: #bdc3c7;
  }

  .edit-btn {
    background: none;
    border: 1px solid #f39c12;
    color: #f39c12;
    padding: 5px;
    border-radius: 4px;
    cursor: pointer;
  }

  .delete-btn {
    background: none;
    border: 1px solid #e74c3c;
    color: #e74c3c;
    padding: 5px;
    border-radius: 4px;
    cursor: pointer;
  }

  tr.done {
    opacity: 0.6;
    background: #f9f9f9;
  }

  .done-btn {
    background: none;
    border: none;
    cursor: pointer;
    color: #95a5a6;
  }

  tr.done .done-btn {
    color: #27ae60;
  }
</style>
