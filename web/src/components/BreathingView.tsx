import React, { useState, useEffect } from 'react';
import { Wind, Play, Square, Bell } from 'lucide-react';
import { soundscape } from '../services/soundscape';

export const BreathingView: React.FC = () => {
  const [isActive, setIsActive] = useState(false);
  const [phase, setPhase] = useState<'Inhale' | 'Hold' | 'Exhale' | 'Rest'>('Inhale');
  const [countdown, setCountdown] = useState(4);

  useEffect(() => {
    let timer: ReturnType<typeof setInterval> | null = null;

    if (isActive) {
      timer = setInterval(() => {
        setCountdown((prev) => {
          if (prev > 1) return prev - 1;

          // Transition phase
          if (phase === 'Inhale') {
            setPhase('Hold');
            return 4;
          } else if (phase === 'Hold') {
            setPhase('Exhale');
            return 4;
          } else if (phase === 'Exhale') {
            setPhase('Rest');
            return 2;
          } else {
            setPhase('Inhale');
            return 4;
          }
        });
      }, 1000);
    }

    return () => {
      if (timer) clearInterval(timer);
    };
  }, [isActive, phase]);

  const toggleBreathing = () => {
    if (!isActive) {
      setIsActive(true);
      setPhase('Inhale');
      setCountdown(4);
      soundscape.playBell();
    } else {
      setIsActive(false);
    }
  };

  const getPhaseColor = () => {
    switch (phase) {
      case 'Inhale': return 'border-emerald-400 text-emerald-400 shadow-emerald-950/50';
      case 'Hold': return 'border-amber-400 text-amber-400 shadow-amber-950/50';
      case 'Exhale': return 'border-cyan-400 text-cyan-400 shadow-cyan-950/50';
      case 'Rest': return 'border-slate-500 text-slate-400 shadow-slate-950/50';
    }
  };

  const getScaleClass = () => {
    if (!isActive) return 'scale-90';
    switch (phase) {
      case 'Inhale': return 'scale-110 transition-all duration-[4000ms] ease-out';
      case 'Hold': return 'scale-110';
      case 'Exhale': return 'scale-75 transition-all duration-[4000ms] ease-in';
      case 'Rest': return 'scale-75';
    }
  };

  return (
    <div className="max-w-md mx-auto w-full p-4 flex flex-col items-center justify-center space-y-6 my-4 pb-20">
      <div className="text-center space-y-1">
        <h2 className="text-lg font-bold text-white flex items-center justify-center gap-2">
          <Wind className="w-5 h-5 text-cyan-400" /> Stillness & Box Breathing
        </h2>
        <p className="text-xs text-slate-400">Paced 4-4-4-2 breathing to reset your nervous system.</p>
      </div>

      {/* Animated Breathing Circle */}
      <div className="relative w-64 h-64 flex items-center justify-center my-4">
        <div
          className={`w-48 h-48 rounded-full border-4 flex flex-col items-center justify-center shadow-2xl bg-slate-900/60 transition-transform ${getPhaseColor()} ${getScaleClass()}`}
        >
          <span className="text-xs font-semibold uppercase tracking-wider">{phase}</span>
          <span className="text-3xl font-extrabold font-mono mt-1">{countdown}</span>
        </div>
      </div>

      {/* Action Button */}
      <div className="flex items-center gap-3">
        <button
          onClick={toggleBreathing}
          className={`flex items-center gap-2 px-6 py-3 rounded-full text-sm font-bold shadow-lg transition-all ${
            isActive
              ? 'bg-slate-800 text-slate-300 hover:bg-slate-700'
              : 'bg-cyan-600 hover:bg-cyan-500 text-white shadow-cyan-950/40'
          }`}
        >
          {isActive ? (
            <>
              <Square className="w-4 h-4 fill-current" /> Stop Practice
            </>
          ) : (
            <>
              <Play className="w-4 h-4 fill-current" /> Begin Breathwork
            </>
          )}
        </button>

        <button
          onClick={() => soundscape.playBell()}
          className="p-3 rounded-full bg-slate-900 border border-slate-800 text-slate-400 hover:text-cyan-400 transition-all"
          title="Play Calming Bell"
        >
          <Bell className="w-4 h-4" />
        </button>
      </div>
    </div>
  );
};
