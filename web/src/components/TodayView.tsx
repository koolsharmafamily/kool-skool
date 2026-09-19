import React, { useState } from 'react';
import { Plus, Pin, CheckCircle, Circle, Trash2, Split, BatteryLow, BatteryMedium, BatteryFull, Pill, Sparkles } from 'lucide-react';
import type { FocusTask, EnergyState, CheckInRecord } from '../types';

interface TodayViewProps {
  tasks: FocusTask[];
  onSaveTask: (task: FocusTask) => void;
  onDeleteTask: (id: string) => void;
  onSelectTaskForFocus: (task: FocusTask) => void;
  checkInToday?: CheckInRecord;
  onSaveCheckIn: (record: CheckInRecord) => void;
  medicationTrackingEnabled: boolean;
}

export const TodayView: React.FC<TodayViewProps> = ({
  tasks,
  onSaveTask,
  onDeleteTask,
  onSelectTaskForFocus,
  checkInToday,
  onSaveCheckIn,
  medicationTrackingEnabled,
}) => {
  const [brainDumpInput, setBrainDumpInput] = useState('');
  const [selectedTaskForSplit, setSelectedTaskForSplit] = useState<FocusTask | null>(null);
  const [nextStepInput, setNextStepInput] = useState('');

  const todayStr = new Date().toISOString().split('T')[0];

  const handleCaptureBrainDump = (e: React.FormEvent) => {
    e.preventDefault();
    if (!brainDumpInput.trim()) return;

    const newTask: FocusTask = {
      id: crypto.randomUUID(),
      title: brainDumpInput.trim(),
      estimateMinutes: 25,
      resistanceRating: 3,
      isPinned: false,
      isCompleted: false,
      sortOrder: tasks.length,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    onSaveTask(newTask);
    setBrainDumpInput('');
  };

  const togglePin = (task: FocusTask) => {
    const pinnedCount = tasks.filter((t) => t.isPinned && !t.isCompleted).length;
    if (!task.isPinned && pinnedCount >= 3) {
      alert('You can pin at most 3 top tasks for today to stay focused!');
      return;
    }
    onSaveTask({ ...task, isPinned: !task.isPinned });
  };

  const toggleComplete = (task: FocusTask) => {
    onSaveTask({
      ...task,
      isCompleted: !task.isCompleted,
      completedAt: !task.isCompleted ? new Date().toISOString() : undefined,
    });
  };

  const handleEnergySelect = (energyState: EnergyState) => {
    const record: CheckInRecord = {
      id: checkInToday?.id || crypto.randomUUID(),
      energyState,
      medicationTaken: checkInToday?.medicationTaken || false,
      date: todayStr,
      createdAt: new Date().toISOString(),
    };
    onSaveCheckIn(record);
  };

  const toggleMedication = () => {
    const record: CheckInRecord = {
      id: checkInToday?.id || crypto.randomUUID(),
      energyState: checkInToday?.energyState || 'medium',
      medicationTaken: !(checkInToday?.medicationTaken || false),
      medicationTakenAt: !checkInToday?.medicationTaken ? new Date().toISOString() : undefined,
      date: todayStr,
      createdAt: new Date().toISOString(),
    };
    onSaveCheckIn(record);
  };

  const saveNextStep = () => {
    if (selectedTaskForSplit && nextStepInput.trim()) {
      onSaveTask({
        ...selectedTaskForSplit,
        nextStep: nextStepInput.trim(),
      });
      setSelectedTaskForSplit(null);
      setNextStepInput('');
    }
  };

  const pinnedTasks = tasks.filter((t) => t.isPinned && !t.isCompleted);
  const inboxTasks = tasks.filter((t) => !t.isPinned && !t.isCompleted);
  const completedTasks = tasks.filter((t) => t.isCompleted);

  return (
    <div className="max-w-md mx-auto w-full p-4 space-y-5 pb-20">
      {/* Daily Check-in & Energy Banner */}
      <div className="bg-slate-900 border border-slate-800 p-4 rounded-2xl space-y-3">
        <div className="flex items-center justify-between">
          <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">Daily Energy Check-In</span>
          {medicationTrackingEnabled && (
            <button
              onClick={toggleMedication}
              className={`flex items-center gap-1.5 text-xs px-2.5 py-1 rounded-full border transition-all ${
                checkInToday?.medicationTaken
                  ? 'bg-emerald-950/60 border-emerald-500/50 text-emerald-400 font-semibold'
                  : 'bg-slate-800 border-slate-700 text-slate-400 hover:text-slate-200'
              }`}
            >
              <Pill className="w-3.5 h-3.5" />
              <span>{checkInToday?.medicationTaken ? 'Meds Logged' : 'Log Meds'}</span>
            </button>
          )}
        </div>

        <div className="flex items-center justify-between gap-2 pt-1">
          {(['low', 'medium', 'high'] as EnergyState[]).map((state) => {
            const isSelected = checkInToday?.energyState === state;
            const icons = {
              low: BatteryLow,
              medium: BatteryMedium,
              high: BatteryFull,
            };
            const labels = { low: 'Low Energy', medium: 'Steady', high: 'High Focus' };
            const Icon = icons[state];

            return (
              <button
                key={state}
                onClick={() => handleEnergySelect(state)}
                className={`flex-1 flex items-center justify-center gap-1.5 py-2 px-3 rounded-xl border text-xs font-semibold transition-all ${
                  isSelected
                    ? 'bg-orange-500/20 border-orange-500 text-orange-400 shadow-md'
                    : 'bg-slate-950 border-slate-800 text-slate-400 hover:bg-slate-800 hover:text-slate-200'
                }`}
              >
                <Icon className="w-4 h-4" />
                <span>{labels[state]}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Top 3 Pinned Focus Tasks */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <h2 className="text-xs font-bold text-orange-400 uppercase tracking-wider flex items-center gap-1.5">
            <Pin className="w-3.5 h-3.5 fill-orange-400" /> Today's Top 3 ({pinnedTasks.length}/3)
          </h2>
          <span className="text-[10px] text-slate-500">Pick up to 3 for today</span>
        </div>

        {pinnedTasks.length === 0 ? (
          <div className="border border-dashed border-slate-800 rounded-2xl p-6 text-center text-slate-500 text-xs">
            No pinned tasks for today yet. Pin up to 3 tasks from your brain dump below to focus without overwhelm!
          </div>
        ) : (
          <div className="space-y-2.5">
            {pinnedTasks.map((task) => (
              <div
                key={task.id}
                className="bg-slate-900 border border-slate-800 p-3.5 rounded-2xl flex items-center justify-between gap-3 shadow-md hover:border-slate-700 transition-all"
              >
                <div className="flex items-center gap-3 flex-1 min-w-0">
                  <button onClick={() => toggleComplete(task)} className="text-slate-500 hover:text-orange-400">
                    <Circle className="w-5 h-5" />
                  </button>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-semibold text-white truncate">{task.title}</p>
                    {task.nextStep && (
                      <p className="text-xs text-orange-300 font-medium truncate">Step: {task.nextStep}</p>
                    )}
                  </div>
                </div>

                <div className="flex items-center gap-1.5">
                  <button
                    onClick={() => onSelectTaskForFocus(task)}
                    className="bg-orange-500 hover:bg-orange-400 text-white font-bold text-xs px-3 py-1.5 rounded-xl shadow-md shadow-orange-950/40"
                  >
                    Focus
                  </button>
                  <button
                    onClick={() => {
                      setSelectedTaskForSplit(task);
                      setNextStepInput(task.nextStep || '');
                    }}
                    className="p-1.5 text-slate-400 hover:text-slate-200"
                    title="Micro-step breakdown"
                  >
                    <Split className="w-4 h-4" />
                  </button>
                  <button onClick={() => togglePin(task)} className="p-1.5 text-orange-400 hover:text-slate-400">
                    <Pin className="w-4 h-4 fill-orange-400" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Brain Dump Capture Bar */}
      <form onSubmit={handleCaptureBrainDump} className="flex items-center gap-2">
        <input
          type="text"
          value={brainDumpInput}
          onChange={(e) => setBrainDumpInput(e.target.value)}
          placeholder="Dump what's in your head..."
          className="flex-1 bg-slate-900 border border-slate-800 rounded-2xl px-4 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-orange-500"
        />
        <button
          type="submit"
          className="bg-slate-800 hover:bg-slate-700 text-slate-200 p-3 rounded-2xl font-bold transition-all"
          title="Add to Brain Dump"
        >
          <Plus className="w-5 h-5" />
        </button>
      </form>

      {/* Brain Dump Inbox Tasks */}
      <div className="space-y-3 pt-2">
        <h2 className="text-xs font-bold text-slate-400 uppercase tracking-wider">Brain Dump Inbox ({inboxTasks.length})</h2>

        {inboxTasks.length === 0 ? (
          <div className="text-xs text-slate-600 text-center py-4">Inbox is clean! Type above to dump a task.</div>
        ) : (
          <div className="space-y-2">
            {inboxTasks.map((task) => (
              <div
                key={task.id}
                className="bg-slate-900/60 border border-slate-800/80 p-3 rounded-2xl flex items-center justify-between gap-3 hover:bg-slate-900 transition-all"
              >
                <div className="flex items-center gap-3 flex-1 min-w-0">
                  <button onClick={() => toggleComplete(task)} className="text-slate-600 hover:text-orange-400">
                    <Circle className="w-4 h-4" />
                  </button>
                  <span className="text-xs font-medium text-slate-300 truncate">{task.title}</span>
                </div>

                <div className="flex items-center gap-1">
                  <button
                    onClick={() => togglePin(task)}
                    className="p-1.5 text-slate-500 hover:text-orange-400"
                    title="Pin to Today's Top 3"
                  >
                    <Pin className="w-3.5 h-3.5" />
                  </button>
                  <button
                    onClick={() => onDeleteTask(task.id)}
                    className="p-1.5 text-slate-600 hover:text-red-400"
                    title="Delete Task"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Completed Section */}
      {completedTasks.length > 0 && (
        <div className="space-y-2 pt-4 border-t border-slate-900">
          <span className="text-xs font-bold text-emerald-500 uppercase tracking-wider">Done Today ({completedTasks.length})</span>
          <div className="space-y-1.5">
            {completedTasks.map((task) => (
              <div key={task.id} className="flex items-center justify-between text-xs text-slate-500 py-1">
                <div className="flex items-center gap-2 line-through">
                  <CheckCircle className="w-3.5 h-3.5 text-emerald-500" />
                  <span>{task.title}</span>
                </div>
                <button onClick={() => toggleComplete(task)} className="text-[10px] text-slate-600 hover:text-slate-400">
                  Undo
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Micro-Step Breakdown Modal */}
      {selectedTaskForSplit && (
        <div className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 p-5 rounded-3xl max-w-sm w-full space-y-4 shadow-2xl">
            <div className="flex items-center gap-2 text-orange-400 font-bold text-sm">
              <Sparkles className="w-4 h-4" />
              <span>Micro-step Breakdown</span>
            </div>
            <p className="text-xs text-slate-400">
              Break <strong className="text-white">"{selectedTaskForSplit.title}"</strong> into one tiny 1-minute step so starting feels effortless.
            </p>
            <input
              type="text"
              value={nextStepInput}
              onChange={(e) => setNextStepInput(e.target.value)}
              placeholder="e.g. Open Google Doc, Type title..."
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2.5 text-xs text-white focus:outline-none focus:border-orange-500"
            />
            <div className="flex items-center justify-end gap-2 pt-2">
              <button
                onClick={() => setSelectedTaskForSplit(null)}
                className="px-3 py-1.5 rounded-xl text-xs font-semibold text-slate-400 hover:text-slate-200"
              >
                Cancel
              </button>
              <button
                onClick={saveNextStep}
                className="px-4 py-1.5 rounded-xl text-xs font-bold bg-orange-500 text-white shadow-md shadow-orange-950/40"
              >
                Save Step
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
