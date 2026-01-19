# frozen_string_literal: true

require 'open3'
require 'fileutils'

module VideoCompressor
  class Error < StandardError; end

  def self.compress!(input_path:, output_path:, crf: 23, preset: 'veryfast')
    raise Error, "Entrada não existe: #{input_path}" unless File.exist?(input_path)

    FileUtils.mkdir_p(File.dirname(output_path))

    # Reduzindo CRF para 23 (padrão do Youtube/Web) para garantir compressão
    # Preset veryfast é bom para realtime.
    cmd = [
      'ffmpeg', '-y',
      '-i', input_path,
      '-c:v', 'libx264',
      '-preset', preset,
      '-crf', crf.to_s,
      '-pix_fmt', 'yuv420p',
      '-profile:v', 'high',
      '-level', '4.1',
      '-c:a', 'aac',
      '-b:a', '128k',
      '-movflags', '+faststart',
      output_path
    ]

    _stdout, stderr, status = Open3.capture3(*cmd)

    unless status.success?
      # Tenta capturar erro específico ou retorna genérico
      raise Error, "ffmpeg falhou (#{status.exitstatus}): #{stderr}"
    end

    raise Error, "Saída não gerada: #{output_path}" unless File.exist?(output_path) && File.size?(output_path)

    output_path
  end
end
