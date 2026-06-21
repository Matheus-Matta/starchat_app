class Companies::ExportXlsxService < Companies::BaseExportService
  def generate
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: 'Companies') do |sheet|
      sheet.add_row headers
      rows.each { |row| sheet.add_row row }
    end
    stream = package.to_stream
    stream.rewind
    stream.read
  end
end
