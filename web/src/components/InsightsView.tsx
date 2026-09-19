import React from 'react';
import { Flame, ShieldCheck, Clock, CheckCircle2, Trophy, Coins } from 'lucide-react';
import type { UserProgress, FocusSession, FocusTask } from '../types';

interface InsightsViewProps {
  progress: UserProgress;
  sessions: FocusSession[];
  tasks: FocusTask[];
}

export const InsightsView: React.FC<InsightsViewProps> = ({ progress, sessions, tasks }) => {
  const totalMinutesFocused = Math.round(
    sessions.reduce((acc, s) => acc + s.actualSeconds, 0) / 60
  );
  const completedTasksCount = tasks.filter((t) => t.isCompleted).length;

  return (
    <div className="max-w-md mx-auto w-full p-4 space-y-5 pb-20">
      <div className="text-center space-y-1">
        <h2 className="text-lg font-bold text-white flex items-center justify-center gap-2">
          <Trophy className="w-5 h-5 text-amber-400" /> Insights & Progress
        </h2>
        <p className="text-xs text-slate-400">Track your consistency without feeling punished for missed days.</p>
      </div>

      {/* Grid Summary Cards */}
      <div className="grid grid-cols-2 gap-3">
        {/* Streak Card */}
        <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl space-y-1">
          <div className="flex items-center justify-between text-orange-400">
            <Flame className="w-5 h-5 fill-orange-400" />
            <span className="text-2xl font-extrabold text-white">{progress.currentStreak}</span>
          </div>
          <span className="text-xs font-semibold text-slate-400 block">Current Streak</span>
          <p className="text-[10px] text-slate-500">Longest: {progress.longestStreak} days</p>
        </div>

        {/* Shield Protection Card */}
        <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl space-y-1">
          <div className="flex items-center justify-between text-emerald-400">
            <ShieldCheck className="w-5 h-5" />
            <span className="text-2xl font-extrabold text-white">{progress.streakShields}/2</span>
          </div>
          <span className="text-xs font-semibold text-slate-400 block">Grace Protection</span>
          <p className="text-[10px] text-slate-500">Forgives 2 missed days/mo</p>
        </div>

        {/* Focus Time Card */}
        <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl space-y-1">
          <div className="flex items-center justify-between text-cyan-400">
            <Clock className="w-5 h-5" />
            <span className="text-2xl font-extrabold text-white">{totalMinutesFocused}m</span>
          </div>
          <span className="text-xs font-semibold text-slate-400 block">Total Focus Time</span>
          <p className="text-[10px] text-slate-500">{sessions.length} sessions</p>
        </div>

        {/* Tasks Done Card */}
        <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl space-y-1">
          <div className="flex items-center justify-between text-amber-400">
            <Coins className="w-5 h-5 fill-amber-400" />
            <span className="text-2xl font-extrabold text-white">{completedTasksCount}</span>
          </div>
          <span className="text-xs font-semibold text-slate-400 block">Tasks Completed</span>
          <p className="text-[10px] text-slate-500">Earned {progress.coins} coins</p>
        </div>
      </div>

      {/* Recent Sessions List */}
      <div className="space-y-3 pt-2">
        <h3 className="text-xs font-bold text-slate-400 uppercase tracking-wider">Recent Sessions</h3>

        {sessions.length === 0 ? (
          <div className="border border-slate-800 rounded-2xl p-6 text-center text-slate-500 text-xs">
            No focus sessions logged yet. Start a session from the Focus Disc tab!
          </div>
        ) : (
          <div className="space-y-2">
            {sessions.slice(0, 5).map((s) => (
              <div
                key={s.id}
                className="bg-slate-900 border border-slate-800 p-3 rounded-2xl flex items-center justify-between text-xs"
              >
                <div className="flex items-center gap-2">
                  <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                  <div>
                    <span className="font-semibold text-slate-200">
                      {Math.round(s.actualSeconds / 60)} min session
                    </span>
                    <span className="text-[10px] text-slate-500 block">
                      {new Date(s.endedAt).toLocaleDateString()} at {new Date(s.endedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </span>
                  </div>
                </div>

                <div className="text-right font-mono text-orange-400 font-bold">
                  +{s.xpEarned} XP
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
