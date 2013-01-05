I18n.default_locale = 'en'
# Adds fallback to default locale for untranslated strings
I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)

require 'redmine'

# Load the secret token from the Redmine configuration file
secret = Redmine::Configuration['faa7c2718be53ae70ac5e2fc6ed0f32477d97826fba8a29518624e86db0c821c0149011f5b3bdcfd']
if secret.present?
  RedmineApp::Application.config.secret_token = secret
end

Redmine::Plugin.load
unless Redmine::Configuration['mirror_plugins_assets_on_startup'] == false
  Redmine::Plugin.mirror_assets
end
