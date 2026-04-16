<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations } from '$lib/i18n';
  import { Chart, registerables } from 'chart.js';
  import { Wallet, Package, ShoppingCart, TrendingUp } from 'lucide-svelte';

  Chart.register(...registerables);

  let stats = $state({
    totalSales: 0,
    totalPurchases: 0,
    totalStock: 0,
    totalExpenses: 0,
    netProfit: 0,
    totalCustomers: 0
  });

  let topCustomers = $state<any[]>([]);
  let chartCanvas = $state<HTMLCanvasElement | null>(null);
  let chart: Chart | null = null;
  const t = $derived(translations[$language]);

  onMount(async () => {
    await fetchStats();
  });

  async function fetchStats() {
    // Fetch sales with customer info
    const { data: sales } = await supabase
      .from('sales')
      .select('total_amount, sales_date, customers:customer_id(name)');
    
    // Fetch inventory
    const { data: inventory } = await supabase.from('inventory').select('quantity');
    
    // Fetch expenses
    const { data: expenses } = await supabase.from('expenses').select('amount, total_with_gst');

    // Fetch purchases
    const { data: purchases } = await supabase.from('purchases').select('total_amount');

    // Fetch total customer count
    const { count: customerCount } = await supabase.from('customers').select('*', { count: 'exact', head: true });

    const totalSales = (sales || []).reduce((acc, curr) => acc + (Number(curr.total_amount) || 0), 0);
    const totalPurchases = (purchases || []).reduce((acc, curr) => acc + (Number(curr.total_amount) || 0), 0);
    const totalStock = (inventory || []).reduce((acc, curr) => acc + (Number(curr.quantity) || 0), 0);
    const totalExpenses = (expenses || []).reduce((acc, curr) => acc + (Number(curr.total_with_gst) || Number(curr.amount) || 0), 0);

    stats = {
      totalSales,
      totalPurchases,
      totalStock,
      totalExpenses,
      netProfit: totalSales - totalExpenses - totalPurchases,
      totalCustomers: customerCount || 0
    };

    // Calculate Top Customers
    const customerMap: { [key: string]: number } = {};
    (sales || []).forEach(sale => {
      const name = sale.customers?.name || 'Walk-in Customer';
      customerMap[name] = (customerMap[name] || 0) + (Number(sale.total_amount) || 0);
    });

    topCustomers = Object.entries(customerMap)
      .map(([name, total]) => ({ name, total }))
      .sort((a, b) => b.total - a.total)
      .slice(0, 5);

    if (chartCanvas && sales) {
      updateChart(sales);
    }
  }

  function updateChart(salesData: any[]) {
    // Group sales by month for the chart
    const monthlySales: { [key: string]: number } = {};
    const last6Months = [];
    
    for (let i = 5; i >= 0; i--) {
      const d = new Date();
      d.setMonth(d.getMonth() - i);
      const monthYear = d.toLocaleString('default', { month: 'short' });
      last6Months.push(monthYear);
      monthlySales[monthYear] = 0;
    }

    salesData.forEach(sale => {
      const saleDate = new Date(sale.sales_date);
      const monthYear = saleDate.toLocaleString('default', { month: 'short' });
      if (monthlySales[monthYear] !== undefined) {
        monthlySales[monthYear] += Number(sale.total_amount) || 0;
      }
    });

    if (chart) chart.destroy();

    if (chartCanvas) {
      chart = new Chart(chartCanvas, {
        type: 'line',
        data: {
          labels: last6Months,
          datasets: [{
            label: t.total_sales + ' (₹)',
            data: last6Months.map(m => monthlySales[m]),
            borderColor: '#3498db',
            backgroundColor: 'rgba(52, 152, 219, 0.1)',
            fill: true,
            tension: 0.3
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              display: true,
              position: 'top'
            }
          },
          scales: {
            y: {
              beginAtZero: true,
              ticks: {
                callback: (value) => '₹' + value.toLocaleString()
              }
            }
          }
        }
      });
    }
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

    <div class="stat-card">
      <div class="stat-icon purchases"><ShoppingCart size={24} /></div>
      <div class="stat-info">
        <h3>{t.total_purchases}</h3>
        <p>₹{stats.totalPurchases.toLocaleString()}</p>
      </div>
    </div>

    <div class="stat-card">
      <div class="stat-icon customers"><Wallet size={24} /></div>
      <div class="stat-info">
        <h3>{t.customers}</h3>
        <p>{stats.totalCustomers}</p>
      </div>
    </div>
  </div>

  <div class="dashboard-grid">
    <div class="chart-container">
      <h3>Sales Trend</h3>
      <div class="canvas-wrapper">
        <canvas bind:this={chartCanvas}></canvas>
      </div>
    </div>

    <div class="top-customers-container">
      <h3>Top Customers</h3>
      <div class="customer-list">
        {#each topCustomers as customer}
          <div class="customer-item">
            <span class="customer-name">{customer.name}</span>
            <span class="customer-total">₹{customer.total.toLocaleString()}</span>
          </div>
        {:else}
          <p class="no-data">No sales data yet</p>
        {/each}
      </div>
    </div>
  </div>
</div>

<style>
  .dashboard-container h2 {
    margin-bottom: 30px;
    color: #2c3e50;
  }

  .stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
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
  .stat-icon.purchases { background-color: #e67e22; }
  .stat-icon.customers { background-color: #9b59b6; }

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

  .dashboard-grid {
    display: grid;
    grid-template-columns: 2fr 1fr;
    gap: 30px;
  }

  @media (max-width: 1024px) {
    .dashboard-grid {
      grid-template-columns: 1fr;
    }
  }

  .chart-container, .top-customers-container {
    background: white;
    padding: 25px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
  }

  .canvas-wrapper {
    height: 300px;
    position: relative;
  }

  h3 {
    margin-top: 0;
    margin-bottom: 20px;
    color: #2c3e50;
    border-bottom: 2px solid #f8f9fa;
    padding-bottom: 10px;
  }

  .customer-list {
    display: flex;
    flex-direction: column;
    gap: 15px;
  }

  .customer-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px;
    background: #f8f9fa;
    border-radius: 6px;
    transition: transform 0.2s;
  }

  .customer-item:hover {
    transform: translateX(5px);
  }

  .customer-name {
    font-weight: 600;
    color: #34495e;
  }

  .customer-total {
    color: #27ae60;
    font-weight: bold;
  }

  .no-data {
    color: #95a5a6;
    text-align: center;
    padding: 20px;
  }
</style>
