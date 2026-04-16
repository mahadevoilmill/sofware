<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations } from '$lib/i18n';
  import { Users, Plus, Phone, Hash } from 'lucide-svelte';

  const t = $derived(translations[$language]);

  let customers = $state<any[]>([]);
  let newCustomer = $state({
    name: '',
    address: '',
    mobile: '',
    gst_number: '',
    state_name: 'Gujarat',
    state_code: '24'
  });

  onMount(async () => {
    await fetchCustomers();
  });

  async function fetchCustomers() {
    const { data } = await supabase.from('customers').select('*').order('name');
    customers = data || [];
  }

  async function handleAddCustomer() {
    const { error } = await supabase.from('customers').insert(newCustomer);
    if (!error) {
      newCustomer = { 
        name: '', 
        address: '', 
        mobile: '', 
        gst_number: '',
        state_name: 'Gujarat',
        state_code: '24'
      };
      await fetchCustomers();
    }
  }
</script>

<div class="customers-container">
  <h2>{t.customers}</h2>

  <div class="customer-form-card">
    <h3>Add New Customer (Billing Details)</h3>
    <div class="form-grid">
      <div class="input-group full-width">
        <label>{t.customer_name} (Buyer Name)</label>
        <input type="text" bind:value={newCustomer.name} placeholder="Full Name / Company Name" />
      </div>

      <div class="input-group full-width">
        <label>Billing Address</label>
        <textarea bind:value={newCustomer.address} placeholder="Complete Street Address, City, Pincode"></textarea>
      </div>

      <div class="input-group">
        <label>Mobile Number</label>
        <input type="text" bind:value={newCustomer.mobile} placeholder="10-digit mobile" />
      </div>

      <div class="input-group">
        <label>{t.gst_no}</label>
        <input type="text" bind:value={newCustomer.gst_number} placeholder="24XXXXX..." />
      </div>

      <div class="input-group">
        <label>State Name</label>
        <input type="text" bind:value={newCustomer.state_name} placeholder="e.g. Gujarat" />
      </div>

      <div class="input-group">
        <label>State Code</label>
        <input type="text" bind:value={newCustomer.state_code} placeholder="e.g. 24" />
      </div>
    </div>
    <button class="add-btn" onclick={handleAddCustomer}>
      <Plus size={18} /> Add Customer
    </button>
  </div>

  <div class="customers-list">
    <h3>Customer Directory</h3>
    <div class="list-grid">
      {#each customers as customer}
        <div class="customer-card">
          <h4>{customer.name}</h4>
          {#if customer.address}
            <p class="address">{customer.address}</p>
          {/if}
          <div class="customer-meta">
            <p><Phone size={14} /> {customer.mobile || 'N/A'}</p>
            <p><Hash size={14} /> GST: {customer.gst_number || 'N/A'}</p>
            <p><strong>State:</strong> {customer.state_name} ({customer.state_code})</p>
          </div>
        </div>
      {/each}
    </div>
  </div>
</div>

<style>
  .customers-container h2 {
    margin-bottom: 30px;
    color: #2c3e50;
  }

  .customer-form-card {
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
    color: #666;
    font-weight: 600;
  }

  .input-group input, .input-group textarea {
    width: 100%;
    padding: 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-family: inherit;
  }

  .input-group textarea {
    height: 80px;
    resize: vertical;
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
    font-weight: 600;
  }

  .list-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 20px;
  }

  .customer-card {
    background: white;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    border-left: 4px solid #3498db;
  }

  .customer-card h4 {
    margin: 0 0 10px 0;
    color: #2c3e50;
    border-bottom: 1px solid #eee;
    padding-bottom: 5px;
  }

  .customer-meta {
    display: flex;
    flex-direction: column;
    gap: 5px;
  }

  .customer-card p {
    margin: 0;
    font-size: 0.9rem;
    color: #7f8c8d;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .customer-card p.address {
    font-size: 0.85rem;
    color: #95a5a6;
    margin-bottom: 10px;
    display: block;
    font-style: italic;
  }
</style>
