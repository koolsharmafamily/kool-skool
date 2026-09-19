import React, { useState } from 'react';
import { Settings as SettingsIcon, Cloud, Download, Upload, Pill, Smartphone, Check, Trash2 } from 'lucide-react';
import type { AppSettings } from '../types';
import { isSupabaseConnected, saveSupabaseCredentials, clearSupabaseCredentials } from '../lib/supabaseClient';
import { DataStore } from '../services/store';

interface SettingsViewProps {
  settings: AppSettings;
  onUpdateSettings: (settings: AppSettings) => void;
}

export const SettingsView: React.FC<SettingsViewProps> = ({ settings, onUpdateSettings }) => {
  const [supabaseUrl, setSupabaseUrl] = useState('');
  const [supabaseKey, setSupabaseKey] = useState('');
  const [importStatus, setImportStatus] = useState<string | null>(null);

  const connected = isSupabaseConnected();

  const handleConnectSupabase = (e: React.FormEvent) => {
    e.preventDefault();
    if (!supabaseUrl.trim() || !supabaseKey.trim()) return;
    saveSupabaseCredentials(supabaseUrl, supabaseKey);
  };

  const handleExportJSON = () => {
    const jsonStr = DataStore.exportJSON();
    const blob = new Blob([jsonStr], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `koolskool-backup-${new Date().toISOString().split('T')[0]}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleImportJSON = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (evt) => {
      const content = evt.target?.result as string;
      const success = DataStore.importJSON(content);
      if (success) {
        setImportStatus('Data imported successfully!');
        setTimeout(() => window.location.reload(), 1200);
      } else {
        setImportStatus('Error importing JSON file.');
      }
    };
    reader.readAsText(file);
  };

  return (
    <div className="max-w-md mx-auto w-full p-4 space-y-5 pb-20">
      <div className="text-center space-y-1">
        <h2 className="text-lg font-bold text-white flex items-center justify-center gap-2">
          <SettingsIcon className="w-5 h-5 text-slate-400" /> Settings & Cloud Sync
        </h2>
        <p className="text-xs text-slate-400">Manage data backup, Supabase cloud sync, and preferences.</p>
      </div>

      {/* iPhone PWA Installation Helper */}
      <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl space-y-2">
        <h3 className="text-xs font-bold text-orange-400 uppercase tracking-wider flex items-center gap-1.5">
          <Smartphone className="w-4 h-4" /> Add to iPhone Home Screen
        </h3>
        <p className="text-xs text-slate-300 leading-relaxed">
          1. Open this website link in <strong>Safari</strong> on your iPhone.<br />
          2. Tap the <strong>Share button</strong> (square with up arrow) at the bottom.<br />
          3. Tap <strong>"Add to Home Screen"</strong>.<br />
          4. Open Kool Skool from your iPhone home screen! Zero 7-day expiration.
        </p>
      </div>

      {/* Supabase Cloud Sync Section */}
      <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="text-xs font-bold text-slate-300 uppercase tracking-wider flex items-center gap-1.5">
            <Cloud className="w-4 h-4 text-emerald-400" /> Supabase Cloud Sync
          </h3>
          <span
            className={`text-[10px] font-bold px-2 py-0.5 rounded-full border ${
              connected
                ? 'bg-emerald-950 border-emerald-500/50 text-emerald-400'
                : 'bg-slate-800 border-slate-700 text-slate-400'
            }`}
          >
            {connected ? 'Connected' : 'Offline / Local'}
          </span>
        </div>

        {connected ? (
          <div className="space-y-2 pt-1">
            <p className="text-xs text-emerald-400 flex items-center gap-1">
              <Check className="w-4 h-4" /> Connected to your Supabase PostgreSQL cloud database!
            </p>
            <button
              onClick={clearSupabaseCredentials}
              className="text-xs text-red-400 hover:text-red-300 flex items-center gap-1 pt-1"
            >
              <Trash2 className="w-3.5 h-3.5" /> Disconnect Supabase Cloud
            </button>
          </div>
        ) : (
          <form onSubmit={handleConnectSupabase} className="space-y-2.5 pt-1">
            <p className="text-xs text-slate-400">
              Enter your free Supabase project credentials to sync your data automatically to the cloud:
            </p>
            <input
              type="text"
              placeholder="https://xyz.supabase.co"
              value={supabaseUrl}
              onChange={(e) => setSupabaseUrl(e.target.value)}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-white focus:outline-none focus:border-orange-500"
            />
            <input
              type="password"
              placeholder="anon-public-key"
              value={supabaseKey}
              onChange={(e) => setSupabaseKey(e.target.value)}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-white focus:outline-none focus:border-orange-500"
            />
            <button
              type="submit"
              className="w-full py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs rounded-xl shadow-md transition-all"
            >
              Connect Supabase Cloud
            </button>
          </form>
        )}
      </div>

      {/* Manual JSON Data Backup & Restore */}
      <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl space-y-3">
        <h3 className="text-xs font-bold text-slate-300 uppercase tracking-wider">Manual Data Backup</h3>
        <p className="text-xs text-slate-400">
          Export your tasks, sessions, and streaks to a local JSON file or import an existing backup.
        </p>

        {importStatus && (
          <div className="text-xs font-semibold text-emerald-400 bg-emerald-950/60 border border-emerald-800 p-2 rounded-xl">
            {importStatus}
          </div>
        )}

        <div className="flex items-center gap-2">
          <button
            onClick={handleExportJSON}
            className="flex-1 flex items-center justify-center gap-1.5 py-2.5 bg-slate-800 hover:bg-slate-700 text-white font-semibold text-xs rounded-xl transition-all"
          >
            <Download className="w-4 h-4" /> Export Backup
          </button>

          <label className="flex-1 flex items-center justify-center gap-1.5 py-2.5 bg-slate-800 hover:bg-slate-700 text-white font-semibold text-xs rounded-xl cursor-pointer transition-all">
            <Upload className="w-4 h-4" /> Import Backup
            <input type="file" accept=".json" onChange={handleImportJSON} className="hidden" />
          </label>
        </div>
      </div>

      {/* Preferences Section */}
      <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl space-y-3">
        <h3 className="text-xs font-bold text-slate-300 uppercase tracking-wider">Preferences</h3>

        {/* Medication Tracking Toggle */}
        <div className="flex items-center justify-between py-1">
          <div className="flex items-center gap-2 text-xs font-semibold text-slate-200">
            <Pill className="w-4 h-4 text-purple-400" />
            <span>Medication Tracking</span>
          </div>
          <button
            onClick={() =>
              onUpdateSettings({
                ...settings,
                medicationTrackingEnabled: !settings.medicationTrackingEnabled,
              })
            }
            className={`w-11 h-6 rounded-full p-1 transition-colors ${
              settings.medicationTrackingEnabled ? 'bg-orange-500' : 'bg-slate-800'
            }`}
          >
            <div
              className={`w-4 h-4 rounded-full bg-white transition-transform ${
                settings.medicationTrackingEnabled ? 'translate-x-5' : 'translate-x-0'
              }`}
            />
          </button>
        </div>
      </div>
    </div>
  );
};
