import { useState, useEffect } from 'react';
import { Header } from './components/Header';
import { TodayView } from './components/TodayView';
import { DiscTimer } from './components/DiscTimer';
import { BreathingView } from './components/BreathingView';
import { InsightsView } from './components/InsightsView';
import { SettingsView } from './components/SettingsView';
import type { FocusTask, FocusSession, UserProgress, CheckInRecord, AppSettings } from './types';
import { DataStore } from './services/store';

export function App() {
  const [activeTab, setActiveTab] = useState<string>('today');
  const [tasks, setTasks] = useState<FocusTask[]>([]);
  const [sessions, setSessions] = useState<FocusSession[]>([]);
  const [progress, setProgress] = useState<UserProgress>(DataStore.getProgress());
  const [checkIns, setCheckIns] = useState<CheckInRecord[]>([]);
  const [settings, setSettings] = useState<AppSettings>(DataStore.getSettings());
  const [selectedTaskForFocus, setSelectedTaskForFocus] = useState<FocusTask | null>(null);

  useEffect(() => {
    // Load local storage initial state
    setTasks(DataStore.getTasks());
    setSessions(DataStore.getSessions());
    setProgress(DataStore.getProgress());
    setCheckIns(DataStore.getCheckIns());
    setSettings(DataStore.getSettings());
  }, []);

  const handleSaveTask = async (task: FocusTask) => {
    const updatedTasks = await DataStore.saveTask(task);
    setTasks(updatedTasks);
  };

  const handleDeleteTask = async (id: string) => {
    const updatedTasks = await DataStore.deleteTask(id);
    setTasks(updatedTasks);
  };

  const handleSelectTaskForFocus = (task: FocusTask) => {
    setSelectedTaskForFocus(task);
    setActiveTab('focus');
  };

  const handleCompleteSession = async (session: FocusSession) => {
    const updatedSessions = await DataStore.addSession(session);
    setSessions(updatedSessions);
    setProgress(DataStore.getProgress());

    // Mark task completed if it was attached
    if (session.taskId) {
      const task = tasks.find((t) => t.id === session.taskId);
      if (task) {
        handleSaveTask({
          ...task,
          isCompleted: true,
          completedAt: new Date().toISOString(),
        });
      }
    }
  };

  const handleSaveCheckIn = (record: CheckInRecord) => {
    const updated = DataStore.saveCheckIn(record);
    setCheckIns(updated);
  };

  const handleUpdateSettings = (newSettings: AppSettings) => {
    const updated = DataStore.saveSettings(newSettings);
    setSettings(updated);
  };

  const todayStr = new Date().toISOString().split('T')[0];
  const checkInToday = checkIns.find((c) => c.date === todayStr);

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans">
      <Header progress={progress} activeTab={activeTab} setActiveTab={setActiveTab} />

      <main className="flex-1 max-w-md mx-auto w-full px-2">
        {activeTab === 'today' && (
          <TodayView
            tasks={tasks}
            onSaveTask={handleSaveTask}
            onDeleteTask={handleDeleteTask}
            onSelectTaskForFocus={handleSelectTaskForFocus}
            checkInToday={checkInToday}
            onSaveCheckIn={handleSaveCheckIn}
            medicationTrackingEnabled={settings.medicationTrackingEnabled}
          />
        )}

        {activeTab === 'focus' && (
          <DiscTimer
            selectedTask={selectedTaskForFocus}
            onCompleteSession={handleCompleteSession}
          />
        )}

        {activeTab === 'breathing' && <BreathingView />}

        {activeTab === 'insights' && (
          <InsightsView progress={progress} sessions={sessions} tasks={tasks} />
        )}

        {activeTab === 'settings' && (
          <SettingsView settings={settings} onUpdateSettings={handleUpdateSettings} />
        )}
      </main>
    </div>
  );
}

export default App;
