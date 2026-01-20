class DocController < ApplicationController
  # Desabilitar autenticação e checks para documentação pública
  skip_before_action :set_current_user
  skip_around_action :handle_with_exception

  # Rate limiting: máximo 60 requisições por minuto por IP
  RATE_LIMIT = 60
  RATE_LIMIT_PERIOD = 1.minute

  def respond
    # Renderizar documentação
    file_path = Rails.root.join('swagger', derived_path)

    # Validar que o arquivo existe e está dentro do diretório swagger
    return head :not_found unless File.exist?(file_path) && file_path.to_s.start_with?(Rails.root.join('swagger').to_s)

    render inline: file_path.read
  end

  private

  def derived_path
    params[:path] ||= 'index.html'
    path = Rack::Utils.clean_path_info(params[:path])
    path << ".#{Rack::Utils.clean_path_info(params[:format])}" unless path.ends_with?(params[:format].to_s)
    path
  end
end
