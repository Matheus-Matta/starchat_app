json.partial! 'api/v1/models/account', formats: [:json], resource: @account
json.latest_chatwoot_version @latest_chatwoot_version
json.partial! 'starchat/api/v1/accounts/partials/account', account: @account if ChatwootApp.enterprise?
