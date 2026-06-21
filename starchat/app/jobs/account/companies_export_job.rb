class Account::CompaniesExportJob < ApplicationJob
  queue_as :low

  def perform(account_id, user_id, params, format = 'csv')
    @account = Account.find(account_id)
    @account_user = @account.users.find(user_id)

    if format == 'xlsx'
      data = Companies::ExportXlsxService.new(@account, params).generate
      attach_file(data, "#{@account.name}_#{@account.id}_companies.xlsx",
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    else
      data = Companies::ExportCsvService.new(@account, params).generate
      attach_file(data, "#{@account.name}_#{@account.id}_companies.csv", 'text/csv')
    end

    send_mail
  end

  private

  def attach_file(data, filename, content_type)
    return if data.blank?

    @account.companies_export.attach(
      io: StringIO.new(data),
      filename: filename,
      content_type: content_type
    )
  end

  def send_mail
    file_url = Rails.application.routes.url_helpers.rails_blob_url(@account.companies_export)
    mailer = AdministratorNotifications::AccountNotificationMailer.with(account: @account)
    mailer.company_export_complete(file_url, @account_user.email)&.deliver_later
  end
end
