<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations } from '$lib/i18n';
  import { Wallet, Plus, Trash2, CheckCircle, Circle } from 'lucide-svelte';

  const t = $derived(translations[$language]);

  let expenses = $state<any[]>([]);
  let totalExpenses = $derived(expenses.reduce((acc, curr) => acc + (curr.total_with_gst || curr.amount || 0), 0));

  let newExpense = $state({
    description: '',
    amount: 0,
    gst_rate: 0,
    gst_amount: 0,
    total_with_gst: 0,
    category: 'other',
    payment_mode: 'Cash',
    payment_details: '',
    expense_date: new Date().toISOString().split('T')[0]
  });

  $effect(() => {
    newExpense.gst_amount = (newExpense.amount * newExpense.gst_rate) / 100;
    newExpense.total_with_gst = newExpense.amount + newExpense.gst_amount;
  });

  onMount(async () => {
    await fetchExpenses();
  });

  async function fetchExpenses() {
    const { data } = await supabase.from('expenses').select('*').order('expense_date', { ascending: false });
    expenses = data || [];
  }

  async function handleAddExpense() {
    const { error } = await supabase.from('expenses').insert(newExpense);
    if (!error) {
      newExpense = { 
        description: '', 
        amount: 0, 
        gst_rate: 0, 
        gst_amount: 0, 
        total_with_gst: 0,
        category: 'other', 
        payment_mode: 'Cash',
        payment_details: '',
        expense_date: new Date().toISOString().split('T')[0] 
      };
      await fetchExpenses();
    }
  }

  async function deleteExpense(id: string) {
    if (confirm('Delete this expense?')) {
      const { error } = await supabase.from('expenses').delete().eq('id', id);
      if (!error) await fetchExpenses();
    }
  }

  async function toggleExpenseDone(expenseId: string, currentDone: boolean) {
    const { error } = await supabase
      .from('expenses')
      .update({ is_done: !currentDone })
      .eq('id', expenseId);

    if (!error) {
      await fetchExpenses();
    }
  }
</script>

<div class="expenses-container">
  <div class="header">
    <h2>{t.expenses}</h2>
    <div class="total-badge">
      Total: ₹{totalExpenses.toLocaleString()}
    </div>
  </div>

  <div class="expense-form-card">
    <h3>Add Expense</h3>
    <div class="form-grid">
      <div class="input-group">
        <label>Description</label>
        <input type="text" bind:value={newExpense.description} placeholder="e.g. Electricity Bill" />
      </div>

      <div class="input-group">
        <label>Base Amount (₹)</label>
        <input type="number" bind:value={newExpense.amount} min="0" />
      </div>

      <div class="input-group">
        <label>GST Rate (%)</label>
        <select bind:value={newExpense.gst_rate}>
          <option value={0}>0%</option>
          <option value={5}>5%</option>
          <option value={12}>12%</option>
          <option value={18}>18%</option>
          <option value={28}>28%</option>
        </select>
      </div>

      <div class="input-group">
        <label>GST Amount</label>
        <input type="number" value={newExpense.gst_amount} disabled />
      </div>

      <div class="input-group">
        <label>Total with GST</label>
        <input type="number" value={newExpense.total_with_gst} disabled />
      </div>

      <div class="input-group">
        <label>Category</label>
        <select bind:value={newExpense.category}>
          <option value="electricity">{t.electricity}</option>
          <option value="labor">{t.labor}</option>
          <option value="transport">{t.transport}</option>
          <option value="other">{t.other}</option>
        </select>
      </div>

      <div class="input-group">
        <label>Date</label>
        <input type="date" bind:value={newExpense.expense_date} />
      </div>

      <div class="input-group">
        <label>Payment Mode</label>
        <select bind:value={newExpense.payment_mode}>
          <option value="Cash">💵 Cash</option>
          <option value="Bank">🏦 Bank / Online</option>
        </select>
      </div>

      <div class="input-group">
        <label>Payment Details</label>
        <input type="text" bind:value={newExpense.payment_details} placeholder="Ref No / Cheque No" />
      </div>
    </div>
    <button class="add-btn" onclick={handleAddExpense}>
      <Plus size={18} /> Add Expense
    </button>
  </div>

  <div class="expenses-list">
    <h3>Recent Expenses</h3>
    <table>
      <thead>
        <tr>
          <th>Date</th>
          <th>Description</th>
          <th>Category</th>
          <th>Mode</th>
          <th>Total</th>
          <th>Status</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        {#each expenses as expense}
          <tr class={expense.is_done ? 'done' : ''}>
            <td>{new Date(expense.expense_date).toLocaleDateString()}</td>
            <td>{expense.description}</td>
            <td><span class="category-tag {expense.category}">{expense.category}</span></td>
            <td>
              <span class="mode-tag {expense.payment_mode?.toLowerCase()}">
                {expense.payment_mode === 'Cash' ? '💵' : '🏦'} {expense.payment_mode}
              </span>
            </td>
            <td><strong>₹{(expense.total_with_gst || expense.amount || 0).toLocaleString()}</strong></td>
            <td class="status-cell">
              <button 
                class="done-btn"
                onclick={() => toggleExpenseDone(expense.id, expense.is_done)}
                title={expense.is_done ? 'Mark as pending' : 'Mark as paid'}
              >
                {#if expense.is_done}
                  <CheckCircle size={18} />
                {:else}
                  <Circle size={18} />
                {/if}
              </button>
            </td>
            <td>
              <button onclick={() => deleteExpense(expense.id)} class="delete-btn">
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
  .expenses-container .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 30px;
  }

  .total-badge {
    background-color: #e74c3c;
    color: white;
    padding: 10px 20px;
    border-radius: 8px;
    font-weight: bold;
    font-size: 1.1rem;
  }

  .expense-form-card {
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

  .input-group label {
    display: block;
    margin-bottom: 5px;
    font-size: 0.9rem;
    color: #666;
  }

  .input-group input, .input-group select {
    width: 100%;
    padding: 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
  }

  .add-btn {
    background-color: #e74c3c;
    color: white;
    border: none;
    padding: 12px 24px;
    border-radius: 4px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .expenses-list {
    background: white;
    padding: 25px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
  }

  table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 15px;
  }

  th, td {
    padding: 12px;
    text-align: left;
    border-bottom: 1px solid #eee;
  }

  .category-tag {
    padding: 4px 8px;
    border-radius: 4px;
    font-size: 0.8rem;
    text-transform: capitalize;
  }

  .category-tag.electricity { background: #fff3cd; color: #856404; }
  .category-tag.labor { background: #d4edda; color: #155724; }
  .category-tag.transport { background: #d1ecf1; color: #0c5460; }
  .category-tag.other { background: #e2e3e5; color: #383d41; }

  .mode-tag {
    padding: 2px 6px;
    border-radius: 4px;
    font-size: 0.8rem;
  }
  .mode-tag.cash { background: #d4edda; color: #155724; }
  .mode-tag.bank { background: #cce5ff; color: #004085; }

  .delete-btn {
    background: none;
    border: none;
    color: #e74c3c;
    cursor: pointer;
    padding: 5px;
  }

  tr.done {
    background-color: #ecf0f1;
    opacity: 0.7;
  }

  tr.done td {
    text-decoration: line-through;
    color: #95a5a6;
  }

  .status-cell {
    text-align: center;
  }

  .done-btn {
    background: none;
    border: none;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #95a5a6;
    padding: 5px;
    border-radius: 4px;
    transition: all 0.3s ease;
  }

  .done-btn:hover {
    background: rgba(46, 204, 113, 0.1);
    color: #27ae60;
  }

  tr.done .done-btn {
    color: #27ae60;
  }

  tr.done .done-btn:hover {
    color: #229954;
  }
</style>
