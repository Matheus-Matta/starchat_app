# Policy de autorização Pundit para o modelo Protocol (registro SAC).
# Nomeada ProtocolSacPolicy para evitar conflito com o modelo ProtocolPolicy
# (configuração de geração de códigos), definido em app/models/protocol_policy.rb.
class ProtocolSacPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  # Criação manual: qualquer agente autenticado
  def create?
    account_user.present?
  end

  # Edição de motivo / descrição / problema: qualquer agente autenticado
  def update?
    account_user.present?
  end

  # Arquivamento: apenas administradores
  def destroy?
    account_user&.administrator?
  end
end
