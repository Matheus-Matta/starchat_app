class Crm::Pipedrive::CreateResourceService
  def initialize(account:, params:)
    @account = account
    @params = params
    @hook = @account.hooks.find_by(app_id: 'pipedrive')
  end

  def perform_deal
    return api_error unless client

    # 1. Criar o deal principal
    result = client.create_deal(@params[:deal])
    return result unless result&.dig('success')

    deal_id = result.dig('data', 'id')
    return result unless deal_id

    # 2. Adicionar operações relacionadas (se fornecidas)
    process_deal_followers(deal_id) if @params[:followers].present?
    process_deal_participants(deal_id) if @params[:participants].present?
    process_deal_products(deal_id) if @params[:products].present?
    process_deal_discount(deal_id) if @params[:discount].present?
    process_deal_installment(deal_id) if @params[:installment].present?

    result
  end

  def perform_lead
    return api_error unless client
    client.create_lead(@params[:lead])
  end

  def perform_activity
    return api_error unless client
    client.create_activity(@params[:activity])
  end

  private

  def process_deal_followers(deal_id)
    Array(@params[:followers]).each do |user_id|
      client.add_deal_follower(deal_id: deal_id, user_id: user_id)
    rescue StandardError => e
      Rails.logger.error("Failed to add follower #{user_id}: #{e.message}")
    end
  end

  def process_deal_participants(deal_id)
    Array(@params[:participants]).each do |person_id|
      client.add_deal_participant(deal_id: deal_id, person_id: person_id)
    rescue StandardError => e
      Rails.logger.error("Failed to add participant #{person_id}: #{e.message}")
    end
  end

  def process_deal_products(deal_id)
    items = Array(@params[:products])
    return if items.empty?

    if items.size == 1
      client.add_deal_product(deal_id: deal_id, payload: items.first)
    else
      client.add_deal_products_bulk(deal_id: deal_id, items: items)
    end
  rescue StandardError => e
    Rails.logger.error("Failed to add products: #{e.message}")
  end

  def process_deal_discount(deal_id)
    discount = @params[:discount]
    client.add_deal_discount(
      deal_id: deal_id,
      description: discount[:description],
      amount: discount[:amount],
      type: discount[:type]
    )
  rescue StandardError => e
    Rails.logger.error("Failed to add discount: #{e.message}")
  end

  def process_deal_installment(deal_id)
    installment = @params[:installment]
    client.add_deal_installment(
      deal_id: deal_id,
      description: installment[:description],
      amount: installment[:amount],
      billing_date: installment[:billing_date]
    )
  rescue StandardError => e
    Rails.logger.error("Failed to add installment: #{e.message}")
  end

  def client
    return nil unless @hook&.settings&.dig('api_token')
    @client ||= PipedriveClient.new(base_url: @hook.settings['pipedrive_url'], api_token: @hook.settings['api_token'])
  end

  def api_error
    { error: 'Not connected' }
  end
end
