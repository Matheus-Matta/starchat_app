require 'administrate/field/base'

class AccountLimitsField < Administrate::Field::Base
  def to_s
    data.present? ? data.to_json : { agents: nil, inboxes: nil, cosmos_::responses: nil, cosmos_::documents: nil }.to_json
  end
end
