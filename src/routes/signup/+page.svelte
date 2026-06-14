<script lang="ts">
  import { supabase } from '$lib/supabase';
  import { language, translations } from '$lib/i18n';
  import { goto } from '$app/navigation';

  let email = $state('');
  let password = $state('');
  let loading = $state(false);
  let error = $state<string | null>(null);
  let message = $state<string | null>(null);

  const t = $derived(translations[$language]);

  const handleSignup = async (e: Event) => {
    e.preventDefault();
    loading = true;
    error = null;
    message = null;

    const { data, error: signupError } = await supabase.auth.signUp({
      email,
      password
    });

    if (signupError) {
      error = signupError.message;
    } else {
      message = 'Signup successful! Please check your email for confirmation.';
    }
    loading = false;
  };
</script>

<div class="signup-container">
  <form class="signup-card" onsubmit={handleSignup}>
    <h2>Sign Up</h2>
    
    {#if error}
      <div class="error-msg">{error}</div>
    {/if}
    
    {#if message}
      <div class="success-msg">{message}</div>
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
      {loading ? '...' : 'Sign Up'}
    </button>
  </form>
</div>

<style>
  .signup-container {
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 70vh;
  }

  .signup-card {
    background: white;
    padding: 40px;
    border-radius: 8px;
    box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    width: 100%;
    max-width: 400px;
  }

  h2 { margin-top: 0; color: #2c3e50; text-align: center; }

  .input-group { margin-bottom: 20px; }

  label { display: block; margin-bottom: 5px; color: #333; }

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
    background-color: #27ae60;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
  }

  .error-msg { background-color: #fdeaea; color: #e74c3c; padding: 10px; border-radius: 4px; margin-bottom: 20px; text-align: center; }
  .success-msg { background-color: #eafaf1; color: #27ae60; padding: 10px; border-radius: 4px; margin-bottom: 20px; text-align: center; }
</style>
