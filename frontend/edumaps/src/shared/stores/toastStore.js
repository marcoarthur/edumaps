// src/shared/stores/toastStore.js
import { BehaviorSubject } from 'rxjs';
import { uuid } from '@/shared/utils/uuid.js';

const DEFAULT_DURATION = 4000; // ms

const toastSubject = new BehaviorSubject([]);

export const toast$ = toastSubject.asObservable();

/**
 * Adiciona um toast
 * @param {string} message
 * @param {'info'|'success'|'warning'|'error'} type
 * @param {number} duration - em ms
 */
export function addToast(message, type = 'info', duration = DEFAULT_DURATION) {
  const id = uuid();
  const toast = { id, message, type, duration };

  const current = toastSubject.getValue();
  toastSubject.next([...current, toast]);

  // Auto-remover após duração
  setTimeout(() => {
    removeToast(id);
  }, duration);
}

export function removeToast(id) {
  const current = toastSubject.getValue();
  toastSubject.next(current.filter(t => t.id !== id));
}

export function clearAllToasts() {
  toastSubject.next([]);
}
