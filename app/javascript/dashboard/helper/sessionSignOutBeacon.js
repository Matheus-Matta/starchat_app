/**
 * sessionSignOutBeacon.js
 *
 * Detecta quando o usuário fecha a aba ou o navegador (evento `pagehide`)
 * e envia um sinal de logout com reason=browser_closed para o servidor,
 * usando `fetch` com `keepalive: true` (garante envio mesmo com a aba fechando).
 *
 * Evita duplo registro:
 *  - Se o usuário clicou explicitamente em "Sair", auth.js seta
 *    sessionStorage['cw_explicit_logout'], e o handler abaixo o ignora.
 *  - Se `event.persisted = true`, a página foi para o bfcache (back-forward cache)
 *    e o usuário pode voltar — não registramos como fechamento.
 */

/**
 * Lê os headers de autenticação do DeviseTokenAuth a partir do cookie
 * `cw_d_session_info` que o frontend persiste após cada resposta autenticada.
 * @returns {Object|null} headers de autenticação ou null se não autenticado
 */
function getAuthHeaders() {
  try {
    const cookieEntry = document.cookie
      .split('; ')
      .find(row => row.startsWith('cw_d_session_info='));

    if (!cookieEntry) return null;

    const jsonStr = decodeURIComponent(
      cookieEntry.split('=').slice(1).join('=')
    );
    const headers = JSON.parse(jsonStr);

    if (!headers['access-token'] || !headers.uid) return null;

    return {
      'access-token': headers['access-token'],
      'token-type': headers['token-type'] || 'Bearer',
      client: headers.client,
      uid: headers.uid,
    };
  } catch {
    return null;
  }
}

/**
 * Handler do evento `pagehide`.
 * Enviado quando:
 *  - A aba é fechada
 *  - O navegador é fechado
 *  - O usuário navega para outro domínio (raro em SPA)
 *  - Atualização de página (F5) — neste caso é um falso-positivo aceitável;
 *    o backend usa o campo `logout_reason` para filtragem futura se necessário.
 */
function handlePageHide(event) {
  // Página foi para o bfcache — usuário pode voltar com o botão Voltar
  if (event.persisted) return;

  // Logout explícito já tratado pelo auth.js — evita duplo registro
  if (sessionStorage.getItem('cw_explicit_logout') === 'true') {
    sessionStorage.removeItem('cw_explicit_logout');
    return;
  }

  const authHeaders = getAuthHeaders();
  if (!authHeaders) return; // Usuário não está autenticado

  // fetch com keepalive=true garante que o request será enviado
  // mesmo com a página sendo descarregada
  fetch('/auth/sign_out?logout_reason=browser_closed', {
    method: 'DELETE',
    keepalive: true,
    headers: {
      'Content-Type': 'application/json',
      ...authHeaders,
    },
  }).catch(() => {
    // Ignoramos erros — o browser pode já ter bloqueado requests
  });
}

/**
 * Inicializa o listener de fechamento de sessão por fechamento de aba/navegador.
 * Deve ser chamado uma única vez, no App.vue mounted().
 */
export function initSessionSignOutBeacon() {
  window.addEventListener('pagehide', handlePageHide);
}

/**
 * Remove o listener. Útil em testes ou se o componente for desmontado.
 */
export function destroySessionSignOutBeacon() {
  window.removeEventListener('pagehide', handlePageHide);
}
