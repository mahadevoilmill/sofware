<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations, financialYear, getFYDateRange } from '$lib/i18n';
  import { Landmark, Plus, Minus, Download, Trash2, Camera, FileText } from 'lucide-svelte';

  const t = $derived(translations[$language]);

  let transactions = $state<any[]>([]);
  let companySettings = $state<any>(null);
  let totalBalance = $state(0);
  let uploading = $state(false);
  let slipFile = $state<File | null>(null);

  let newTransaction = $state({
    partner_name: '',
    type: 'deposit',
    amount: 0,
    notes: '',
    transaction_date: new Date().toISOString().split('T')[0]
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
    
    // Fetch Company Settings for partner names
    const { data: setts } = await supabase.from('company_settings').select('*');
    companySettings = setts?.[0] || null;

    // Fetch Transactions for selected FY
    const { data, error } = await supabase
      .from('bank_transactions')
      .select('*')
      .gte('transaction_date', start)
      .lte('transaction_date', end)
      .order('transaction_date', { ascending: false })
      .order('created_at', { ascending: false });

    if (!error) {
      transactions = data || [];
      calculateBalance();
    }
  }

  function calculateBalance() {
    // Total balance is usually across all time, but we'll show balance for the current view
    totalBalance = transactions.reduce((acc, curr) => {
      return curr.type === 'deposit' ? acc + Number(curr.amount) : acc - Number(curr.amount);
    }, 0);
  }

  async function handleAddTransaction() {
    if (newTransaction.amount <= 0 || !newTransaction.partner_name) {
      alert('Please enter amount and partner name');
      return;
    }

    uploading = true;
    let slip_path = '';

    if (slipFile) {
      const fileExt = slipFile.name.split('.').pop();
      const fileName = `${Date.now()}.${fileExt}`;
      const filePath = `slips/${fileName}`;

      const { data: uploadData, error: uploadError } = await supabase.storage
        .from('bank-slips')
        .upload(filePath, slipFile);

      if (uploadError) {
        alert('Error uploading slip: ' + uploadError.message);
        uploading = false;
        return;
      }
      slip_path = filePath;
    }

    const { error } = await supabase.from('bank_transactions').insert({
      ...newTransaction,
      slip_url: slip_path
    });

    if (!error) {
      newTransaction = {
        partner_name: '',
        type: 'deposit',
        amount: 0,
        notes: '',
        transaction_date: new Date().toISOString().split('T')[0]
      };
      slipFile = null;
      uploading = false;
      await fetchData();
      alert('Transaction recorded!');
    } else {
      uploading = false;
      alert('Error: ' + error.message);
    }
  }

  async function deleteTransaction(id: string) {
    if (confirm('Delete this record?')) {
      await supabase.from('bank_transactions').delete().eq('id', id);
      await fetchData();
    }
  }

  function getSlipUrl(path: string) {
    if (!path) return null;
    const { data } = supabase.storage.from('bank-slips').getPublicUrl(path);
    return data.publicUrl;
  }
</script>

<div class="banking-container">
  <div class="header">
    <h2><Landmark size={32} style="vertical-align: middle; margin-right: 10px;" /> {t.banking}</h2>
    <div class="balance-card">
      <span class="label">FY Net Bank Movement</span>
      <span class="value {totalBalance >= 0 ? 'plus' : 'minus'}">
        ₹{Math.abs(totalBalance).toLocaleString()}
        {totalBalance >= 0 ? ' (Cr)' : ' (Dr)'}
      </span>
    </div>
  </div>

  <div class="transaction-form-card">
    <h3>New Entry</h3>
    <div class="form-grid">
      <div class="input-group">
        <label>Transaction Type</label>
        <select bind:value={newTransaction.type}>
          <option value="deposit">📥 Deposit (Money In)</option>
          <option value="withdrawal">📤 Withdrawal (Money Out)</option>
        </select>
      </div>

      <div class="input-group">
        <label>Partner / Person Name</label>
        <select bind:value={newTransaction.partner_name}>
          <option value="">Select Partner</option>
          {#if companySettings?.partner1_name}
            <option value={companySettings.partner1_name}>{companySettings.partner1_name}</option>
          {/if}
          {#if companySettings?.partner2_name}
            <option value={companySettings.partner2_name}>{companySettings.partner2_name}</option>
          {/if}
          <option value="Other">Other</option>
        </select>
      </div>

      <div class="input-group">
        <label>Amount (₹)</label>
        <input type="number" bind:value={newTransaction.amount} min="1" step="0.01" />
      </div>

      <div class="input-group">
        <label>Date</label>
        <input type="date" bind:value={newTransaction.transaction_date} />
      </div>

      <div class="input-group">
        <label>Upload Slip / Photo</label>
        <div class="file-input-wrapper">
          <input type="file" accept="image/*,.pdf" onchange={(e) => slipFile = e.currentTarget.files?.[0] || null} id="slip" />
          <label for="slip" class="file-label"><Camera size={16} /> {slipFile ? slipFile.name : 'Choose Photo'}</label>
        </div>
      </div>

      <div class="input-group full-width">
        <label>Notes (Optional)</label>
        <input type="text" bind:value={newTransaction.notes} placeholder="e.g. Cash Deposit in Vasad Branch" />
      </div>
    </div>
    <button class="add-btn {newTransaction.type}" onclick={handleAddTransaction} disabled={uploading}>
      <Plus size={18} /> {uploading ? 'Processing...' : 'Record Transaction'}
    </button>
  </div>

  <div class="history-list">
    <h3>Recent Transactions</h3>
    <table>
      <thead>
        <tr>
          <th>Date</th>
          <th>Partner</th>
          <th>Type</th>
          <th>Amount</th>
          <th>Slip</th>
          <th>Notes</th>
          <th>Action</th>
        </tr>
      </thead>
      <tbody>
        {#each transactions as tx}
          <tr class={tx.type}>
            <td>{new Date(tx.transaction_date).toLocaleDateString()}</td>
            <td><strong>{tx.partner_name}</strong></td>
            <td>
              <span class="type-tag {tx.type}">
                {tx.type === 'deposit' ? '📥 Deposit' : '📤 Withdrawal'}
              </span>
            </td>
            <td>₹{Number(tx.amount).toLocaleString()}</td>
            <td>
              {#if tx.slip_url}
                <a href={getSlipUrl(tx.slip_url)} target="_blank" class="view-link">
                  <FileText size={16} /> View
                </a>
              {:else}
                <span class="no-slip">-</span>
              {/if}
            </td>
            <td class="notes-cell">{tx.notes || '-'}</td>
            <td>
              <button onclick={() => deleteTransaction(tx.id)} class="delete-btn">
                <Trash2 size={16} />
              </button>
            </td>
          </tr>
        {:else}
          <tr>
            <td colspan="7" class="no-data">No transactions found for this year</td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
</div>

<style>
  .banking-container {
    max-width: 1200px;
  }

  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 30px;
  }

  .balance-card {
    background: white;
    padding: 15px 25px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    text-align: right;
  }

  .balance-card .label {
    display: block;
    font-size: 0.8rem;
    color: #7f8c8d;
    text-transform: uppercase;
    font-weight: bold;
  }

  .balance-card .value {
    font-size: 1.5rem;
    font-weight: bold;
  }

  .value.plus { color: #27ae60; }
  .value.minus { color: #e74c3c; }

  .transaction-form-card {
    background: white;
    padding: 25px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    margin-bottom: 30px;
  }

  .form-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 20px;
    margin-bottom: 20px;
  }

  .full-width {
    grid-column: 1 / -1;
  }

  .input-group label {
    display: block;
    margin-bottom: 5px;
    font-size: 0.9rem;
    font-weight: 600;
    color: #666;
  }

  .input-group select, .input-group input {
    width: 100%;
    padding: 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-family: inherit;
  }

  .file-input-wrapper {
    position: relative;
  }

  .file-input-wrapper input {
    display: none;
  }

  .file-label {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px;
    background: #f8f9fa;
    border: 1px dashed #cbd5e0;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.9rem;
    color: #4a5568;
  }

  .add-btn {
    color: white;
    border: none;
    padding: 12px 24px;
    border-radius: 4px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 8px;
    font-weight: bold;
    transition: opacity 0.3s;
  }

  .add-btn.deposit { background-color: #27ae60; }
  .add-btn.withdrawal { background-color: #e67e22; }
  .add-btn:disabled { opacity: 0.7; cursor: not-allowed; }

  .history-list {
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

  th {
    color: #7f8c8d;
    font-size: 0.85rem;
    text-transform: uppercase;
  }

  .type-tag {
    padding: 4px 8px;
    border-radius: 12px;
    font-size: 0.75rem;
    font-weight: bold;
  }

  .type-tag.deposit { background: #eafaf1; color: #27ae60; }
  .type-tag.withdrawal { background: #fef5e7; color: #e67e22; }

  .view-link {
    color: #3498db;
    text-decoration: none;
    display: flex;
    align-items: center;
    gap: 4px;
    font-weight: 600;
    font-size: 0.85rem;
  }

  .delete-btn {
    background: none;
    border: none;
    color: #e74c3c;
    cursor: pointer;
    opacity: 0.6;
  }

  .delete-btn:hover { opacity: 1; }

  .no-data { text-align: center; color: #95a5a6; padding: 40px; }
  .notes-cell { font-size: 0.85rem; color: #7f8c8d; max-width: 200px; }
</style>
