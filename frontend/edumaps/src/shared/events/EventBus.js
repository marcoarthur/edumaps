// src/shared/events/EventBus.js
//
// Barramento de eventos da aplicação: comunicação entre features sem que
// elas se importem diretamente (ex.: SchoolSearchForm dispara SEARCH, e
// uma página de resultados ou o mapa reagem, sem se conhecerem).
//
// Decisão de design (revisão de uma proposta baseada em RxJS): a API
// pública é callback-based (`on(type, handler) -> unsubscribe`), não
// devolve Observable. Um Observable devolvido por `on()` ainda vaza a
// FORMA de um stream reativo pros componentes (eles precisam saber
// `.subscribe()`, `.pipe()`...) — "esconder a implementação" só é
// alcançado de verdade com uma API de função simples. Por isso o motor
// interno também não usa RxJS: um registro Map<tipo, Set<handler>> + um
// pipeline de middlewares cobre tudo que as Fases 1/2 precisam, sem
// dependência externa. Se um dia for preciso compor eventos com
// operadores (debounce, buffer, switchMap), o motor interno pode trocar
// para RxJS sem que nenhum componente perceba — a troca fica isolada
// aqui dentro.

/**
 * @typedef {Object} BusEvent
 * @property {string} id - identificador único do evento (crypto.randomUUID)
 * @property {string} type
 * @property {*} payload
 * @property {number} timestamp - Date.now()
 * @property {string|null} source - quem emitiu, se informado por quem chamou emit()
 */

/**
 * @callback EventHandler
 * @param {*} payload
 * @param {BusEvent} event - evento completo, para quem precisar de metadados
 */

/**
 * @callback Middleware
 * @param {BusEvent} event
 * @param {(event: BusEvent) => void} next - chame para continuar o pipeline;
 *   não chamar cancela o evento (ele nunca chega aos handlers)
 */

export class EventBus {
  /** @type {Map<string, Set<EventHandler>>} */
  #handlers = new Map();

  /** @type {Set<EventHandler>} */
  #anyHandlers = new Set();

  /** @type {Middleware[]} */
  #middlewares = [];

  /** @type {Map<string, (payload: *) => (Promise<*>|*)>} */
  #commandHandlers = new Map();

  #destroyed = false;

  /**
   * Emite um evento para todos os handlers registrados em `type` (e para
   * os handlers de `onAny`), passando antes pelo pipeline de middlewares.
   *
   * @param {string} type
   * @param {*} [payload]
   * @param {{ source?: string }} [options] - `source` é informativo (ex.:
   *   nome do componente que emitiu) — não é detectado automaticamente,
   *   precisa ser passado explicitamente por quem emite.
   */
  emit(type, payload = undefined, { source = null } = {}) {
    this.#assertNotDestroyed();

    /** @type {BusEvent} */
    const event = {
      id: crypto.randomUUID(),
      type,
      payload,
      timestamp: Date.now(),
      source,
    };

    this.#warnIfOrphanEvent(event);

    this.#runMiddlewares(event, (finalEvent) => this.#dispatch(finalEvent));
  }

  /**
   * Registra um handler para um tipo de evento específico.
   * @param {string} type
   * @param {EventHandler} handler
   * @returns {() => void} função de cancelamento
   */
  on(type, handler) {
    this.#assertNotDestroyed();
    if (!this.#handlers.has(type)) {
      this.#handlers.set(type, new Set());
    }
    this.#handlers.get(type).add(handler);

    return () => {
      this.#handlers.get(type)?.delete(handler);
    };
  }

  /**
   * Como `on()`, mas o handler é removido automaticamente após a primeira
   * ocorrência do evento.
   * @param {string} type
   * @param {EventHandler} handler
   * @returns {() => void}
   */
  once(type, handler) {
    const unsubscribe = this.on(type, (payload, event) => {
      unsubscribe();
      handler(payload, event);
    });
    return unsubscribe;
  }

  /**
   * Registra um handler que recebe TODOS os eventos, de qualquer tipo.
   * Uso típico: telemetria/debug que só observa, sem bloquear/alterar o
   * evento (para isso, ver `use()`).
   * @param {EventHandler} handler
   * @returns {() => void}
   */
  onAny(handler) {
    this.#assertNotDestroyed();
    this.#anyHandlers.add(handler);
    return () => this.#anyHandlers.delete(handler);
  }

  /**
   * Registra um middleware no pipeline. Middlewares rodam em ordem de
   * registro, antes de qualquer handler, e podem:
   *  - transformar o evento (mutar `event.payload` e chamar `next(event)`)
   *  - bloquear o evento (não chamar `next`) — ex.: permissionChecker
   *  - só observar e repassar (ex.: logger)
   *
   * @param {Middleware} middleware
   * @returns {() => void} remove o middleware
   */
  use(middleware) {
    this.#assertNotDestroyed();
    this.#middlewares.push(middleware);
    return () => {
      this.#middlewares = this.#middlewares.filter((m) => m !== middleware);
    };
  }

  /**
   * Resolve numa Promise assim que o evento `type` ocorrer. Útil em
   * testes ("espere o SEARCH acontecer") e em fluxos que precisam do
   * próximo evento de um tipo. Rejeita se `timeoutMs` passar sem o
   * evento ocorrer — evita testes/fluxos travados esperando pra sempre.
   *
   * @param {string} type
   * @param {{ timeoutMs?: number }} [options]
   * @returns {Promise<*>} resolve com o payload do evento
   */
  waitFor(type, { timeoutMs = 5000 } = {}) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        unsubscribe();
        reject(new Error(`waitFor("${type}") expirou após ${timeoutMs}ms`));
      }, timeoutMs);

      const unsubscribe = this.once(type, (payload) => {
        clearTimeout(timer);
        resolve(payload);
      });
    });
  }

  // ==========================================================
  // Comandos (request/reply) — Fase 3 da proposta original.
  //
  // Diferença deliberada em relação a eventos: um evento é um FATO
  // ("SEARCH aconteceu") e pode ter 0..N ouvintes. Um comando é uma
  // INTENÇÃO com resposta ("execute a busca, me diga o resultado") e
  // tem exatamente UM handler. Por isso não reaproveitamos o pipeline
  // de emit/on com correlation-id — isso permitiria 0 ou várias
  // respostas para o mesmo comando e criaria condição de corrida. Um
  // registro dedicado comando -> handler deixa o contrato explícito e
  // falha alto (erro imediato) se estiver mal configurado.
  // ==========================================================

  /**
   * Registra o (único) handler de um comando.
   * @param {string} command
   * @param {(payload: *) => (Promise<*>|*)} handler
   * @returns {() => void} remove o handler
   */
  handle(command, handler) {
    this.#assertNotDestroyed();
    if (this.#commandHandlers.has(command)) {
      throw new Error(`Já existe um handler registrado para o comando "${command}"`);
    }
    this.#commandHandlers.set(command, handler);
    return () => this.#commandHandlers.delete(command);
  }

  /**
   * Executa um comando e aguarda o resultado do handler registrado.
   * @param {string} command
   * @param {*} [payload]
   * @returns {Promise<*>}
   */
  async request(command, payload = undefined) {
    this.#assertNotDestroyed();
    const handler = this.#commandHandlers.get(command);
    if (!handler) {
      throw new Error(`Nenhum handler registrado para o comando "${command}"`);
    }
    return handler(payload);
  }

  /**
   * Remove todos os handlers, middlewares e handlers de comando. Depois
   * de destruído, o bus não aceita mais emit/on/use/handle (lança erro).
   * Uso típico: afterEach() de testes, ou reset de sessão/logout.
   */
  destroy() {
    this.#handlers.clear();
    this.#anyHandlers.clear();
    this.#middlewares = [];
    this.#commandHandlers.clear();
    this.#destroyed = true;
  }

  // ==========================================================
  // Privado
  // ==========================================================
  #runMiddlewares(event, onComplete) {
    let index = -1;

    const next = (currentEvent) => {
      index += 1;
      const middleware = this.#middlewares[index];
      if (!middleware) {
        onComplete(currentEvent);
        return;
      }
      try {
        middleware(currentEvent, next);
      } catch (error) {
        // Um middleware quebrado interrompe o pipeline deste evento (não
        // chama next), mas não derruba o resto da aplicação nem os
        // outros eventos.
        console.error(`[EventBus] middleware lançou erro para "${currentEvent.type}":`, error);
      }
    };

    next(event);
  }

  #dispatch(event) {
    const handlers = this.#handlers.get(event.type);
    if (handlers) {
      for (const handler of handlers) {
        this.#safeCall(handler, event);
      }
    }
    for (const handler of this.#anyHandlers) {
      this.#safeCall(handler, event);
    }
  }

  #safeCall(handler, event) {
    try {
      handler(event.payload, event);
    } catch (error) {
      // Um handler quebrado não deve impedir os demais handlers do mesmo
      // evento de rodar.
      console.error(`[EventBus] handler lançou erro para "${event.type}":`, error);
    }
  }

  /**
   * Aviso de desenvolvimento: emitir um evento que ninguém escuta não é
   * um erro (fire-and-forget é válido — nem todo evento precisa de
   * consumidor), mas é o tipo de engano fácil de não perceber (ex.: uma
   * ponte de inicialização que não foi registrada) e que não deixa
   * nenhum rastro no console por padrão. Isso te avisa sem quebrar nada.
   */
  #warnIfOrphanEvent(event) {
    if (!(import.meta.env?.DEV ?? true)) return;
    const hasSpecificHandlers = (this.#handlers.get(event.type)?.size ?? 0) > 0;
    const hasCatchAllHandlers = this.#anyHandlers.size > 0;
    if (!hasSpecificHandlers && !hasCatchAllHandlers) {
      console.warn(
        `[EventBus] emit("${event.type}") não tem nenhum handler registrado — ` +
          `o evento foi descartado. Se isso for esperado, ignore; se não, ` +
          `confira se o listener/ponte correspondente foi registrado.`
      );
    }
  }

  #assertNotDestroyed() {
    if (this.#destroyed) {
      throw new Error("EventBus já foi destruído (destroy() foi chamado)");
    }
  }
}

/**
 * Instância única usada pela aplicação. Features importam esta instância
 * em vez de criar seu próprio EventBus, para todas conversarem pelo
 * mesmo barramento. Em testes, prefira `new EventBus()` isolado (ver
 * EventBus.test.js) em vez desta instância global.
 */
export const eventBus = new EventBus();
