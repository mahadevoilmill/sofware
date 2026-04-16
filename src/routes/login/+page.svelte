<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations } from '$lib/i18n';
  import { goto } from '$app/navigation';

  let email = $state('');
  let password = $state('');
  let loading = $state(false);
  let error = $state<string | null>(null);

  onMount(async () => {
    const { data } = await supabase.auth.getUser();
    if (data.user) {
      goto('/dashboard');
    }
  });

  const t = $derived(translations[$language]);

  const handleLogin = async (e: Event) => {
    e.preventDefault();
    loading = true;
    error = null;

    const { error: loginError } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (loginError) {
      error = loginError.message;
      loading = false;
    } else {
      goto('/dashboard');
    }
  };
</script>

<div class="login-container">
  <form class="login-card" onsubmit={handleLogin}>
    <h2>Mahadev Oil Mill</h2>
    <p>{t.login}</p>
    
    {#if error}
      <div class="error-msg">{error}</div>
    {/if}

    <div class="input-group">
      <label for="email">Email</label>
      <input type="email" id="email" bind:value={email} required />
    </div>

    <div class="input-group">
      <label for="password">Password</label>
      <input type="password" id="password" bind:value={password} required />
    </div>

    <button type="submit" disabled={loading}>
      {loading ? '...' : t.login}
    </button>
  </form>
</div>

<style>
  .login-container {
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 70vh;
  }

  .login-card {
    background: white;
    padding: 40px;
    border-radius: 8px;
    box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    width: 100%;
    max-width: 400px;
  }

  h2 {
    margin-top: 0;
    color: #2c3e50;
    text-align: center;
  }

  p {
    text-align: center;
    color: #666;
    margin-bottom: 30px;
  }

  .input-group {
    margin-bottom: 20px;
  }

  label {
    display: block;
    margin-bottom: 5px;
    color: #333;
  }

  input {
    width: 100%;
    padding: 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
    box-sizing: border-box;
  }

  button {
    width: 100%;
    padding: 12px;
    background-color: #3498db;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 1rem;
    transition: background 0.3s;
  }

  button:hover {
    background-color: #2980b9;
  }

  button:disabled {
    background-color: #bdc3c7;
    cursor: not-allowed;
  }

  .error-msg {
    background-color: #fdeaea;
    color: #e74c3c;
    padding: 10px;
    border-radius: 4px;
    margin-bottom: 20px;
    text-align: center;
    font-size: 0.9rem;
  }
</style>
