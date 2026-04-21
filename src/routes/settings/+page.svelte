<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations } from '$lib/i18n';
  import { Save, RefreshCw, Trash2, Edit } from 'lucide-svelte';

  const t = $derived(translations[$language]);

  let loading = $state(false);
  let success = $state(false);
  let error = $state<string | null>(null);

  let settings = $state({
    id: '',
    company_name: '',
    address: '',
    gstin: '',
    pan: '',
    state_name: '',
    state_code: '',
    contact_no: '',
    bank_name: '',
    account_no: '',
    branch_ifsc: '',
    upi_id: '',
    fssai_code: '',
    partner1_name: '',
    partner1_mobile: '',
    partner1_investment_cash: 0,
    partner1_investment_bank: 0,
    partner1_investment_date: new Date().toISOString().split('T')[0],
    partner1_investment_year: new Date().getFullYear().toString(),
    partner2_name: '',
    partner2_mobile: '',
    partner2_investment_cash: 0,
    partner2_investment_bank: 0,
    partner2_investment_date: new Date().toISOString().split('T')[0],
    partner2_investment_year: new Date().getFullYear().toString(),
    logo_url: ''
  });

  let logoFile = $state<File | null>(null);
  let logoPreview = $state<string | null>(null);

  $effect(() => {
    if (logoFile) {
      const reader = new FileReader();
      reader.onload = (e) => {
        logoPreview = e.target?.result as string;
      };
      reader.readAsDataURL(logoFile);
    } else {
      logoPreview = null;
    }
  });

  let investments = $state<any[]>([]);
  let newInvestment = $state({
    id: null as string | null,
    partner_name: '',
    amount_cash: 0,
    amount_bank: 0,
    investment_date: new Date().toISOString().split('T')[0],
    investment_year: '2024-25'
  });

  onMount(async () => {
    await fetchSettings();
    await fetchInvestments();
  });

  async function fetchInvestments() {
    const { data, error: invError } = await supabase
      .from('partner_investments')
      .select('*')
      .order('investment_date', { ascending: false });
    
    if (!invError) {
      investments = data || [];
    }
  }

  async function handleAddInvestment() {
    if (!newInvestment.partner_name || !newInvestment.investment_year) {
      alert('Please fill partner name and year');
      return;
    }

    let result;
    if (newInvestment.id) {
      const { id, ...data } = newInvestment;
      result = await supabase.from('partner_investments').update(data).eq('id', id);
    } else {
      const { id, ...data } = newInvestment;
      result = await supabase.from('partner_investments').insert(data);
    }

    if (result.error) {
      alert('Error saving investment: ' + result.error.message);
    } else {
      newInvestment = {
        id: null,
        partner_name: '',
        amount_cash: 0,
        amount_bank: 0,
        investment_date: new Date().toISOString().split('T')[0],
        investment_year: '2024-25'
      };
      await fetchInvestments();
      alert('Investment saved successfully!');
    }
  }

  async function deleteInvestment(id: string) {
    if (confirm('Delete this investment entry?')) {
      const { error: delError } = await supabase.from('partner_investments').delete().eq('id', id);
      if (delError) {
        alert('Error deleting investment: ' + delError.message);
      } else {
        await fetchInvestments();
        alert('Investment deleted!');
      }
    }
  }

  async function editInvestment(inv: any) {
    newInvestment = { ...inv };
  }

  async function fetchSettings() {
    loading = true;
    try {
      const { data, error: fetchError } = await supabase
        .from('company_settings')
        .select('*')
        .single();

      if (fetchError && fetchError.code !== 'PGRST116') { // PGRST116 is 'No rows found'
        throw fetchError;
      }

      if (data) {
        settings = { 
          id: data.id || '',
          company_name: data.company_name || '',
          address: data.address || '',
          gstin: data.gstin || '',
          pan: data.pan || '',
          state_name: data.state_name || '',
          state_code: data.state_code || '',
          contact_no: data.contact_no || '',
          bank_name: data.bank_name || '',
          account_no: data.account_no || '',
          branch_ifsc: data.branch_ifsc || '',
          upi_id: data.upi_id || '',
          fssai_code: data.fssai_code || '',
          partner1_name: data.partner1_name || '',
          partner1_mobile: data.partner1_mobile || '',
          partner1_investment_cash: data.partner1_investment_cash || 0,
          partner1_investment_bank: data.partner1_investment_bank || 0,
          partner1_investment_date: data.partner1_investment_date || new Date().toISOString().split('T')[0],
          partner1_investment_year: data.partner1_investment_year || new Date().getFullYear().toString(),
          partner2_name: data.partner2_name || '',
          partner2_mobile: data.partner2_mobile || '',
          partner2_investment_cash: data.partner2_investment_cash || 0,
          partner2_investment_bank: data.partner2_investment_bank || 0,
          partner2_investment_date: data.partner2_investment_date || new Date().toISOString().split('T')[0],
          partner2_investment_year: data.partner2_investment_year || new Date().getFullYear().toString(),
          logo_url: data.logo_url || ''
        };
      }
    } catch (err: any) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  async function handleSave() {
    loading = true;
    success = false;
    error = null;

    try {
      let finalSettings = { ...settings };
      
      // Upload Logo if selected
      if (logoFile) {
        const fileExt = logoFile.name.split('.').pop();
        const fileName = `logo_${Date.now()}.${fileExt}`;
        const filePath = `branding/${fileName}`;

        const { data: uploadData, error: uploadError } = await supabase.storage
          .from('company-assets')
          .upload(filePath, logoFile);

        if (uploadError) throw new Error(`Logo Upload Failed: ${uploadError.message}`);
        
        const { data: urlData } = supabase.storage.from('company-assets').getPublicUrl(filePath);
        finalSettings.logo_url = urlData.publicUrl;
      }

      let result;
      if (settings.id) {
        // Update existing record
        const { id, ...dbData } = finalSettings;
        result = await supabase
          .from('company_settings')
          .update(dbData)
          .eq('id', settings.id);
      } else {
        // Create new record
        const { id, ...newData } = finalSettings;
        result = await supabase
          .from('company_settings')
          .insert(newData)
          .select()
          .single();
        if (result.data) finalSettings.id = result.data.id;
      }

      if (result.error) throw new Error(`Database Error: ${result.error.message}`);

      settings = { ...finalSettings };
      success = true;
      logoFile = null;
      logoPreview = null;

      setTimeout(() => success = false, 3000);
    } catch (err: any) {
      error = err.message;
    } finally {
      loading = false;
    }
  }
</script>

<div class="settings-container">
  <div class="header">
    <h2>Settings</h2>
    <p>Manage your company and bank details for invoices</p>
  </div>

  {#if error}
    <div class="error-banner">{error}</div>
  {/if}

  {#if success}
    <div class="success-banner">Settings saved successfully!</div>
  {/if}

  <div class="settings-grid">
    <!-- Company Information -->
    <div class="settings-card">
      <h3>Company Information</h3>

      <div class="logo-upload-section">
        {#if logoPreview || settings.logo_url}
          <div class="logo-preview">
            <img src={logoPreview || settings.logo_url} alt="Logo Preview" />
          </div>
        {/if}
        <div class="form-group">
          <label>Company Logo</label>
          <input type="file" accept="image/*" onchange={(e) => logoFile = e.currentTarget.files?.[0] || null} />
          <p class="help-text">Recommended: Square PNG/JPG</p>
        </div>
      </div>
      <div class="form-group">
        <label>Company Name</label>
        <input type="text" bind:value={settings.company_name} placeholder="e.g. MAHADEV OIL MILL" />
      </div>
      <div class="form-group">
        <label>Address</label>
        <input type="text" bind:value={settings.address} placeholder="Street, City, State" />
      </div>
      <div class="row">
        <div class="form-group">
          <label>GSTIN</label>
          <input type="text" bind:value={settings.gstin} placeholder="GST Number" />
        </div>
        <div class="form-group">
          <label>PAN Number</label>
          <input type="text" bind:value={settings.pan} placeholder="PAN Number" />
        </div>
        <div class="form-group">
          <label>FSSAI Number</label>
          <input type="text" bind:value={settings.fssai_code} placeholder="FSSAI Number" />
        </div>
      </div>
      <div class="row">
        <div class="form-group">
          <label>State Name</label>
          <input type="text" bind:value={settings.state_name} placeholder="e.g. Gujarat" />
        </div>
        <div class="form-group">
          <label>State Code</label>
          <input type="text" bind:value={settings.state_code} placeholder="e.g. 24" />
        </div>
      </div>
      <div class="form-group">
        <label>Contact Number</label>
        <input type="text" bind:value={settings.contact_no} placeholder="Mobile / Phone" />
      </div>
    </div>

    <!-- Partner Details -->
    <div class="settings-card">
      <h3>Partner Details</h3>
      
      <!-- Partner 1 -->
      <div class="partner-group">
        <h4>Partner 1</h4>
        <div class="row">
          <div class="form-group">
            <label>Name</label>
            <input type="text" bind:value={settings.partner1_name} placeholder="Name" />
          </div>
          <div class="form-group">
            <label>Mobile</label>
            <input type="text" bind:value={settings.partner1_mobile} placeholder="Mobile" />
          </div>
        </div>
      </div>

      <!-- Partner 2 -->
      <div class="partner-group" style="margin-top: 20px; border-top: 1px solid #eee; padding-top: 20px;">
        <h4>Partner 2</h4>
        <div class="row">
          <div class="form-group">
            <label>Name</label>
            <input type="text" bind:value={settings.partner2_name} placeholder="Name" />
          </div>
          <div class="form-group">
            <label>Mobile</label>
            <input type="text" bind:value={settings.partner2_mobile} placeholder="Mobile" />
          </div>
        </div>
      </div>
    </div>

    <!-- Bank Details -->
    <div class="settings-card">
      <h3>Bank Details</h3>
      <div class="form-group">
        <label>Bank Name</label>
        <input type="text" bind:value={settings.bank_name} placeholder="e.g. State Bank of India" />
      </div>
      <div class="form-group">
        <label>Account Number</label>
        <input type="text" bind:value={settings.account_no} placeholder="Account Number" />
      </div>
      <div class="form-group">
        <label>Branch & IFSC Code</label>
        <input type="text" bind:value={settings.branch_ifsc} placeholder="e.g. VASAD & SBIN000XXXX" />
      </div>
      <div class="form-group">
        <label>UPI ID (for QR Code)</label>
        <input type="text" bind:value={settings.upi_id} placeholder="e.g. 8849735425@upi" />
      </div>
    </div>
  </div>

  <div class="header" style="margin-top: 50px;">
    <h2>Partner Investment Tracking</h2>
    <p>Record and view investment history year by year</p>
  </div>

  <div class="settings-grid">
    <!-- Add Investment Entry -->
    <div class="settings-card">
      <h3>{newInvestment.id ? 'Edit' : 'Add'} Investment Entry</h3>
      <div class="form-group">
        <label>Partner Name</label>
        <select bind:value={newInvestment.partner_name}>
          <option value="">Select Partner</option>
          {#if settings.partner1_name}<option value={settings.partner1_name}>{settings.partner1_name}</option>{/if}
          {#if settings.partner2_name}<option value={settings.partner2_name}>{settings.partner2_name}</option>{/if}
        </select>
      </div>
      <div class="row">
        <div class="form-group">
          <label>Amount (Cash)</label>
          <input type="number" bind:value={newInvestment.amount_cash} placeholder="₹ 0.00" />
        </div>
        <div class="form-group">
          <label>Amount (Bank)</label>
          <input type="number" bind:value={newInvestment.amount_bank} placeholder="₹ 0.00" />
        </div>
      </div>
      <div class="row">
        <div class="form-group">
          <label>Date</label>
          <input type="date" bind:value={newInvestment.investment_date} />
        </div>
        <div class="form-group">
          <label>Year</label>
          <select bind:value={newInvestment.investment_year}>
            {#each Array.from({ length: 50 }, (_, i) => {
              const start = 2020 + i;
              return `${start}-${(start + 1).toString().slice(-2)}`;
            }) as year}
              <option value={year}>{year}</option>
            {/each}
          </select>
        </div>
      </div>
      <button class="save-btn" style="width: 100%; margin-top: 10px;" onclick={handleAddInvestment}>
        <Save size={18} /> {newInvestment.id ? 'Update' : 'Add'} Entry
      </button>
      {#if newInvestment.id}
        <button class="btn-cancel" style="width: 100%; margin-top: 10px;" onclick={() => newInvestment = { id: null, partner_name: '', amount_cash: 0, amount_bank: 0, investment_date: new Date().toISOString().split('T')[0], investment_year: '2024-25' }}>
          Cancel
        </button>
      {/if}
    </div>

    <!-- Investment History -->
    <div class="settings-card" style="grid-column: span 2;">
      <h3>Investment History (Year Wise)</h3>
      <div class="table-container">
        <table>
          <thead>
            <tr>
              <th>Year</th>
              <th>Partner</th>
              <th>Date</th>
              <th>Cash</th>
              <th>Bank</th>
              <th>Total</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {#each investments as inv}
              <tr>
                <td><strong>{inv.investment_year}</strong></td>
                <td>{inv.partner_name}</td>
                <td>{new Date(inv.investment_date).toLocaleDateString("en-IN")}</td>
                <td>₹{inv.amount_cash.toLocaleString()}</td>
                <td>₹{inv.amount_bank.toLocaleString()}</td>
                <td><strong>₹{(inv.amount_cash + inv.amount_bank).toLocaleString()}</strong></td>
                <td class="actions-cell">
                  <button class="icon-btn edit" onclick={() => editInvestment(inv)} title="Edit"><Edit size={16} /></button>
                  <button class="icon-btn delete" onclick={() => deleteInvestment(inv.id)} title="Delete"><Trash2 size={16} /></button>
                </td>
              </tr>
            {:else}
              <tr>
                <td colspan="7" style="text-align: center; color: #95a5a6; padding: 20px;">No investment entries found.</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>
  </div>

  <div class="actions">
    <button class="save-btn" onclick={handleSave} disabled={loading}>
      {#if loading}
        <RefreshCw size={18} class="spin" /> Saving...
      {:else}
        <Save size={18} /> Save Settings
      {/if}
    </button>
  </div>
</div>

<style>
  .settings-container {
    max-width: 1000px;
    margin: 0 auto;
  }

  .header {
    margin-bottom: 30px;
  }

  .header h2 {
    color: #2c3e50;
    margin-bottom: 5px;
  }

  .header p {
    color: #7f8c8d;
    margin: 0;
  }

  .settings-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
    gap: 30px;
    margin-bottom: 30px;
  }

  .settings-card {
    background: white;
    padding: 25px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
  }

  .settings-card h3 {
    margin-top: 0;
    margin-bottom: 20px;
    color: #34495e;
    font-size: 1.1rem;
    border-bottom: 1px solid #eee;
    padding-bottom: 10px;
  }

  .logo-upload-section {
    display: flex;
    align-items: center;
    gap: 20px;
    margin-bottom: 20px;
    padding: 15px;
    background: #f8f9fa;
    border-radius: 8px;
  }

  .logo-preview {
    width: 60px;
    height: 60px;
    border-radius: 4px;
    overflow: hidden;
    border: 1px solid #ddd;
    background: white;
  }

  .logo-preview img {
    width: 100%;
    height: 100%;
    object-fit: contain;
  }

  .help-text {
    font-size: 0.75rem;
    color: #95a5a6;
    margin: 5px 0 0;
  }

  .form-group {
    margin-bottom: 15px;
  }

  .row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 15px;
  }

  label {
    display: block;
    font-size: 0.85rem;
    color: #7f8c8d;
    margin-bottom: 5px;
    font-weight: 600;
  }

  input {
    width: 100%;
    padding: 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 0.9rem;
    box-sizing: border-box;
  }

  input:focus {
    border-color: #3498db;
    outline: none;
    box-shadow: 0 0 0 2px rgba(52, 152, 219, 0.1);
  }

  .actions {
    display: flex;
    justify-content: flex-end;
  }

  .save-btn {
    background: #3498db;
    color: white;
    border: none;
    padding: 12px 30px;
    border-radius: 4px;
    font-weight: 600;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 10px;
    transition: background 0.3s;
  }

  .save-btn:hover:not(:disabled) {
    background: #2980b9;
  }

  .save-btn:disabled {
    opacity: 0.7;
    cursor: not-allowed;
  }

  .btn-cancel {
    background: #bdc3c7;
    color: white;
    border: none;
    padding: 12px 30px;
    border-radius: 4px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.3s;
  }

  .btn-cancel:hover {
    background: #95a5a6;
  }

  .error-banner {
    background: #fdeaea;
    color: #e74c3c;
    padding: 15px;
    border-radius: 4px;
    margin-bottom: 20px;
    border-left: 4px solid #e74c3c;
  }

  .success-banner {
    background: #eafaf1;
    color: #27ae60;
    padding: 15px;
    border-radius: 4px;
    margin-bottom: 20px;
    border-left: 4px solid #27ae60;
  }

  .table-container {
    overflow-x: auto;
  }

  table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 10px;
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
    font-weight: 600;
  }

  td {
    font-size: 0.9rem;
    color: #2c3e50;
  }

  .actions-cell {
    display: flex;
    gap: 5px;
  }

  .icon-btn {
    background: none;
    border: 1px solid #eee;
    padding: 4px;
    border-radius: 4px;
    cursor: pointer;
    color: #95a5a6;
    transition: all 0.2s;
  }

  .icon-btn.edit:hover {
    color: #3498db;
    border-color: #3498db;
    background: rgba(52, 152, 219, 0.1);
  }

  .icon-btn.delete:hover {
    color: #e74c3c;
    border-color: #e74c3c;
    background: rgba(231, 76, 60, 0.1);
  }

  .spin {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
</style>