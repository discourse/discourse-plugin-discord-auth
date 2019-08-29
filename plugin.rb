# frozen_string_literal: true

# name: discourse-plugin-discord-auth
# about: Enable Login via Discord
# version: 0.1.3
# authors: Jeff Wong, Robert Barrow
# url: https://github.com/featheredtoast/discourse-plugin-discord-auth

register_svg_icon "fab-discord" if respond_to?(:register_svg_icon)

enabled_site_setting :discord_enabled

class OmniAuth::Strategies::Discord < OmniAuth::Strategies::OAuth2
  option :name, 'discord'
  option :scope, 'identify email guilds'

  option :client_options,
          site: 'https://discordapp.com/api',
          authorize_url: 'oauth2/authorize',
          token_url: 'oauth2/token'

  option :authorize_options, %i[scope permissions]

  uid { raw_info['id'] }

  info do
    puts raw_info
    {
      name: raw_info['username'],
      email: raw_info['verified'] ? raw_info['email'] : nil,
      image: "https://cdn.discordapp.com/avatars/#{raw_info['id']}/#{raw_info['avatar']}"
    }
  end

  extra do
    {
      'raw_info' => raw_info
    }
  end

  def raw_info
    @raw_info ||= access_token.get('users/@me').parsed.
      merge(guilds: access_token.get('users/@me/guilds').parsed)
  end

  def callback_url
    full_host + script_name + callback_path
  end
end

class DiscordAuthenticator < ::Auth::ManagedAuthenticator
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
           }
    end

  def after_authenticate(auth_token, existing_account: nil)
    trustedGuild = false

    if SiteSetting.discord_trusted_guild != ''
      guilds = auth_token.extra[:raw_info][:guilds]
      for guild in guilds do
        if guild['id'] == SiteSetting.discord_trusted_guild then
          trustedGuild = true
          break
        end
      end
    end

    result = super

    if trustedGuild
      result.extra_data[:auto_approve] = true
    else
      result.extra_data[:auto_approve] = false
    end

    result
  end

  def after_create_account(user, auth)
    super

    data = auth[:extra_data]
    if !user.approved && data[:auto_approve]
      user.approved = true
      user.approved_by_id = Discourse.system_user.id
      user.save!
      if reviewable = ::ReviewableUser.pending.find_by(target: user)
        reviewable.perform(:approve, Discourse.system_user)
      end
    end
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
