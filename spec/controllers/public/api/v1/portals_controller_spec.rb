require 'rails_helper'

RSpec.describe Public::Api::V1::PortalsController, type: :request do
  let!(:account) { create(:account) }
  let!(:agent) { create(:user, account: account, role: :agent) }
  let!(:portal) { create(:portal, slug: 'test-portal', account_id: account.id, custom_domain: 'www.example.com') }

  before do
    create(:portal, slug: 'test-portal-1', account_id: account.id)
    create(:portal, slug: 'test-portal-2', account_id: account.id)
    create_list(:article, 3, account: account, author: agent, portal: portal, status: :published)
    create_list(:article, 2, account: account, author: agent, portal: portal, status: :draft)
  end

  describe 'GET /public/api/v1/portals/{portal_slug}' do
    it 'Show portal and categories belonging to the portal' do
      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
    end

    it 'Throws unauthorised error for unknown domain' do
      portal.update(custom_domain: 'www.something.com')

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:unauthorized)
      json_response = response.parsed_body

      expect(json_response['error']).to eql "Domain: www.example.com is not registered with us. \
      Please send us an email at support@starchats.com.br with the custom domain name and account API key"
    end

    context 'when portal has a logo' do
      it 'includes the logo as favicon' do
        # Attach a test image to the portal
        file = Rails.root.join('spec/assets/sample.png').open
        portal.logo.attach(io: file, filename: 'sample.png', content_type: 'image/png')
        file.close

        get "/hc/#{portal.slug}/en"

        expect(response).to have_http_status(:success)
        expect(response.body).to include('<link rel="icon" href=')
      end
    end

    context 'when portal has no logo' do
      it 'does not include a favicon link' do
        # Ensure logo is not attached
        portal.logo.purge if portal.logo.attached?

        get "/hc/#{portal.slug}/en"

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('<link rel="icon" href=')
      end
    end
  end

  describe 'GET /public/api/v1/portals/{portal_slug}/{locale} recommended content' do
    let(:category_a) { create(:category, portal: portal, account: account, name: 'Getting Started', locale: 'en') }
    let(:category_b) { create(:category, portal: portal, account: account, name: 'Billing', locale: 'en') }
    let(:alpha) { create(:article, account: account, author: agent, portal: portal, locale: 'en', status: :published, title: 'Alpha Guide') }
    let(:beta) { create(:article, account: account, author: agent, portal: portal, locale: 'en', status: :published, title: 'Beta Guide') }
    let(:gamma) { create(:article, account: account, author: agent, portal: portal, locale: 'en', status: :published, title: 'Gamma Guide') }

    it 'renders recommended articles in the configured order' do
      portal.update!(config: { allowed_locales: %w[en], default_locale: 'en',
                               popular_content: { 'en' => { 'article_ids' => [gamma.id, alpha.id] } } })

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Recommended articles')
      expect(response.body.index('Gamma Guide')).to be < response.body.index('Alpha Guide')
    end

    it 'drops draft and other-locale ids from the recommended articles' do
      draft = create(:article, account: account, author: agent, portal: portal, locale: 'en', status: :draft, title: 'Draft Secret')
      spanish = create(:article, account: account, author: agent, portal: portal, locale: 'es', status: :published, title: 'Spanish Only')
      portal.update!(config: { allowed_locales: %w[en es], default_locale: 'en',
                               popular_content: { 'en' => { 'article_ids' => [alpha.id, draft.id, spanish.id] } } })

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Alpha Guide')
      expect(response.body).not_to include('Draft Secret')
      expect(response.body).not_to include('Spanish Only')
    end

    it 'does not leak one locale\'s recommendations into another' do
      portal.update!(config: { allowed_locales: %w[en es], default_locale: 'en',
                               popular_content: { 'es' => { 'article_ids' => [alpha.id] } } })

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('Recommended articles')
    end

    it 'renders recommended categories as hero pills in the configured order' do
      portal.update!(config: { allowed_locales: %w[en], default_locale: 'en',
                               popular_content: { 'en' => { 'category_ids' => [category_b.id, category_a.id] } } })

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('recommended-pill')
      expect(response.body).to include('Getting Started', 'Billing')
      expect(response.body.index('Billing')).to be < response.body.index('Getting Started')
    end

    it 'falls back to featured articles when no recommendations are configured' do
      create_list(:article, 6, account: account, author: agent, portal: portal, locale: 'en', status: :published, category: category_a)

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Featured Articles')
      expect(response.body).not_to include('Recommended articles')
    end

    it 'renders recommended articles in the documentation layout' do
      portal.update!(config: { allowed_locales: %w[en], default_locale: 'en', layout: 'documentation',
                               popular_content: { 'en' => { 'article_ids' => [alpha.id, beta.id] } } })

      get "/hc/#{portal.slug}/en"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Recommended articles')
      expect(response.body).to include('Alpha Guide', 'Beta Guide')
    end
  end

  describe 'GET /public/api/v1/portals/{portal_slug}/sitemap' do
    context 'when custom_domain is present' do
      it 'gets a valid sitemap' do
        get "/hc/#{portal.slug}/sitemap.xml"
        expect(response).to have_http_status(:success)
        expect(response.body).to match(/<sitemap/)
        expect(Nokogiri::XML(response.body).errors).to be_empty
      end

      it 'has valid sitemap links' do
        get "/hc/#{portal.slug}/sitemap.xml"
        expect(response).to have_http_status(:success)
        parsed_xml = Nokogiri::XML(response.body)
        links = parsed_xml.css('loc')

        links.each do |link|
          expect(link.text).to match(%r{https://www\.example\.com/hc/test-portal/articles/\d+})
        end

        expect(links.length).to eq 3
      end
    end
  end
end
