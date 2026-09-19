import { createClient, SupabaseClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || localStorage.getItem('ks_supabase_url') || '';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || localStorage.getItem('ks_supabase_key') || '';

export const supabase: SupabaseClient | null =
  supabaseUrl && supabaseAnonKey
    ? createClient(supabaseUrl, supabaseAnonKey)
    : null;

export function isSupabaseConnected(): boolean {
  return supabase !== null;
}

export function saveSupabaseCredentials(url: string, key: string) {
  if (url && key) {
    localStorage.setItem('ks_supabase_url', url.trim());
    localStorage.setItem('ks_supabase_key', key.trim());
    window.location.reload();
  }
}

export function clearSupabaseCredentials() {
  localStorage.removeItem('ks_supabase_url');
  localStorage.removeItem('ks_supabase_key');
  window.location.reload();
}
