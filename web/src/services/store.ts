import type { FocusTask, FocusSession, UserProgress, CheckInRecord, AppSettings } from '../types';
import { supabase } from '../lib/supabaseClient';

const STORAGE_KEYS = {
  TASKS: 'ks_tasks_v1',
  SESSIONS: 'ks_sessions_v1',
  PROGRESS: 'ks_progress_v1',
  CHECKINS: 'ks_checkins_v1',
  SETTINGS: 'ks_settings_v1',
};

const DEFAULT_SETTINGS: AppSettings = {
  medicationTrackingEnabled: false,
  soundscapeVolume: 0.5,
  selectedSoundscape: 'brown_noise',
  tradition: 'secular',
  notificationsEnabled: false,
};

const DEFAULT_PROGRESS: UserProgress = {
  xp: 0,
  coins: 0,
  currentStreak: 0,
  longestStreak: 0,
  streakShields: 2,
};

// Helper: Local Storage getter/setter
function getLocal<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : fallback;
  } catch {
    return fallback;
  }
}

function setLocal<T>(key: string, value: T): void {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch (e) {
    console.error('LocalStorage write error', e);
  }
}

export class DataStore {
  // TASKS
  static getTasks(): FocusTask[] {
    return getLocal<FocusTask[]>(STORAGE_KEYS.TASKS, []);
  }

  static async saveTask(task: FocusTask): Promise<FocusTask[]> {
    const tasks = this.getTasks();
    const existingIndex = tasks.findIndex((t) => t.id === task.id);
    let updated: FocusTask[];

    if (existingIndex >= 0) {
      updated = [...tasks];
      updated[existingIndex] = { ...task, updatedAt: new Date().toISOString() };
    } else {
      updated = [task, ...tasks];
    }

    setLocal(STORAGE_KEYS.TASKS, updated);

    // Sync with Supabase if connected
    if (supabase) {
      try {
        const { data: userData } = await supabase.auth.getUser();
        const userId = userData.user?.id;
        await supabase.from('tasks').upsert({
          id: task.id,
          user_id: userId,
          title: task.title,
          notes: task.notes || null,
          next_step: task.nextStep || null,
          estimate_minutes: task.estimateMinutes,
          resistance_rating: task.resistanceRating,
          is_pinned: task.isPinned,
          is_completed: task.isCompleted,
          completed_at: task.completedAt || null,
          sort_order: task.sortOrder,
          updated_at: new Date().toISOString(),
        });
      } catch (err) {
        console.warn('Supabase task sync deferred:', err);
      }
    }

    return updated;
  }

  static async deleteTask(id: string): Promise<FocusTask[]> {
    const tasks = this.getTasks().filter((t) => t.id !== id);
    setLocal(STORAGE_KEYS.TASKS, tasks);

    if (supabase) {
      try {
        await supabase.from('tasks').delete().eq('id', id);
      } catch (err) {
        console.warn('Supabase task delete deferred:', err);
      }
    }

    return tasks;
  }

  // SESSIONS & REWARDS
  static getSessions(): FocusSession[] {
    return getLocal<FocusSession[]>(STORAGE_KEYS.SESSIONS, []);
  }

  static async addSession(session: FocusSession): Promise<FocusSession[]> {
    const sessions = [session, ...this.getSessions()];
    setLocal(STORAGE_KEYS.SESSIONS, sessions);

    // Calculate XP & coins
    const progress = this.getProgress();
    const newXp = progress.xp + session.xpEarned;
    const newCoins = progress.coins + session.coinsEarned;

    // Recalculate streak
    const updatedProgress = this.calculateStreak({
      ...progress,
      xp: newXp,
      coins: newCoins,
      lastActiveDate: new Date().toISOString().split('T')[0],
    });

    this.saveProgress(updatedProgress);

    if (supabase) {
      try {
        const { data: userData } = await supabase.auth.getUser();
        const userId = userData.user?.id;
        await supabase.from('sessions').insert({
          id: session.id,
          user_id: userId,
          task_id: session.taskId || null,
          duration_seconds: session.durationSeconds,
          actual_seconds: session.actualSeconds,
          completed_naturally: session.completedNaturally,
          xp_earned: session.xpEarned,
          coins_earned: session.coinsEarned,
          started_at: session.startedAt,
          ended_at: session.endedAt,
        });
      } catch (err) {
        console.warn('Supabase session sync deferred:', err);
      }
    }

    return sessions;
  }

  // PROGRESS & STREAKS
  static getProgress(): UserProgress {
    return getLocal<UserProgress>(STORAGE_KEYS.PROGRESS, DEFAULT_PROGRESS);
  }

  static saveProgress(progress: UserProgress): UserProgress {
    setLocal(STORAGE_KEYS.PROGRESS, progress);
    if (supabase) {
      const client = supabase;
      client.auth.getUser().then(({ data }) => {
        if (data.user?.id) {
          client.from('profiles').upsert({
            id: data.user.id,
            xp: progress.xp,
            coins: progress.coins,
            current_streak: progress.currentStreak,
            longest_streak: progress.longestStreak,
            streak_shields: progress.streakShields,
          });
        }
      });
    }
    return progress;
  }

  private static calculateStreak(current: UserProgress): UserProgress {
    const todayStr = new Date().toISOString().split('T')[0];
    if (current.lastActiveDate === todayStr) {
      return current; // already counted today
    }

    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = yesterday.toISOString().split('T')[0];

    let newStreak = current.currentStreak;
    let shields = current.streakShields;

    if (!current.lastActiveDate) {
      newStreak = 1;
    } else if (current.lastActiveDate === yesterdayStr) {
      newStreak += 1;
    } else {
      // Missed 1 or more days: check 2-day monthly forgiveness grace
      const daysMissed = Math.floor(
        (new Date(todayStr).getTime() - new Date(current.lastActiveDate).getTime()) / (1000 * 3600 * 24)
      );

      if (daysMissed <= 2 && shields > 0) {
        // Use grace shield to protect streak!
        shields = Math.max(0, shields - 1);
        newStreak += 1;
      } else {
        // Reset streak
        newStreak = 1;
      }
    }

    return {
      ...current,
      currentStreak: newStreak,
      longestStreak: Math.max(newStreak, current.longestStreak),
      streakShields: shields,
      lastActiveDate: todayStr,
    };
  }

  // CHECK-INS & MEDICATION
  static getCheckIns(): CheckInRecord[] {
    return getLocal<CheckInRecord[]>(STORAGE_KEYS.CHECKINS, []);
  }

  static saveCheckIn(record: CheckInRecord): CheckInRecord[] {
    const records = this.getCheckIns();
    const idx = records.findIndex((r) => r.date === record.date);
    let updated: CheckInRecord[];
    if (idx >= 0) {
      updated = [...records];
      updated[idx] = record;
    } else {
      updated = [record, ...records];
    }
    setLocal(STORAGE_KEYS.CHECKINS, updated);
    return updated;
  }

  // APP SETTINGS
  static getSettings(): AppSettings {
    return getLocal<AppSettings>(STORAGE_KEYS.SETTINGS, DEFAULT_SETTINGS);
  }

  static saveSettings(settings: AppSettings): AppSettings {
    setLocal(STORAGE_KEYS.SETTINGS, settings);
    return settings;
  }

  // DATA BACKUP & EXPORT
  static exportJSON(): string {
    const dump = {
      tasks: this.getTasks(),
      sessions: this.getSessions(),
      progress: this.getProgress(),
      checkIns: this.getCheckIns(),
      settings: this.getSettings(),
      exportedAt: new Date().toISOString(),
      app: 'KoolSkool PWA',
    };
    return JSON.stringify(dump, null, 2);
  }

  static importJSON(jsonString: string): boolean {
    try {
      const data = JSON.parse(jsonString);
      if (data.tasks) setLocal(STORAGE_KEYS.TASKS, data.tasks);
      if (data.sessions) setLocal(STORAGE_KEYS.SESSIONS, data.sessions);
      if (data.progress) setLocal(STORAGE_KEYS.PROGRESS, data.progress);
      if (data.checkIns) setLocal(STORAGE_KEYS.CHECKINS, data.checkIns);
      if (data.settings) setLocal(STORAGE_KEYS.SETTINGS, data.settings);
      return true;
    } catch (e) {
      console.error('Import failed', e);
      return false;
    }
  }
}
