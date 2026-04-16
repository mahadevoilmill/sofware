<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations } from '$lib/i18n';
  import { Save, RefreshCw } from 'lucide-svelte';

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
    branch_ifsc: ''
  });

  onMount(async () => {
    await fetchSettings();
  });

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
        settings = { ...data };
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
      let result;
      if (settings.id) {
        // Update
        result = await supabase
          .from('company_settings')
          .update(settings)
          .eq('id', settings.id);
      } else {
        // Insert
        const { id, ...newData } = settings;
        result = await supabase
          .from('company_settings')
          .insert(newData)
          .select()
          .single();
        if (result.data) settings.id = result.data.id;
      }

      if (result.error) throw result.error;
      success = true;
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

  .spin {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
</style>
