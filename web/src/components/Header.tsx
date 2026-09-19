import React from 'react';
import { Flame, Coins, ShieldCheck, Cloud, CloudOff, Target, CirclePlay, Wind, BarChart3, Settings as SettingsIcon } from 'lucide-react';
import type { UserProgress } from '../types';
import { isSupabaseConnected } from '../lib/supabaseClient';

interface HeaderProps {
  progress: UserProgress;
  activeTab: string;
  setActiveTab: (tab: string) => void;
}

export const Header: React.FC<HeaderProps> = ({ progress, activeTab, setActiveTab }) => {
  const connected = isSupabaseConnected();

  const navItems = [
    { id: 'today', label: 'Today', icon: Target },
    { id: 'focus', label: 'Focus Disc', icon: CirclePlay },
    { id: 'breathing', label: 'Stillness', icon: Wind },
    { id: 'insights', label: 'Insights', icon: BarChart3 },
    { id: 'settings', label: 'Settings', icon: SettingsIcon },
  ];

  return (
    <header className="sticky top-0 z-50 bg-slate-950/80 backdrop-blur-md border-b border-slate-800 px-4 py-3 max-w-md mx-auto w-full">
      <div className="flex items-center justify-between">
        {/* Brand & Sync Indicator */}
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-orange-500 to-amber-600 flex items-center justify-center shadow-lg shadow-orange-950/50">
            <span className="font-extrabold text-white text-base tracking-tighter">KS</span>
          </div>
          <div>
            <h1 className="font-bold text-sm tracking-tight text-white flex items-center gap-1.5">
              Kool Skool
              {connected ? (
                <span title="Cloud Synced with Supabase">
                  <Cloud className="w-3.5 h-3.5 text-emerald-400" />
                </span>
              ) : (
                <span title="Offline / Local Storage Mode">
                  <CloudOff className="w-3.5 h-3.5 text-slate-500" />
                </span>
              )}
            </h1>
            <p className="text-[10px] text-slate-400 font-mono">XP: {progress.xp}</p>
          </div>
        </div>

        {/* Stats Badges */}
        <div className="flex items-center gap-2 text-xs">
          {/* Streak */}
          <div className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-slate-900 border border-slate-800 text-orange-400 font-semibold">
            <Flame className="w-3.5 h-3.5 fill-orange-400" />
            <span>{progress.currentStreak}</span>
            {progress.streakShields > 0 && (
              <span title={`${progress.streakShields} Grace Shield(s)`}>
                <ShieldCheck className="w-3 h-3 text-emerald-400 ml-0.5" />
              </span>
            )}
          </div>

          {/* Coins */}
          <div className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-slate-900 border border-slate-800 text-amber-400 font-semibold">
            <Coins className="w-3.5 h-3.5 fill-amber-400" />
            <span>{progress.coins}</span>
          </div>
        </div>
      </div>

      {/* Navigation Bar */}
      <nav className="flex items-center justify-around mt-3 pt-2 border-t border-slate-900">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              className={`flex flex-col items-center gap-1 py-1 px-2.5 rounded-lg text-[11px] font-medium transition-all ${
                isActive
                  ? 'text-orange-400 bg-orange-950/30 font-semibold'
                  : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900'
              }`}
            >
              <Icon className={`w-4 h-4 ${isActive ? 'text-orange-400 scale-110' : ''}`} />
              <span>{item.label}</span>
            </button>
          );
        })}
      </nav>
    </header>
  );
};
