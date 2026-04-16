<script lang="ts">
  import '../app.css';
  import { language, translations } from '$lib/i18n';
  import { supabase } from '$lib/supabase';
  import { onMount } from 'svelte';
  import { LayoutDashboard, Package, Factory, ShoppingCart, Wallet, Users, FileText, Settings, LogOut, Truck, Building } from 'lucide-svelte';

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
  };

  const setLanguage = (lang: 'en' | 'gu') => {
    $language = lang;
  };

  const t = $derived(translations[$language]);
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
      <div class="lang-switch">
        <button class:active={$language === 'en'} onclick={() => setLanguage('en')}>EN</button>
        <button class:active={$language === 'gu'} onclick={() => setLanguage('gu')}>ગુ</button>
      </div>
      {#if user}
        <div class="user-info">
          <span>{user.email}</span>
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
  }

  .nav-links li a {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 15px 20px;
    color: #bdc3c7;
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
