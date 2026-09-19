import React, { useState, useEffect, useRef } from 'react';
import { Play, Pause, RotateCcw, Volume2, VolumeX, Sparkles, CheckCircle2 } from 'lucide-react';
import type { FocusTask, FocusSession } from '../types';
import { soundscape } from '../services/soundscape';

interface DiscTimerProps {
  selectedTask?: FocusTask | null;
  onCompleteSession: (session: FocusSession) => void;
}

export const DiscTimer: React.FC<DiscTimerProps> = ({ selectedTask, onCompleteSession }) => {
  const [durationMinutes, setDurationMinutes] = useState<number>(selectedTask?.estimateMinutes || 25);
  const [secondsRemaining, setSecondsRemaining] = useState<number>((selectedTask?.estimateMinutes || 25) * 60);
  const [isRunning, setIsRunning] = useState<boolean>(false);
  const [isAudioPlaying, setIsAudioPlaying] = useState<boolean>(false);
  const [isFinished, setIsFinished] = useState<boolean>(false);

  const startTimeRef = useRef<string | null>(null);

  useEffect(() => {
    if (selectedTask) {
      setDurationMinutes(selectedTask.estimateMinutes);
      setSecondsRemaining(selectedTask.estimateMinutes * 60);
      setIsRunning(false);
      setIsFinished(false);
    }
  }, [selectedTask]);

  useEffect(() => {
    let timer: ReturnType<typeof setInterval> | null = null;
    if (isRunning && secondsRemaining > 0) {
      timer = setInterval(() => {
        setSecondsRemaining((prev) => prev - 1);
      }, 1000);
    } else if (isRunning && secondsRemaining === 0) {
      handleComplete(true);
    }
    return () => {
      if (timer) clearInterval(timer);
    };
  }, [isRunning, secondsRemaining]);

  const toggleTimer = () => {
    if (!isRunning) {
      if (!startTimeRef.current) {
        startTimeRef.current = new Date().toISOString();
      }
      setIsRunning(true);
      soundscape.start('brown_noise');
      setIsAudioPlaying(true);
    } else {
      setIsRunning(false);
      soundscape.stop();
      setIsAudioPlaying(false);
    }
  };

  const resetTimer = () => {
    setIsRunning(false);
    setIsFinished(false);
    setSecondsRemaining(durationMinutes * 60);
    startTimeRef.current = null;
    soundscape.stop();
    setIsAudioPlaying(false);
  };

  const addMinutes = (mins: number) => {
    setSecondsRemaining((prev) => prev + mins * 60);
  };

  const toggleSoundscape = () => {
    if (isAudioPlaying) {
      soundscape.stop();
      setIsAudioPlaying(false);
    } else {
      soundscape.start('brown_noise');
      setIsAudioPlaying(true);
    }
  };

  const handleComplete = (naturally = true) => {
    setIsRunning(false);
    setIsFinished(true);
    soundscape.stop();
    setIsAudioPlaying(false);
    soundscape.playBell();

    const totalSecs = durationMinutes * 60;
    const actualSecs = totalSecs - secondsRemaining;
    const xpEarned = Math.max(10, Math.floor(actualSecs / 60) * 2);
    const coinsEarned = Math.max(2, Math.floor(xpEarned / 5));

    const newSession: FocusSession = {
      id: crypto.randomUUID(),
      taskId: selectedTask?.id,
      durationSeconds: totalSecs,
      actualSeconds: Math.max(actualSecs, 60),
      completedNaturally: naturally,
      xpEarned,
      coinsEarned,
      startedAt: startTimeRef.current || new Date().toISOString(),
      endedAt: new Date().toISOString(),
    };

    onCompleteSession(newSession);
  };

  // Disc progress math
  const totalSeconds = durationMinutes * 60;
  const progressFraction = Math.max(0, Math.min(1, secondsRemaining / totalSeconds));
  const strokeDashoffset = 283 * (1 - progressFraction);

  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  return (
    <div className="flex flex-col items-center justify-center p-6 bg-slate-900/50 rounded-3xl border border-slate-800 shadow-2xl max-w-md mx-auto w-full my-4">
      {/* Selected Task Banner */}
      {selectedTask && (
        <div className="w-full bg-slate-850 border border-slate-750 px-4 py-2.5 rounded-2xl mb-6 text-center">
          <span className="text-[11px] font-semibold text-orange-400 uppercase tracking-wider block mb-0.5">Current Focus</span>
          <p className="text-sm font-semibold text-slate-100 truncate">{selectedTask.title}</p>
          {selectedTask.nextStep && (
            <p className="text-xs text-slate-400 mt-1">Step: {selectedTask.nextStep}</p>
          )}
        </div>
      )}

      {/* Visual Time-Blindness Disc */}
      <div className="relative w-64 h-64 flex items-center justify-center my-2">
        <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100">
          {/* Track Circle */}
          <circle
            cx="50"
            cy="50"
            r="45"
            className="stroke-slate-800"
            strokeWidth="8"
            fill="transparent"
          />
          {/* Progress Disc Circle */}
          <circle
            cx="50"
            cy="50"
            r="45"
            className={`transition-all duration-1000 ease-linear ${
              isFinished
                ? 'stroke-emerald-500'
                : isRunning
                ? 'stroke-orange-500'
                : 'stroke-amber-600'
            }`}
            strokeWidth="8"
            strokeDasharray="283"
            strokeDashoffset={strokeDashoffset}
            strokeLinecap="round"
            fill="transparent"
          />
        </svg>

        {/* Center Countdown Display */}
        <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
          {isFinished ? (
            <div className="flex flex-col items-center animate-bounce">
              <CheckCircle2 className="w-12 h-12 text-emerald-400 mb-1" />
              <span className="text-lg font-bold text-emerald-400">Great Job!</span>
            </div>
          ) : (
            <>
              <span className="font-mono text-4xl font-extrabold tracking-tight text-white drop-shadow-md">
                {formatTime(secondsRemaining)}
              </span>
              <span className="text-xs text-slate-400 mt-1 font-medium">
                {isRunning ? 'Session Active' : 'Ready to Start'}
              </span>
            </>
          )}
        </div>
      </div>

      {/* Preset Duration Buttons */}
      {!isRunning && !isFinished && (
        <div className="flex items-center gap-2 my-4">
          {[15, 25, 45, 60].map((mins) => (
            <button
              key={mins}
              onClick={() => {
                setDurationMinutes(mins);
                setSecondsRemaining(mins * 60);
              }}
              className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-all ${
                durationMinutes === mins
                  ? 'bg-orange-500 text-white shadow-md shadow-orange-950/40'
                  : 'bg-slate-800 text-slate-400 hover:text-slate-200'
              }`}
            >
              {mins}m
            </button>
          ))}
        </div>
      )}

      {/* Main Action Controls */}
      <div className="flex items-center gap-4 mt-4">
        <button
          onClick={resetTimer}
          className="p-3 rounded-full bg-slate-800 text-slate-400 hover:text-slate-200 hover:bg-slate-700 transition-all"
          title="Reset Timer"
        >
          <RotateCcw className="w-5 h-5" />
        </button>

        <button
          onClick={toggleTimer}
          className={`flex items-center gap-2 px-7 py-3.5 rounded-full text-base font-bold shadow-xl transition-all ${
            isRunning
              ? 'bg-amber-600 hover:bg-amber-500 text-white shadow-amber-950/40'
              : 'bg-orange-500 hover:bg-orange-400 text-white shadow-orange-950/50 scale-105'
          }`}
        >
          {isRunning ? (
            <>
              <Pause className="w-5 h-5 fill-current" /> Pause
            </>
          ) : (
            <>
              <Play className="w-5 h-5 fill-current ml-0.5" /> Start Focus
            </>
          )}
        </button>

        <button
          onClick={toggleSoundscape}
          className={`p-3 rounded-full transition-all ${
            isAudioPlaying
              ? 'bg-orange-950/60 border border-orange-500/50 text-orange-400'
              : 'bg-slate-800 text-slate-400 hover:text-slate-200'
          }`}
          title={isAudioPlaying ? 'Mute Soundscape' : 'Play Ambient Soundscape'}
        >
          {isAudioPlaying ? <Volume2 className="w-5 h-5 animate-pulse" /> : <VolumeX className="w-5 h-5" />}
        </button>
      </div>

      {/* Additional Actions */}
      {isRunning && (
        <div className="flex items-center gap-3 mt-4 pt-3 border-t border-slate-800/80 w-full justify-center">
          <button
            onClick={() => addMinutes(5)}
            className="text-xs font-semibold text-slate-400 hover:text-slate-200 px-3 py-1.5 rounded-lg bg-slate-800/50"
          >
            +5 mins
          </button>
          <button
            onClick={() => handleComplete(false)}
            className="text-xs font-semibold text-emerald-400 hover:text-emerald-300 px-3 py-1.5 rounded-lg bg-emerald-950/40 border border-emerald-800/50 flex items-center gap-1"
          >
            <Sparkles className="w-3.5 h-3.5" /> Finish Early
          </button>
        </div>
      )}
    </div>
  );
};
