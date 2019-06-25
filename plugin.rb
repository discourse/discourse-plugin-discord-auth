# frozen_string_literal: true

# name: discourse-plugin-discord-auth
# about: Enable Login via Discord
# version: 0.1.3
# authors: Jeff Wong, Robert Barrow
# url: https://github.com/featheredtoast/discourse-plugin-discord-auth

require 'auth/oauth2_authenticator'
require 'open-uri'
require 'json'

gem 'omniauth-discord', '0.1.8'

register_svg_icon "fab-discord" if respond_to?(:register_svg_icon)

enabled_site_setting :discord_enabled

class DiscordAuthenticator < ::Auth::ManagedAuthenticator
  PLUGIN_NAME = 'oauth-discord'
  BASE_API_URL = 'https://discordapp.com/api'
  AVATAR_SIZE ||= 480

  def name
    'discord'
  end

  def enabled?
    SiteSetting.discord_enabled?
  end

  def register_middleware(omniauth)
  omniauth.provider :discord,
         setup: lambda { |env|
           strategy = env["omniauth.strategy"]
            strategy.options[:client_id] = SiteSetting.discord_client_id
            strategy.options[:client_secret] = SiteSetting.discord_secret
            strategy.options[:info_fields] = 'email,username'
            strategy.options[:image_size] = { width: AVATAR_SIZE, height: AVATAR_SIZE }
            strategy.options[:secure_image_url] = true
         },
         scope: 'identify email guilds'
  end

  def after_authenticate(auth_token)
    trustedGuild = false
    if SiteSetting.discord_trusted_guild != ''
      guildsString = open(BASE_API_URL + '/users/@me/guilds',
                     "Authorization" => "Bearer " + auth_token.credentials.token).read
      guilds = JSON.parse guildsString
      for guild in guilds do
        if guild['id'] == SiteSetting.discord_trusted_guild then
          trustedGuild = true
          break
        end
      end
    end
    if trustedGuild && !User.find_by_email(auth_token.info.email)
      systemUser = User.find_by(id: -1)
      Invite.generate_invite_link(auth_token.info.email, systemUser)
    end

    result = super
    data = auth_token[:info]
    
    if trustedGuild
      result.extra_data[:auto_approve] = true
    else
      result.extra_data[:auto_approve] = false
    end
    result
  end
end

auth_provider icon: 'fab-discord',
              frame_width: 920,
              frame_height: 800,
              authenticator: DiscordAuthenticator.new

register_css <<CSS

.btn-social.discord {
  background: #7289da;
}

CSS
