I18n.default_locale = 'en'
# Adds fallback to default locale for untranslated strings
I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)

require 'redmine'

# Load the secret token from the Redmine configuration file
secret = Redmine::Configuration['4aac56118d4314ea7b66fdc8db22a46d2d56954dd36ac8f78366228a94c4a174e1f31650951cef08']
if secret.present?
  RedmineApp::Application.config.secret_token = secret
end

Redmine::Plugin.load
unless Redmine::Configuration['mirror_plugins_assets_on_startup'] == false
  Redmine::Plugin.mirror_assets
end
