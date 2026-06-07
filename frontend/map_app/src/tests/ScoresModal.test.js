import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import SchoolScores from '../lib/School/SchoolScores.svelte';

describe('SchoolScores Component', () => {
  const baseSchoolData = {
    escola: 'Colégio Estadual do Futuro',
    endereco: 'Av Central, 500',
    co_entidade: '998877',
    nu_ano_censo: '2026',
    data_atualizacao: '2026-01-01T12:00:00Z',
    score_capacidade_atendimento: '2.5', // < 3 -> Vermelho (#ef4444)
    score_infraestrutura: '5.5',         // < 6 -> Amarelo (#eab308)
    score_capacitacao_docente: '7.5',    // < 8 -> Azul (#3b82f6)
    score_diversidade_discente: '9.0',   // >= 8 -> Verde (#22c55e)
  };

  it('deve renderizar os cabeçalhos e metadados da escola corretamente', () => {
    render(SchoolScores, { schoolData: baseSchoolData, averages: null });

    expect(screen.getByText('Colégio Estadual do Futuro')).toBeInTheDocument();
    expect(screen.getByText(/Código: 998877/)).toBeInTheDocument();
    expect(screen.getByText(/Ano: 2026/)).toBeInTheDocument();
  });

  it('deve aplicar as cores corretas nas barras baseado nos ranges das notas', () => {
    const { container } = render(SchoolScores, { schoolData: baseSchoolData, averages: null });

    // Seleciona todas as divs de preenchimento de barra (.bar-fill)
    const bars = container.querySelectorAll('.bar-fill');

    // Nota 2.5 (Vermelho)
    expect(bars[0].style.backgroundColor).toBe('rgb(239, 68, 68)'); // #ef4444 em RGB

    // Nota 5.5 (Amarelo)
    expect(bars[1].style.backgroundColor).toBe('rgb(234, 179, 8)');  // #eab308 em RGB

    // Nota 7.5 (Azul)
    expect(bars[2].style.backgroundColor).toBe('rgb(59, 130, 246)'); // #3b82f6 em RGB

    // Nota 9.0 (Verde)
    expect(bars[3].style.backgroundColor).toBe('rgb(34, 197, 94)');  // #22c55e em RGB
  });

  it('não deve renderizar a seção de médias se o objeto averages for nulo', () => {
    const { container } = render(SchoolScores, { schoolData: baseSchoolData, averages: null });
    const averagesDiv = container.querySelector('.averages');
    expect(averagesDiv).toBeNull();
  });

  it('deve renderizar as médias regionalizadas quando fornecidas', () => {
    const mockAverages = {
      score_capacidade_atendimento: { municipal: 4.2, estadual: 5.1, nacional: 6.0 }
    };

    render(SchoolScores, { schoolData: baseSchoolData, averages: mockAverages });

    expect(screen.getByText('Municipal: 4.2')).toBeInTheDocument();
    expect(screen.getByText('Estadual: 5.1')).toBeInTheDocument();
    expect(screen.getByText('Nacional: 6.0')).toBeInTheDocument();
  });
});
