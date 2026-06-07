/**
 * school.js
 * Módulo para buscar dados de scores de escolas via API
 * Endpoint: /api/school/scores?id=<co_entidade>
 */

/**
 * Busca os scores de uma escola pelo seu código INEP (co_entidade)
 * @param {number|string} id - Código da escola (co_entidade)
 * @returns {Promise<Object>} Objeto com os dados da escola e scores
 * @throws {Error} Lança erro se a requisição falhar ou se a resposta não for ok
 */
export async function fetchSchoolScores(id) {
  if (!id) {
    throw new Error("ID da escola não fornecido");
  }

  const url = `/api/school/scores?id=${encodeURIComponent(id)}`;

  try {
    const response = await fetch(url);

    if (!response.ok) {
      // Tenta extrair mensagem de erro do corpo da resposta, se disponível
      let errorMessage = `Erro ${response.status}: ${response.statusText}`;
      try {
        const errorData = await response.json();
        if (errorData.message) {
          errorMessage = errorData.message;
        }
      } catch {
        // Se não for JSON, mantém a mensagem padrão
      }
      throw new Error(errorMessage);
    }

    const data = await response.json();
    return data;
  } catch (error) {
    // Relançar o erro para que o chamador possa tratá-lo
    throw new Error(`Falha ao buscar scores da escola ${id}: ${error.message}`);
  }
}

/**
 * Exemplo de uso:
 *
 * import { fetchSchoolScores } from './school.js';
 *
 * try {
 *   const scores = await fetchSchoolScores(35245264);
 *   console.log(scores);
 * } catch (err) {
 *   console.error(err.message);
 * }
 */
