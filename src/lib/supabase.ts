import { createClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

if (!PUBLIC_SUPABASE_URL || !PUBLIC_SUPABASE_ANON_KEY) {
    console.error('Supabase environment variables are missing! Please check your .env file.');
}

export const supabase = createClient(
    PUBLIC_SUPABASE_URL || 'https://placeholder.supabase.co', 
    PUBLIC_SUPABASE_ANON_KEY || 'placeholder'
);
