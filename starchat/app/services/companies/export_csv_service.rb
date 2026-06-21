class Companies::ExportCsvService < Companies::BaseExportService
  def generate
    bom = "\xEF\xBB\xBF"
    csv_data = CSV.generate do |csv|
      csv << headers
      rows.each { |row| csv << row }
    end
    "#{bom}#{csv_data}"
  end
end
