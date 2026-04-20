<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations, financialYear, getFYDateRange } from '$lib/i18n';
  import jsPDF from 'jspdf';
  import { Landmark, Plus, Minus, Download, Trash2, Camera, FileText, Receipt } from 'lucide-svelte';

  const t = $derived(translations[$language]);

  let transactions = $state<any[]>([]);
  let companySettings = $state<any>(null);
  let totalBalance = $state(0);
  let uploading = $state(false);
  let slipFile = $state<File | null>(null);

  // Voucher Entry
  let showVoucherForm = $state(false);
  let ledgers = $state<any[]>([]);
  let vouchers = $state<any[]>([]);
  let voucherType = $state('sales');
  let voucherParty = $state('');
  let voucherName = $state('');
  let voucherAmount = $state(0);
  let voucherGst = $state(0);
  let voucherNarration = $state('');
  let voucherLoading = $state(false);

  // Debit/Credit entries
  let voucherEntries = $state([
    { ledger_name: '', debit: 0, credit: 0 },
    { ledger_name: '', debit: 0, credit: 0 }
  ]);

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

    // Fetch ledgers for voucher entry
    const { data: ledgerData } = await supabase.from('ledgers').select('*').order('name');
    ledgers = ledgerData || [];

    // Fetch vouchers
    const { data: voucherData } = await supabase
      .from('vouchers')
      .select('*, voucher_entries(*)')
      .gte('voucher_date', start)
      .lte('voucher_date', end)
      .order('created_at', { ascending: false });
    vouchers = voucherData || [];
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

  async function saveVoucher() {
    if (voucherAmount <= 0) {
      alert('Please enter amount');
      return;
    }

    // Validate entries
    const validEntries = voucherEntries.filter(e => e.ledger_name);
    if (validEntries.length < 2) {
      alert('Please add at least 2 ledger entries');
      return;
    }

    voucherLoading = true;

    try {
      // Generate voucher number
      const { data: lastVoucher } = await supabase
        .from('vouchers')
        .select('voucher_number')
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      
      let nextNum = 1;
      if (lastVoucher) {
        const lastNum = parseInt(lastVoucher.voucher_number.replace('V-', ''), 10);
        nextNum = isNaN(lastNum) ? 1 : lastNum + 1;
      }
      const voucher_number = `V-${nextNum.toString().padStart(4, '0')}`;

      // Create voucher
      const { data: voucher, error: voucherError } = await supabase
        .from('vouchers')
        .insert([{
          voucher_type: voucherType,
          name: voucherName,
          voucher_number,
          voucher_date: new Date().toISOString().split('T')[0],
          total_amount: voucherAmount,
          gst_amount: voucherGst,
          narration: voucherNarration
        }])
        .select()
        .single();

      if (voucherError) throw new Error(voucherError.message);

      // Add voucher entries
      const entriesToInsert = validEntries.map(entry => ({
        voucher_id: voucher.id,
        ledger_name: entry.ledger_name,
        debit: entry.debit || 0,
        credit: entry.credit || 0
      }));

      const { error: entriesError } = await supabase
        .from('voucher_entries')
        .insert(entriesToInsert);

      if (entriesError) throw new Error(entriesError.message);

      // Reset form
      voucherType = 'sales';
      voucherParty = '';
      voucherAmount = 0;
      voucherGst = 0;
      voucherNarration = '';
      voucherEntries = [
        { ledger_name: '', debit: 0, credit: 0 },
        { ledger_name: '', debit: 0, credit: 0 }
      ];

      await fetchData();
      alert('Voucher saved!');
    } catch (err: any) {
      alert('Error: ' + err.message);
    } finally {
      voucherLoading = false;
    }
  }

  function addVoucherEntry() {
    voucherEntries = [...voucherEntries, { ledger_name: '', debit: 0, credit: 0 }];
  }

  function removeVoucherEntry(index: number) {
    voucherEntries = voucherEntries.filter((_, i) => i !== index);
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

  async function generateVoucherPDF(voucher: any) {
    const doc = new jsPDF({
      orientation: 'portrait',
      unit: 'mm',
      format: 'a4'
    });

    const pageWidth = doc.internal.pageSize.getWidth();
    const margin = 10;
    const contentWidth = pageWidth - (margin * 2);

    // Header
    doc.setFontSize(14);
    doc.setFont('helvetica', 'bold');
    doc.text('VOUCHER', pageWidth / 2, margin + 5, { align: 'center' });

    doc.setFontSize(10);
    doc.setFont('helvetica', 'normal');
    doc.text(`Voucher No: ${voucher.voucher_number}`, margin, margin + 15);
    doc.text(`Date: ${new Date(voucher.voucher_date).toLocaleDateString('en-IN')}`, pageWidth - margin - 30, margin + 15);
    doc.text(`Type: ${voucher.voucher_type.toUpperCase()}`, margin, margin + 22);

    if (voucher.name) {
      doc.text(`Name: ${voucher.name}`, margin, margin + 29);
    }

    // Table
    let y = margin + 40;
    doc.setFontSize(10);
    doc.setFont('helvetica', 'bold');
    
    // Table header
    doc.rect(margin, y - 3, contentWidth, 8);
    doc.text('Ledger', margin + 2, y + 2);
    doc.text('Debit', margin + 90, y + 2);
    doc.text('Credit', margin + 130, y + 2);

    doc.setFont('helvetica', 'normal');
    y += 10;

    // Entries
    const entries = voucher.voucher_entries || [];
    for (const entry of entries) {
      doc.text(entry.ledger_name || '', margin + 2, y);
      doc.text(entry.debit ? entry.debit.toString() : '', margin + 90, y);
      doc.text(entry.credit ? entry.credit.toString() : '', margin + 130, y);
      y += 8;
    }

    // Total
    y += 5;
    doc.line(margin, y, pageWidth - margin, y);
    y += 8;
    doc.setFont('helvetica', 'bold');
    doc.text('Total:', margin + 70, y);
    doc.text(voucher.total_amount.toString(), margin + 90, y);
    doc.text(voucher.total_amount.toString(), margin + 130, y);

    // Narration
    if (voucher.narration) {
      y += 15;
      doc.setFont('helvetica', 'normal');
      doc.text('Narration:', margin, y);
      doc.text(voucher.narration, margin + 25, y);
    }

    // Signatures
    y = doc.internal.pageSize.getHeight() - 30;
    doc.line(margin, y, margin + 50, y);
    doc.setFontSize(8);
    doc.text('Prepared By', margin, y + 5);

    doc.line(pageWidth - margin - 50, y, pageWidth - margin, y);
    doc.text('Authorized Sign', pageWidth - margin - 50, y + 5);

    doc.save(`${voucher.voucher_number}.pdf`);
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

  <!-- Tabs -->
  <div class="tabs">
    <button class="tab" class:active={!showVoucherForm} onclick={() => showVoucherForm = false}>
      <Landmark size={16} /> Bank Entry
    </button>
    <button class="tab" class:active={showVoucherForm} onclick={() => showVoucherForm = true}>
      <Receipt size={16} /> Voucher Entry
    </button>
  </div>

  {#if showVoucherForm}
    <!-- Voucher Entry Form -->
    <div class="voucher-form-card">
      <h3>New Voucher Entry</h3>
      <div class="form-grid">
        <div class="input-group">
          <label>Voucher Type</label>
          <select bind:value={voucherType}>
            <option value="sales">Sales Voucher</option>
            <option value="purchase">Purchase Voucher</option>
            <option value="payment">Payment Voucher</option>
            <option value="receipt">Receipt Voucher</option>
            <option value="journal">Journal Voucher</option>
          </select>
        </div>
        <div class="input-group">
          <label>Name / Party</label>
          <input type="text" bind:value={voucherName} placeholder="Enter name" />
        </div>
        <div class="input-group">
          <label>Amount (₹)</label>
          <input type="number" bind:value={voucherAmount} min="0" step="0.01" />
        </div>
        <div class="input-group">
          <label>GST Amount (₹)</label>
          <input type="number" bind:value={voucherGst} min="0" step="0.01" />
        </div>
        <div class="input-group full-width">
          <label>Narration</label>
          <input type="text" bind:value={voucherNarration} placeholder="Enter narration" />
        </div>
      </div>

      <h4>Ledger Entries</h4>
      <div class="ledger-entries">
        {#each voucherEntries as entry, i}
          <div class="ledger-row">
            <select bind:value={entry.ledger_name}>
              <option value="">Select Ledger</option>
              {#each ledgers as ledger}
                <option value={ledger.name}>{ledger.name}</option>
              {/each}
            </select>
            <input type="number" bind:value={entry.debit} placeholder="Debit" min="0" step="0.01" />
            <input type="number" bind:value={entry.credit} placeholder="Credit" min="0" step="0.01" />
            {#if voucherEntries.length > 2}
              <button type="button" onclick={() => removeVoucherEntry(i)} class="remove-entry">✕</button>
            {/if}
          </div>
        {/each}
      </div>
      <button type="button" onclick={addVoucherEntry} class="add-entry-btn">+ Add Ledger</button>

      <button class="add-btn" onclick={saveVoucher} disabled={voucherLoading}>
        <Plus size={18} /> {voucherLoading ? 'Saving...' : 'Save Voucher'}
      </button>
    </div>

    <!-- Voucher List -->
    {#if vouchers.length > 0}
      <div class="voucher-list">
        <h3>Saved Vouchers</h3>
        <table>
          <thead>
            <tr>
              <th>V.No</th>
              <th>Date</th>
              <th>Type</th>
              <th>Name</th>
              <th>Amount</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {#each vouchers as voucher}
              <tr>
                <td>{voucher.voucher_number}</td>
                <td>{new Date(voucher.voucher_date).toLocaleDateString('en-IN')}</td>
                <td>{voucher.voucher_type}</td>
                <td>{voucher.name || 'N/A'}</td>
                <td>₹{voucher.total_amount?.toLocaleString()}</td>
                <td>
                  <button onclick={() => generateVoucherPDF(voucher)} class="pdf-btn" title="Download PDF">
                    <Download size={16} />
                  </button>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  {:else}
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
  {/if}
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

  .tabs { display: flex; gap: 10px; margin-bottom: 20px; }
  .tab {
    padding: 12px 24px;
    border: none;
    background: #e0e0e0;
    cursor: pointer;
    border-radius: 8px;
    display: flex;
    align-items: center;
    gap: 8px;
    font-weight: 600;
  }
  .tab.active { background: #3498db; color: white; }

  .voucher-form-card {
    background: white;
    padding: 25px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    margin-bottom: 30px;
  }
  .ledger-entries { margin: 15px 0; }
  .ledger-row {
    display: flex;
    gap: 10px;
    margin-bottom: 10px;
    align-items: center;
  }
  .ledger-row select, .ledger-row input {
    padding: 8px;
    border: 1px solid #ddd;
    border-radius: 4px;
  }
  .ledger-row select { flex: 1; }
  .ledger-row input { width: 100px; }
  .remove-entry {
    background: #e74c3c;
    color: white;
    border: none;
    width: 30px;
    height: 30px;
    border-radius: 4px;
    cursor: pointer;
  }
  .add-entry-btn {
    background: none;
    border: 1px dashed #3498db;
    color: #3498db;
    padding: 8px 16px;
    border-radius: 4px;
    cursor: pointer;
    margin-bottom: 15px;
  }

  .voucher-list {
    background: white;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    margin-bottom: 30px;
  }
  .voucher-list h3 { margin-top: 0; }
  .pdf-btn {
    background: #e74c3c;
    color: white;
    border: none;
    padding: 6px 10px;
    border-radius: 4px;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
  }
</style>
