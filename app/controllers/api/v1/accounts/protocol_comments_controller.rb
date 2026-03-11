class Api::V1::Accounts::ProtocolCommentsController < Api::V1::Accounts::BaseController
  before_action :fetch_protocol
  before_action :fetch_comment, only: [:destroy]
  before_action :check_authorization

  # GET /api/v1/accounts/:account_id/protocols/:protocol_id/comments
  def index
    @comments = @protocol.protocol_comments
                         .includes(:user)
                         .order(created_at: :asc)
    @comments = @comments.public_only unless current_user_can_see_private?
  end

  # POST /api/v1/accounts/:account_id/protocols/:protocol_id/comments
  # Campo `files` (array de arquivos) suportado via ActiveStorage
  def create
    @comment = @protocol.protocol_comments.build(comment_params)
    @comment.account = Current.account
    @comment.user    = Current.user

    # Processa anexos enviados via multipart
    if params[:files].present?
      Array(params[:files]).each do |file|
        @comment.files.attach(file)
      end
    end

    @comment.save!
    render :show, status: :created
  end

  # DELETE /api/v1/accounts/:account_id/protocols/:protocol_id/comments/:id
  def destroy
    @comment.destroy!
    head :ok
  end

  private

  def fetch_protocol
    @protocol = Current.account.protocols.find(params[:protocol_id])
  end

  def fetch_comment
    @comment = @protocol.protocol_comments.find(params[:id])
  end

  def check_authorization
    authorize @protocol, :update?, policy_class: ProtocolSacPolicy
  end

  def current_user_can_see_private?
    # Administradores e agentes com permissão protocols.manage visualizam comentários privados
    Current.account_user&.administrator? || Current.account_user&.has_permission?('protocols.manage')
  end

  def comment_params
    params.require(:protocol_comment).permit(:content, :is_private)
  end
end
