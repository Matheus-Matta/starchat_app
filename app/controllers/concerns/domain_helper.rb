module DomainHelper
  def self.starchats_domain?(domain = request.host)
    [URI.parse(ENV.fetch('FRONTEND_URL', '')).host, URI.parse(ENV.fetch('HELPCENTER_URL', '')).host].include?(domain)
  end
end
