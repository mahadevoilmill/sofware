<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations } from '$lib/i18n';
  import { Users, Plus, Phone, Hash, Edit, Trash2 } from 'lucide-svelte';

  const t = $derived(translations[$language]);

  let customers = $state<any[]>([]);
  let showEditForm = $state(false);
  let editingCustomer = $state<any>(null);

  let newCustomer = $state({
    name: '',
    'Billing Address': '',
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
    const name = typeof newCustomer.name === 'string' ? newCustomer.name.trim() : '';
    const billingAddress = typeof newCustomer['Billing Address'] === 'string' ? newCustomer['Billing Address'].trim() : '';
    const mobile = typeof newCustomer.mobile === 'string' ? newCustomer.mobile.trim() : '';

    if (!name || !billingAddress || !mobile) {
        alert('Please fill in Name, Billing Address, and Mobile Number.');
        return;
    }

    const customerToInsert = {
        name: name.toUpperCase(),
        "Billing Address": billingAddress.toUpperCase(),
        mobile: mobile,
        gst_number: newCustomer.gst_number?.toUpperCase() || ''
    };

    const { error } = await supabase.from('customers').insert(customerToInsert);
    if (!error) {
      newCustomer = { 
        name: '', 
        'Billing Address': '',
        mobile: '', 
        gst_number: '',
        state_name: 'Gujarat',
        state_code: '24'
      };
      await fetchCustomers();
      alert('Customer added successfully!');
    } else {
      // Log or display the error to the user
      console.error('Error adding customer:', error);
      alert(`Failed to add customer. Please try again. Error: ${error.message}`);
    }
  }

  async function openEditForm(customer: any) {
    editingCustomer = { ...customer };
    showEditForm = true;
  }

  async function handleUpdateCustomer() {
    if (!editingCustomer) return;
    const { id, ...updateData } = editingCustomer;
    const formattedUpdateData = {
        ...updateData,
        name: updateData.name?.toUpperCase(),
        "Billing Address": updateData["Billing Address"]?.toUpperCase(),
        gst_number: updateData.gst_number?.toUpperCase(),
        state_name: updateData.state_name?.toUpperCase()
    };
    const { error } = await supabase.from('customers').update(formattedUpdateData).eq('id', id);
    if (!error) {
      showEditForm = false;
      editingCustomer = null;
      await fetchCustomers();
      alert('Customer updated successfully!');
    }
  }

  async function deleteCustomer(id: string) {
    if (confirm('Delete this customer?')) {
      const { error } = await supabase.from('customers').delete().eq('id', id);
      if (!error) {
        await fetchCustomers();
        alert('Customer deleted!');
      }
    }
  }
</script>

<div class="customers-container">
  <h2>{t.customers}</h2>

  {#if showEditForm && editingCustomer}
    <div class="edit-form-card">
      <div class="form-header">
        <h3>Edit Customer: {editingCustomer.name}</h3>
        <button class="close-btn" onclick={() => { showEditForm = false; editingCustomer = null; }}>✕</button>
      </div>
      <div class="form-grid">
        <div class="input-group full-width">
          <label>Buyer Name</label>
          <input type="text" bind:value={editingCustomer.name} />
        </div>
        <div class="input-group full-width">
          <label>Billing Address</label>
          <textarea bind:value={editingCustomer['Billing Address']}></textarea>        </div>
        <div class="input-group">
          <label>Mobile Number</label>
          <input type="text" bind:value={editingCustomer.mobile} />
        </div>
        <div class="input-group">
          <label>GST Number</label>
          <input type="text" bind:value={editingCustomer.gst_number} />
        </div>
        <div class="input-group">
          <label>State Name</label>
          <input type="text" bind:value={editingCustomer.state_name} />
        </div>
        <div class="input-group">
          <label>State Code</label>
          <input type="text" bind:value={editingCustomer.state_code} />
        </div>
      </div>
      <div class="form-actions">
        <button class="btn-submit" onclick={handleUpdateCustomer}>Update Customer</button>
        <button class="btn-cancel" onclick={() => { showEditForm = false; editingCustomer = null; }}>Cancel</button>
      </div>
    </div>
  {/if}

  <div class="customer-form-card">
    <h3>Add New Customer (Billing Details)</h3>
    <div class="form-grid">
      <div class="input-group full-width">
        <label>{t.customer_name} (Buyer Name)</label>
        <input type="text" bind:value={newCustomer.name} placeholder="Full Name / Company Name" />
      </div>

      <div class="input-group full-width">
        <label>Billing Address</label>
        <textarea bind:value={newCustomer['Billing Address']} placeholder="Complete Street Address, City, Pincode"></textarea>
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
    <table class="customer-table">
      <thead>
        <tr>
          <th>Sr. No.</th>
          <th>Name</th>
          <th>Address</th>
          <th>Mobile</th>
          <th>GST Number</th>
          <th>State</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        {#each customers as customer, i}
          <tr>
            <td>{i + 1}</td>
            <td>{customer.name}</td>
            <td>{customer['Billing Address'] || 'N/A'}</td>
            <td>{customer.mobile || 'N/A'}</td>
            <td>{customer.gst_number || 'N/A'}</td>
            <td>{customer.state_name || ''} ({customer.state_code || ''})</td>
            <td>
              <div class="card-actions">
                <button class="icon-btn edit" onclick={() => openEditForm(customer)} title="Edit">
                  <Edit size={16} />
                </button>
                <button class="icon-btn delete" onclick={() => deleteCustomer(customer.id)} title="Delete">
                  <Trash2 size={16} />
                </button>
              </div>
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
</div>

<style>
  .customers-container h2 {
    margin-bottom: 30px;
    color: #2c3e50;
  }

  .customer-form-card, .edit-form-card {
    background: white;
    padding: 25px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    margin-bottom: 30px;
  }

  .edit-form-card {
    border: 2px solid #3498db;
  }

  .form-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
    border-bottom: 1px solid #eee;
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

  .add-btn, .btn-submit {
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

  .btn-submit {
    background-color: #27ae60;
  }

  .form-actions {
    display: flex;
    gap: 10px;
  }

  .btn-cancel {
    background-color: #bdc3c7;
    color: white;
    border: none;
    padding: 12px 24px;
    border-radius: 4px;
    cursor: pointer;
    font-weight: 600;
  }

  .customer-table {
    width: 100%;
    border-collapse: collapse;
    background: white;
    border-radius: 8px;
    overflow: hidden;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
  }

  .customer-table th, .customer-table td {
    padding: 12px 15px;
    text-align: left;
    border-bottom: 1px solid #eee;
  }

  .customer-table th {
    background-color: #f8f9fa;
    color: #2c3e50;
    font-weight: 600;
  }

  .customer-table tr:hover {
    background-color: #f1f7fb;
  }

  .card-actions {
    display: flex;
    gap: 5px;
  }
</style>