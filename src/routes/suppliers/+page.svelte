<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations } from '$lib/i18n';
  import { Plus, MapPin, Phone, Hash, Edit2, Trash2 } from 'lucide-svelte';

  const t = $derived(translations[$language]);

  let suppliers = $state<any[]>([]);
  let showEditForm = $state(false);
  let editingSupplier = $state<any>(null);
  
  let newSupplier = $state({
    name: '',
    address: '',
    city: '',
    state_name: 'Gujarat',
    state_code: '24',
    mobile: '',
    gst_number: '',
    partner_name: '', // Added partner name
    partner_mobile: '' // Added partner mobile
  });

  onMount(async () => {
    await fetchSuppliers();
  });

  async function fetchSuppliers() {
    try {
      // Explicitly select partner_name and partner_mobile
      const { data, error } = await supabase.from('suppliers').select('*, partner_name, partner_mobile').order('name');
      if (error) {
        console.error('Error fetching suppliers:', error.message);
        alert('Failed to fetch suppliers. Please try again. Error: ' + error.message);
        suppliers = []; // Ensure suppliers is reset on error
        return;
      }
      suppliers = data || [];
    } catch (e) {
      console.error('An unexpected error occurred:', e);
      alert('An unexpected error occurred while fetching suppliers.');
      suppliers = []; // Ensure suppliers is reset on error
    }
  }

  async function handleAddSupplier() {
    if (!newSupplier.name) {
      alert('Please enter supplier name');
      return;
    }
    const { error } = await supabase.from('suppliers').insert(newSupplier);
    if (!error) {
      newSupplier = { 
        name: '', 
        address: '', 
        city: '',
        state_name: 'Gujarat',
        state_code: '24',
        mobile: '', 
        gst_number: '',
        partner_name: '', // Reset new field
        partner_mobile: '' // Reset new field
      };
      await fetchSuppliers();
      alert('Supplier added successfully!');
    } else {
      alert('Error adding supplier: ' + error.message);
    }
  }

  async function deleteSupplier(id: string) {
    if (confirm('Delete this supplier?')) {
      const { error } = await supabase.from('suppliers').delete().eq('id', id);
      if (!error) await fetchSuppliers();
    }
  }

  function openEditForm(supplier: any) {
    editingSupplier = { ...supplier };
    showEditForm = true;
  }

  async function handleUpdateSupplier() {
    if (!editingSupplier) return;
    
    const { error } = await supabase
      .from('suppliers')
      .update({
        name: editingSupplier.name,
        address: editingSupplier.address,
        city: editingSupplier.city,
        state_name: editingSupplier.state_name,
        state_code: editingSupplier.state_code,
        mobile: editingSupplier.mobile,
        gst_number: editingSupplier.gst_number,
        partner_name: editingSupplier.partner_name,
        partner_mobile: editingSupplier.partner_mobile
      })
      .eq('id', editingSupplier.id);

    if (!error) {
      showEditForm = false;
      editingSupplier = null;
      await fetchSuppliers();
      alert('Supplier updated successfully!');
    } else {
      alert('Error updating supplier: ' + error.message);
    }
  }
</script>

<div class="suppliers-container">
  <h2>{t.suppliers}</h2>

  <div class="supplier-form-card">
    <h3>Add New Supplier</h3>
    <div class="form-grid">
      <div class="input-group full-width">
        <label>Supplier Name / Company Name</label>
        <input type="text" bind:value={newSupplier.name} placeholder="Full Name" />
      </div>

      <div class="input-group full-width">
        <label>Full Address</label>
        <textarea bind:value={newSupplier.address} placeholder="Street Address"></textarea>
      </div>

      <div class="input-group">
        <label>City</label>
        <input type="text" bind:value={newSupplier.city} placeholder="City Name" />
      </div>

      <div class="input-group">
        <label>Mobile Number</label>
        <input type="text" bind:value={newSupplier.mobile} placeholder="10-digit mobile" />
      </div>

      <div class="input-group">
        <label>{t.gst_no}</label>
        <input type="text" bind:value={newSupplier.gst_number} placeholder="24XXXXX..." />
      </div>

      <div class="input-group">
        <label>State Name</label>
        <input type="text" bind:value={newSupplier.state_name} placeholder="Gujarat" />
      </div>

      <!-- New fields for partner details -->
      <div class="input-group">
        <label>Partner Name</label>
        <input type="text" bind:value={newSupplier.partner_name} placeholder="Partner's Name" />
      </div>

      <div class="input-group">
        <label>Partner Mobile</label>
        <input type="text" bind:value={newSupplier.partner_mobile} placeholder="Partner's Mobile" />
      </div>
    </div>
    <button class="add-btn" onclick={handleAddSupplier}>
      <Plus size={18} /> Add Supplier
    </button>
  </div>

  <div class="suppliers-list">
    <h3>Supplier Directory</h3>
    <div class="list-grid">
      {#each suppliers as supplier}
        <div class="supplier-card">
          <h4>{supplier.name}</h4>
          {#if supplier.address}
            <p class="address"><MapPin size={14} /> {supplier.address}, {supplier.city}</p>
          {/if}
          <div class="meta-row">
            <p><Phone size={14} /> {supplier.mobile || 'N/A'}</p>
            <p><Hash size={14} /> GST: {supplier.gst_number || 'N/A'}</p>
          </div>
          <!-- Display new partner details -->
          {#if supplier.partner_name}
            <p>Partner: {supplier.partner_name}</p>
          {/if}
          {#if supplier.partner_mobile}
            <p>Partner Mobile: {supplier.partner_mobile}</p>
          {/if}

          <button class="edit-btn" onclick={() => openEditForm(supplier)}><Edit2 size={14} /> Edit</button>
          <button class="delete-btn" onclick={() => deleteSupplier(supplier.id)}><Trash2 size={14} /> Delete</button>
        </div>
      {/each}
    </div>
  </div>

  <!-- Edit Form -->
  {#if showEditForm && editingSupplier}
    <div class="edit-form-overlay">
      <div class="edit-form-card">
        <h3>Edit Supplier</h3>
        <div class="form-grid">
          <div class="input-group full-width">
            <label>Supplier Name</label>
            <input type="text" bind:value={editingSupplier.name} />
          </div>
          <div class="input-group full-width">
            <label>Address</label>
            <textarea bind:value={editingSupplier.address}></textarea>
          </div>
          <div class="input-group">
            <label>City</label>
            <input type="text" bind:value={editingSupplier.city} />
          </div>
          <div class="input-group">
            <label>Mobile</label>
            <input type="text" bind:value={editingSupplier.mobile} />
          </div>
          <div class="input-group">
            <label>GST Number</label>
            <input type="text" bind:value={editingSupplier.gst_number} />
          </div>
          <div class="input-group">
            <label>State Name</label>
            <input type="text" bind:value={editingSupplier.state_name} />
          </div>
          <div class="input-group">
            <label>Partner Name</label>
            <input type="text" bind:value={editingSupplier.partner_name} />
          </div>
          <div class="input-group">
            <label>Partner Mobile</label>
            <input type="text" bind:value={editingSupplier.partner_mobile} />
          </div>
        </div>
        <div class="form-actions">
          <button class="save-btn" onclick={handleUpdateSupplier}>Save Changes</button>
          <button class="cancel-btn" onclick={() => { showEditForm = false; editingSupplier = null; }}>Cancel</button>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .suppliers-container h2 {
    margin-bottom: 30px;
    color: #2c3e50;
  }

  .supplier-form-card {
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
    height: 60px;
    resize: vertical;
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

  .list-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
    gap: 20px;
  }

  .supplier-card {
    background: white;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    border-left: 4px solid #e67e22;
    position: relative;
  }

  .supplier-card h4 {
    margin: 0 0 10px 0;
    color: #2c3e50;
    border-bottom: 1px solid #eee;
    padding-bottom: 5px;
  }

  .supplier-card p {
    margin: 5px 0;
    font-size: 0.9rem;
    color: #7f8c8d;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .meta-row {
    display: flex;
    flex-direction: column;
    gap: 5px;
    margin-top: 10px;
  }

  .delete-btn {
    position: absolute;
    top: 10px;
    right: 10px;
    background: none;
    border: 1px solid #e74c3c;
    color: #e74c3c;
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 0.7rem;
    cursor: pointer;
  }

  .delete-btn:hover {
    background: #e74c3c;
    color: white;
  }

  .edit-btn {
    position: absolute;
    top: 10px;
    right: 70px;
    background: none;
    border: 1px solid #3498db;
    color: #3498db;
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 0.7rem;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .edit-btn:hover {
    background: #3498db;
    color: white;
  }

  .supplier-card {
    position: relative;
  }

  .edit-form-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0,0,0,0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }

  .edit-form-card {
    background: white;
    padding: 30px;
    border-radius: 12px;
    width: 90%;
    max-width: 600px;
    max-height: 90vh;
    overflow-y: auto;
  }

  .edit-form-card h3 {
    margin-top: 0;
    margin-bottom: 20px;
  }

  .form-actions {
    display: flex;
    gap: 10px;
    justify-content: flex-end;
  }

  .save-btn {
    background: #27ae60;
    color: white;
    border: none;
    padding: 10px 20px;
    border-radius: 6px;
    cursor: pointer;
    font-weight: bold;
  }

  .cancel-btn {
    background: #95a5a6;
    color: white;
    border: none;
    padding: 10px 20px;
    border-radius: 6px;
    cursor: pointer;
  }
</style>
