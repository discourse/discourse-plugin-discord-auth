# name: discourse-plugin-discord-auth
# about: Enable Login via Discord
# version: 0.0.1
# authors: Jeff Wong
# url: https://github.com/featheredtoast/discourse-plugin-discord-auth

require 'auth/oauth2_authenticator'
require_relative 'omniauth/discord'

enabled_site_setting :discord_enabled

class DiscordAuthenticator < ::Auth::OAuth2Authenticator
  PLUGIN_NAME = 'oauth-discord'

  def name
    'discord'
  end

  def after_authenticate(auth_token)
    result = super
    result
  end

  def register_middleware(omniauth)
    omniauth.provider :discord,
                      scope: 'identify email',
                      setup: lambda { |env|
                        strategy = env['omniauth.strategy']
                        strategy.options[:client_id] = SiteSetting.discord_client_id
                        strategy.options[:client_secret] = SiteSetting.discord_secret
                      }
  end
end

auth_provider :title => 'with Discord',
              enabled_setting: "discord_enabled",
              :message => 'Log in via Discord',
              :frame_width => 920,
              :frame_height => 800,
              :authenticator => DiscordAuthenticator.new('discord',
                                                          trusted: true,
                                                          auto_create_account: true)


register_css <<CSS

.btn-social.discord {
  background: #7289da;
}

.btn-social.discord::before {
  content: $fa-var-gamepad;
}

CSS
