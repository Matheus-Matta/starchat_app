class Api::V1::Accounts::ProtocolsController < Api::V1::Accounts::BaseController
  before_action :fetch_protocol, only: [:show, :update, :destroy, :close, :reopen]
  before_action :check_authorization

  # GET /api/v1/accounts/:account_id/protocols
  # Parâmetros opcionais: contact_id, protocol_policy_id, status, q (busca por código)
  def index
    @protocols = Current.account.protocols
                        .includes(:contact, :protocol_policy, :conversations, :protocol_comments)
    @protocols = @protocols.where(contact_id: params[:contact_id])               if params[:contact_id].present?
    @protocols = @protocols.where(protocol_policy_id: params[:protocol_policy_id]) if params[:protocol_policy_id].present?
    @protocols = @protocols.where(status: params[:status])                        if params[:status].present?
    @protocols = @protocols.where('code ILIKE ?', "%#{params[:q]}%")              if params[:q].present?
    @protocols = @protocols.order(created_at: :desc).page(params[:page]).per(25)
  end

  # GET /api/v1/accounts/:account_id/protocols/:id
  def show
  end

  # POST /api/v1/accounts/:account_id/protocols
  # Permite criar um protocolo manualmente (ex.: abertura retroativa, migração)
  def create
    @protocol = Current.account.protocols.create!(protocol_params)
    render :show
  end

  # PATCH /api/v1/accounts/:account_id/protocols/:id
  # Agente pode editar: motivo, descrição, problema, razão
  def update
    @protocol.update!(protocol_params)
    render :show
  end

  # DELETE /api/v1/accounts/:account_id/protocols/:id
  # Arquiva o protocolo (não remove do banco)
  def destroy
    @protocol.update!(status: :archived)
    head :ok
  end

  # POST /api/v1/accounts/:account_id/protocols/:id/close
  def close
    @protocol.close!
    render :show
  end

  # POST /api/v1/accounts/:account_id/protocols/:id/reopen
  def reopen
    @protocol.reopen!
    render :show
  end

  private

  def fetch_protocol
    @protocol = Current.account.protocols.find(params[:id])
  end

  def check_authorization
    authorize(@protocol || Protocol, policy_class: ProtocolSacPolicy)
  end

  def protocol_params
    params.require(:protocol).permit(
      :contact_id,
      :conversation_id,
      :protocol_policy_id,
      :reason,
      :description,
      :problem,
      :status
    )
  end
end
