<!-- src/features/chat/components/ChatCalendar.svelte -->
<script>
  import { onMount } from "svelte";

  /**
   * @param {Object<string, number>} diasComConversa - Mapa "YYYY-MM-DD" -> count
   * @param {string} selectedDate - Data selecionada "YYYY-MM-DD"
   * @param {Function} onSelect - Callback (date) quando clica num dia
   * @param {Date} currentMonth - Mês atual exibido
   * @param {Function} onMonthChange - Callback (Date) quando muda o mês
   */
  let {
    diasComConversa = {},
    selectedDate = "",
    onSelect = () => {},
    currentMonth = new Date(),
    onMonthChange = () => {},
  } = $props();

  let weeks = $state([]);

  function buildCalendar() {
    const year = currentMonth.getFullYear();
    const month = currentMonth.getMonth();
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    const startDay = firstDay.getDay(); // 0 = domingo
    const daysInMonth = lastDay.getDate();

    const prevMonthLastDay = new Date(year, month, 0).getDate();
    const newWeeks = [];
    let week = [];

    // Dias do mês anterior (para preencher a primeira semana)
    for (let i = startDay - 1; i >= 0; i--) {
      const day = prevMonthLastDay - i;
      const date = new Date(year, month - 1, day);
      const key = date.toISOString().split("T")[0];
      week.push({ day, date, isCurrentMonth: false, hasConversa: !!diasComConversa[key], count: diasComConversa[key] || 0 });
    }

    // Dias do mês atual
    for (let day = 1; day <= daysInMonth; day++) {
      const date = new Date(year, month, day);
      const key = date.toISOString().split("T")[0];
      week.push({ day, date, isCurrentMonth: true, hasConversa: !!diasComConversa[key], count: diasComConversa[key] || 0, isSelected: key === selectedDate });
      if (week.length === 7) {
        newWeeks.push(week);
        week = [];
      }
    }

    // Dias do próximo mês (para completar a última semana)
    let nextDay = 1;
    while (week.length < 7) {
      const date = new Date(year, month + 1, nextDay);
      const key = date.toISOString().split("T")[0];
      week.push({ day: nextDay, date, isCurrentMonth: false, hasConversa: !!diasComConversa[key], count: diasComConversa[key] || 0 });
      nextDay++;
    }
    if (week.length > 0) newWeeks.push(week);

    weeks = newWeeks;
  }

  $effect(buildCalendar());

  function handleDayClick(dayInfo) {
    if (!dayInfo.isCurrentMonth) return;
    const key = dayInfo.date.toISOString().split("T")[0];
    onSelect(key);
  }

  function prevMonth() {
    onMonthChange(new Date(currentMonth.getFullYear(), currentMonth.getMonth() - 1, 1));
  }

  function nextMonth() {
    onMonthChange(new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 1));
  }

  const monthNames = [
    "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
    "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
  ];
</script>

<div class="bg-white rounded-lg border border-gray-200 p-4">
  <div class="flex items-center justify-between mb-4">
    <button onclick={prevMonth} class="p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-md transition-colors" aria-label="Mês anterior">
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path></svg>
    </button>
    <h3 class="font-semibold text-gray-900">{monthNames[currentMonth.getMonth()]} {currentMonth.getFullYear()}</h3>
    <button onclick={nextMonth} class="p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-md transition-colors" aria-label="Próximo mês">
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
    </button>
  </div>

  <div class="grid grid-cols-7 gap-1 mb-2">
    {#each ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"] as dia}
      <div class="text-center text-xs font-medium text-gray-500 py-1">{dia}</div>
    {/each}
  </div>

  <div class="grid grid-cols-7 gap-1">
    {#each weeks as week}
      {#each week as dayInfo}
        <button
          class="relative aspect-square text-sm font-medium rounded-md transition-colors
            {dayInfo.isCurrentMonth ? 'text-gray-900 hover:bg-blue-50' : 'text-gray-300'}
            {dayInfo.hasConversa ? 'bg-blue-50 font-semibold' : ''}
            {dayInfo.isSelected ? 'bg-blue-600 text-white' : ''}"
          onclick={() => handleDayClick(dayInfo)}
          disabled={!dayInfo.isCurrentMonth}
          aria-label={dayInfo.hasConversa ? `${dayInfo.day} - ${dayInfo.count} conversa(s)` : dayInfo.day}
        >
          {dayInfo.day}
          {#if dayInfo.hasConversa}
            <span class="absolute bottom-1 right-1 text-xs bg-blue-600 text-white rounded-full px-1">{dayInfo.count}</span>
          {/if}
        </button>
      {/each}
    {/each}
  </div>

  <p class="mt-3 text-xs text-gray-500 text-center">
    Dias com ponto azul indicam dias com conversas salvas. Clique para filtrar.
  </p>
</div>