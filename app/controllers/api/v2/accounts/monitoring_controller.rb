class Api::V2::Accounts::MonitoringController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def show
    builder = Monitoring::OperationalSnapshotBuilder.new(account: Current.account)
    render json: builder.build
  end

  private

  def check_authorization
    authorize :report, :view?
  end
end
