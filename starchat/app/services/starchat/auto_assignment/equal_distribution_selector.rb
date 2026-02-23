# Seleciona o agente com menor carga dentro de uma janela de tempo, mas com
# fallback inteligente para round-robin quando as cargas estão próximas.
#
# Configurado por inbox via InboxAssignmentPolicy:
#   equal_distribution_enabled           → liga/desliga por inbox
#   equal_distribution_window_hours      → janela de tempo para contar conversas abertas
#   equal_distribution_balance_threshold → limiar de dispersão em % (0‒100)
#
# Algoritmo de dispersão:
#   1. Conta conversas abertas de cada agente dentro da janela
#   2. Calcula spread_pct = (max - min) / max * 100
#   3. Se spread_pct <= balance_threshold → cargas parecidas → usa round-robin
#   4. Se spread_pct >  balance_threshold → desequilíbrio → seleciona agente com min carga
#
# Exemplos com threshold=20:
#   agente1=20, agente2=30, agente3=5  → spread=(30-5)/30*100=83% > 20 → equal  → seleciona agente3
#   agente1=10, agente2=11, agente3=12 → spread=(12-10)/12*100=17% ≤ 20 → round-robin
#   agente1=8,  agente2=14             → spread=(14-8)/14*100=43% > 20  → equal  → seleciona agente1
class Starchat::AutoAssignment::EqualDistributionSelector
  pattr_initialize [:inbox!, :window_hours!, :balance_threshold!, :round_robin_fallback!]

  # Recebe um array de InboxMember e retorna o User selecionado.
  def select_agent(available_agents)
    return nil if available_agents.empty?
    return available_agents.first.user if available_agents.size == 1

    agent_users = available_agents.map(&:user)
    counts = fetch_open_conversation_counts(agent_users)

    if balanced_enough?(counts)
      # Dispersão dentro do limiar → delega ao round-robin para não forçar redistribuição
      round_robin_fallback.select_agent(available_agents)
    else
      # Desequilíbrio detectado → agente com maior ociosidade recente
      agent_users.min_by { |user| counts[user.id] }
    end
  end

  private

  # Retorna true quando a dispersão de carga está dentro do limiar configurado.
  # Se todos estão empatados (todos zero ou spread <= threshold), usa round-robin.
  def balanced_enough?(counts)
    return true if counts.values.all?(&:zero?) # empate total → round-robin

    max = counts.values.max
    min = counts.values.min
    return true if max.zero? # segurança extra

    spread_pct = (max - min).to_f / max * 100
    spread_pct <= balance_threshold
  end

  # Conta conversas abertas por agente na inbox dentro da janela de tempo.
  # Se window_hours for 0 ou negativo, conta todas sem filtro de tempo.
  def fetch_open_conversation_counts(users)
    user_ids = users.map(&:id)

    scope = inbox.conversations
                 .open
                 .where(assignee_id: user_ids)

    scope = scope.where('conversations.created_at >= ?', window_hours.hours.ago) if window_hours.positive?

    counts = scope.group(:assignee_id).count

    # Agentes sem conversas retornam 0 explicitamente
    user_ids.each_with_object(Hash.new(0)) do |id, hash|
      hash[id] = counts[id] || 0
    end
  end
end
