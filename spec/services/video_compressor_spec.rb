require 'rails_helper'

RSpec.describe VideoCompressor do
  let(:input_path)  { '/tmp/input.mp4' }
  let(:output_path) { '/tmp/output.mp4' }

  before do
    # Garante que FileUtils.mkdir_p não falhe
    allow(FileUtils).to receive(:mkdir_p)

    # Permite chamadas reais para outros arquivos (evita erro com gems internas)
    allow(File).to receive(:exist?).and_call_original

    # Garante que verificação de existência do input passe
    allow(File).to receive(:exist?).with(input_path).and_return(true)
  end

  describe '.compress!' do
    context 'when ffmpeg succeeds' do
      before do
        # Mock do sucesso do comando ffmpeg
        status = instance_double(Process::Status, success?: true, exitstatus: 0)
        allow(Open3).to receive(:capture3).and_return(['', '', status])

        # Mock do arquivo de saída sendo gerado
        allow(File).to receive(:exist?).with(output_path).and_return(true)
        allow(File).to receive(:size?).with(output_path).and_return(1024)
      end

      it 'calls ffmpeg with correct arguments and returns output path' do
        result = described_class.compress!(input_path: input_path, output_path: output_path)

        expect(result).to eq(output_path)
        expect(Open3).to have_received(:capture3) do |*args|
          expect(args).to include('ffmpeg')
          expect(args).to include(input_path)
          expect(args).to include(output_path)
        end
      end
    end

    context 'when ffmpeg fails' do
      before do
        status = instance_double(Process::Status, success?: false, exitstatus: 1)
        allow(Open3).to receive(:capture3).and_return(['', 'Error processing', status])
      end

      it 'raises VideoCompressor::Error' do
        expect do
          described_class.compress!(input_path: input_path, output_path: output_path)
        end.to raise_error(VideoCompressor::Error, /ffmpeg falhou \(1\): Error processing/)
      end
    end

    context 'when input file does not exist' do
      before do
        allow(File).to receive(:exist?).with(input_path).and_return(false)
      end

      it 'raises VideoCompressor::Error' do
        expect do
          described_class.compress!(input_path: input_path, output_path: output_path)
        end.to raise_error(VideoCompressor::Error, /Entrada não existe/)
      end
    end
  end
end
