<script lang="ts">
  import { goto } from '$app/navigation';
  import '../app.css';
  import { language, translations, financialYear } from '$lib/i18n';
  import { supabase } from '$lib/supabase';
  import { onMount } from 'svelte';
  import { LayoutDashboard, Package, Factory, ShoppingCart, Wallet, Users, FileText, Settings, LogOut, Truck, Building, Landmark } from 'lucide-svelte';

  let { children } = $props();
  let user = $state<any>(null);

  onMount(async () => {
    const { data } = await supabase.auth.getUser();
    user = data.user;
    
    supabase.auth.onAuthStateChange((_event, session) => {
      user = session?.user ?? null;
    });
  });

  const handleLogout = async () => {
    await supabase.auth.signOut();
    goto('/login');
  };

  const setLanguage = (lang: 'en' | 'gu') => {
    $language = lang;
  };

  const t = $derived(translations[$language]);

  const financialYears = (() => {
    const years = [];
    const baseYear = 2024; // Starting from 2024-25
    for (let i = 0; i < 50; i++) {
      const start = baseYear + i;
      const end = (start + 1).toString().slice(-2);
      years.push(`${start}-${end}`);
    }
    return years;
  })();
</script>

<div class="app-container">
  {#if user}
    <nav class="sidebar">
      <div class="logo">
        <h1>Mahadev Oil Mill</h1>
      </div>
      <ul class="nav-links">
        <li><a href="/dashboard"><LayoutDashboard size={20} /> {t.dashboard}</a></li>
        <li><a href="/inventory"><Package size={20} /> {t.inventory}</a></li>
        <li><a href="/production"><Factory size={20} /> {t.production}</a></li>
        <li><a href="/purchases"><Truck size={20} /> {t.purchases}</a></li>
        <li><a href="/sales"><ShoppingCart size={20} /> {t.sales}</a></li>
        <li><a href="/expenses"><Wallet size={20} /> {t.expenses}</a></li>
        <li><a href="/customers"><Users size={20} /> {t.customers}</a></li>
        <li><a href="/suppliers"><Building size={20} /> {t.suppliers}</a></li>
        <li><a href="/banking"><Landmark size={20} /> {t.banking}</a></li>
        <li><a href="/reports"><FileText size={20} /> {t.reports}</a></li>
        <li><a href="/settings"><Settings size={20} /> {t.settings}</a></li>
      </ul>
      <div class="sidebar-footer">
        <button onclick={handleLogout} class="logout-btn">
          <LogOut size={20} /> {t.logout}
        </button>
      </div>
    </nav>
  {/if}

  <main class="main-content {user ? 'with-sidebar' : ''}">
    <header class="top-header">
      <div class="header-left">
        {#if user}
          <div class="fy-selector">
            <label for="fy">FY:</label>
            <select id="fy" bind:value={$financialYear}>
              {#each financialYears as fy}
                <option value={fy}>{fy}</option>
              {/each}
            </select>
          </div>
        {/if}
        <div class="lang-switch">
          <button class:active={$language === 'en'} onclick={() => setLanguage('en')}>EN</button>
          <button class:active={$language === 'gu'} onclick={() => setLanguage('gu')}>ગુ</button>
        </div>
      </div>
      {#if user}
        <div class="user-info">
          <span>{user.email}</span>
          <button onclick={handleLogout} class="header-logout" title={t.logout}>
            <LogOut size={18} />
          </button>
        </div>
      {/if}
    </header>

    <div class="page-content">
      {@render children()}
    </div>
  </main>
</div>

<style>
  :global(body) {
    margin: 0;
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    background-color: #f4f7f6;
    color: #333;
  }

  .app-container {
    display: flex;
    min-height: 100vh;
  }

  .sidebar {
    width: 250px;
    background-color: #2c3e50;
    color: white;
    display: flex;
    flex-direction: column;
    position: fixed;
    height: 100vh;
    z-index: 100;
  }

  .logo {
    padding: 20px;
    text-align: center;
    border-bottom: 1px solid #34495e;
  }

  .logo h1 {
    font-size: 1.2rem;
    margin: 0;
    color: #3498db;
  }

  .nav-links {
            list-style: none;
            padding: 0;
            margin: 20px 0;
            flex-grow: 1;
            height: calc(100vh - 130px); /* Add scrollable height */
            overflow-y: auto; /* Add scrollbar */
          }
  .nav-links li a {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 15px 20px;
            color: #3498db; /* Changed to blue */
            text-decoration: none;
            transition: all 0.3s;
          }

  .nav-links li a:hover {
    background-color: #34495e;
    color: white;
  }

  .sidebar-footer {
    padding: 20px;
    border-top: 1px solid #34495e;
  }

  .logout-btn {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px;
    background: none;
    border: 1px solid #e74c3c;
    color: #e74c3c;
    cursor: pointer;
    border-radius: 4px;
    transition: all 0.3s;
  }

  .logout-btn:hover {
    background-color: #e74c3c;
    color: white;
  }

  .main-content {
    flex-grow: 1;
    display: flex;
    flex-direction: column;
  }

  .main-content.with-sidebar {
    margin-left: 250px;
  }

  .top-header {
    height: 60px;
    background-color: white;
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0 30px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  }

  .header-left {
    display: flex;
    align-items: center;
    gap: 20px;
  }

  .fy-selector {
    display: flex;
    align-items: center;
    gap: 8px;
    background: #f8f9fa;
    padding: 5px 10px;
    border-radius: 4px;
    border: 1px solid #ddd;
  }

  .fy-selector label {
    font-size: 0.8rem;
    font-weight: bold;
    color: #7f8c8d;
  }

  .fy-selector select {
    border: none;
    background: transparent;
    font-weight: bold;
    color: #2c3e50;
    cursor: pointer;
    outline: none;
  }

  .lang-switch {
    display: flex;
    gap: 5px;
  }

  .lang-switch button {
    padding: 5px 10px;
    border: 1px solid #ddd;
    background: white;
    cursor: pointer;
    border-radius: 4px;
  }

  .lang-switch button.active {
    background-color: #3498db;
    color: white;
    border-color: #3498db;
  }

  .user-info {
    display: flex;
    align-items: center;
    gap: 15px;
  }

  .header-logout {
    background: none;
    border: 1px solid #e74c3c;
    color: #e74c3c;
    padding: 5px;
    border-radius: 4px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.3s;
  }

  .header-logout:hover {
    background-color: #e74c3c;
    color: white;
  }

  .page-content {
    padding: 30px;
  }

  @media (max-width: 768px) {
    .sidebar {
      width: 60px;
    }
    .sidebar .logo h1, .sidebar .nav-links span, .logout-btn span {
      display: none;
    }
    .main-content.with-sidebar {
      margin-left: 60px;
    }
  }
</style>
