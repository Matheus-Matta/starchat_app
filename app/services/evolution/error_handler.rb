# frozen_string_literal: true

module Evolution
  class ErrorHandler
    PHONE_NOT_FOUND_PATTERNS = [
      /phone.*not.*exist/i,
      /number.*not.*found/i,
      /invalid.*number/i,
      /numero.*não.*existe/i,
      /telefone.*invalido/i,
      /not.*registered/i,
      /participant.*not.*found/i
    ].freeze

    CONNECTION_ERROR_PATTERNS = [
      /connection.*refused/i,
      /timeout/i,
      /network.*error/i,
      /unable.*to.*connect/i,
      /socket.*error/i,
      /offline/i
    ].freeze

    MEDIA_ERROR_PATTERNS = [
      /media.*too.*large/i,
      /file.*size.*exceeded/i,
      /invalid.*media/i,
      /unsupported.*format/i,
      /arquivo.*muito.*grande/i
    ].freeze

    class << self
      def handle_send_error(error)
        error_message = extract_error_message(error)
        error_type = classify_error(error_message)

        {
          user_message: user_friendly_message(error_type),
          error_type: error_type,
          technical_message: error_message
        }
      end

      private

      def extract_error_message(error)
        return error.message if error.respond_to?(:message)
        return error.to_s if error.is_a?(String)

        'Unknown error'
      end

      def classify_error(message)
        return :phone_not_found if matches_patterns?(message, PHONE_NOT_FOUND_PATTERNS)
        return :connection_error if matches_patterns?(message, CONNECTION_ERROR_PATTERNS)
        return :media_error if matches_patterns?(message, MEDIA_ERROR_PATTERNS)

        :generic_error
      end

      def matches_patterns?(message, patterns)
        patterns.any? { |pattern| pattern.match?(message) }
      end

      def user_friendly_message(error_type)
        case error_type
        when :phone_not_found
          I18n.t('errors.evolution.phone_not_found',
                 default: 'Erro ao enviar mensagem. Este número pode não existir no WhatsApp.')
        when :connection_error
          I18n.t('errors.evolution.connection_error',
                 default: 'Erro de conexão. Verifique sua conexão e tente novamente.')
        when :media_error
          I18n.t('errors.evolution.media_error',
                 default: 'Erro ao enviar arquivo. Verifique o tamanho e formato do arquivo.')
        else
          I18n.t('errors.evolution.generic',
                 default: 'Erro ao enviar mensagem. Tente novamente.')
        end
      end
    end
  end
end
