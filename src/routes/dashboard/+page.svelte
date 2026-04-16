<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations } from '$lib/i18n';
  import { Chart, registerables } from 'chart.js';
  import { Wallet, Package, ShoppingCart, TrendingUp } from 'lucide-svelte';

  Chart.register(...registerables);

  let stats = $state({
    totalSales: 0,
    totalStock: 0,
    totalExpenses: 0,
    netProfit: 0
  });

  let chartCanvas = $state<HTMLCanvasElement | null>(null);
  const t = $derived(translations[$language]);

  onMount(async () => {
    await fetchStats();
    if (chartCanvas) {
      new Chart(chartCanvas, {
        type: 'line',
        data: {
          labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
          datasets: [{
            label: t.total_sales,
            data: [12000, 19000, 3000, 5000, 20000, 30000],
            borderColor: '#3498db',
            tension: 0.1
          }]
        }
      });
    }
  });

  async function fetchStats() {
    // In a real app, these would be complex queries or RPC calls
    const { data: sales } = await supabase.from('sales').select('total_amount');
    const { data: inventory } = await supabase.from('inventory').select('quantity');
    const { data: expenses } = await supabase.from('expenses').select('amount');

    const totalSales = (sales || []).reduce((acc, curr) => acc + (curr.total_amount || 0), 0);
    const totalStock = (inventory || []).reduce((acc, curr) => acc + (curr.quantity || 0), 0);
    const totalExpenses = (expenses || []).reduce((acc, curr) => acc + (curr.amount || 0), 0);

    stats = {
      totalSales,
      totalStock,
      totalExpenses,
      netProfit: totalSales - totalExpenses
    };
  }
</script>

<div class="dashboard-container">
  <h2>{t.dashboard}</h2>

  <div class="stats-grid">
    <div class="stat-card">
      <div class="stat-icon sales"><ShoppingCart size={24} /></div>
      <div class="stat-info">
        <h3>{t.total_sales}</h3>
        <p>₹{stats.totalSales.toLocaleString()}</p>
      </div>
    </div>

    <div class="stat-card">
      <div class="stat-icon stock"><Package size={24} /></div>
      <div class="stat-info">
        <h3>{t.total_stock}</h3>
        <p>{stats.totalStock.toLocaleString()} kg/l</p>
      </div>
    </div>

    <div class="stat-card">
      <div class="stat-icon expenses"><Wallet size={24} /></div>
      <div class="stat-info">
        <h3>{t.total_expenses}</h3>
        <p>₹{stats.totalExpenses.toLocaleString()}</p>
      </div>
    </div>

    <div class="stat-card">
      <div class="stat-icon profit"><TrendingUp size={24} /></div>
      <div class="stat-info">
        <h3>{t.net_profit}</h3>
        <p>₹{stats.netProfit.toLocaleString()}</p>
      </div>
    </div>
  </div>

  <div class="chart-container">
    <h3>Sales Trend</h3>
    <canvas bind:this={chartCanvas}></canvas>
  </div>
</div>

<style>
  .dashboard-container h2 {
    margin-bottom: 30px;
    color: #2c3e50;
  }

  .stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
    gap: 20px;
    margin-bottom: 40px;
  }

  .stat-card {
    background: white;
    padding: 20px;
    border-radius: 8px;
    display: flex;
    align-items: center;
    gap: 20px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
  }

  .stat-icon {
    width: 50px;
    height: 50px;
    border-radius: 12px;
    display: flex;
    justify-content: center;
    align-items: center;
    color: white;
  }

  .stat-icon.sales { background-color: #3498db; }
  .stat-icon.stock { background-color: #2ecc71; }
  .stat-icon.expenses { background-color: #e74c3c; }
  .stat-icon.profit { background-color: #f1c40f; }

  .stat-info h3 {
    margin: 0;
    font-size: 0.9rem;
    color: #7f8c8d;
    text-transform: uppercase;
  }

  .stat-info p {
    margin: 5px 0 0;
    font-size: 1.5rem;
    font-weight: bold;
    color: #2c3e50;
  }

  .chart-container {
    background: white;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
  }

  .chart-container h3 {
    margin-top: 0;
    margin-bottom: 20px;
    color: #2c3e50;
  }
</style>
