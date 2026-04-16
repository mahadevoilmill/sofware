<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { goto } from '$app/navigation';

  onMount(async () => {
    if (!supabase) {
      console.error('Supabase client not initialized. Check your environment variables.');
      goto('/login');
      return;
    }
    try {
      const { data } = await supabase.auth.getUser();
      if (data.user) {
        goto('/dashboard');
      } else {
        goto('/login');
      }
    } catch (error) {
      console.error('Auth error:', error);
      goto('/login');
    }
  });
</script>

<div class="loading">
  <p>Loading Mahadev Oil Mill ERP...</p>
</div>

<style>
  .loading {
    display: flex;
    justify-content: center;
    align-items: center;
    height: 80vh;
    font-size: 1.2rem;
    color: #666;
  }
</style>
