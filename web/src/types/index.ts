export type EnergyState = 'low' | 'medium' | 'high';

export interface FocusTask {
  id: string;
  user_id?: string;
  title: string;
  notes?: string;
  nextStep?: string;
  estimateMinutes: number;
  resistanceRating: number; // 1 to 5
  isPinned: boolean;
  isCompleted: boolean;
  completedAt?: string;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

export interface FocusSession {
  id: string;
  user_id?: string;
  taskId?: string;
  durationSeconds: number;
  actualSeconds: number;
  completedNaturally: boolean;
  xpEarned: number;
  coinsEarned: number;
  startedAt: string;
  endedAt: string;
}

export interface UserProgress {
  xp: number;
  coins: number;
  currentStreak: number;
  longestStreak: number;
  streakShields: number;
  lastActiveDate?: string;
}

export interface CheckInRecord {
  id: string;
  user_id?: string;
  energyState: EnergyState;
  medicationTaken: boolean;
  medicationTakenAt?: string;
  reflectionNote?: string;
  date: string; // YYYY-MM-DD
  createdAt: string;
}

export interface AppSettings {
  medicationTrackingEnabled: boolean;
  soundscapeVolume: number; // 0 to 1
  selectedSoundscape: 'brown_noise' | 'warm_rain' | 'gentle_stream' | 'none';
  tradition: 'secular' | 'mindful' | 'grounding';
  notificationsEnabled: boolean;
}

export interface StillnessPractice {
  id: string;
  title: string;
  subtitle: string;
  durationSeconds: number;
  category: 'breath' | 'grounding' | 'release';
  steps: string[];
}
