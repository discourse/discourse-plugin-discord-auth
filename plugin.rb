# frozen_string_literal: true

# name: discourse-plugin-discord-auth
# about: Enable Login via Discord
# version: 0.1.3
# authors: Jeff Wong, Robert Barrow
# url: https://github.com/featheredtoast/discourse-plugin-discord-auth

register_svg_icon "fab-discord" if respond_to?(:register_svg_icon)

enabled_site_setting :enable_discord_logins

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
    SiteSetting.enable_discord_logins?
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
    allowed_guild_ids = SiteSetting.discord_trusted_guilds.split("|")

    if allowed_guild_ids.length > 0
      user_guild_ids = auth_token.extra[:raw_info][:guilds].map { |g| g['id'] }
      if (user_guild_ids & allowed_guild_ids).empty? # User is not in any allowed guilds
        return Auth::Result.new.tap do |auth_result|
          auth_result.failed = true
          auth_result.failed_reason = I18n.t("discord.not_in_allowed_guild")
        end
      end
    end

    super
  end
end

auth_provider icon: 'fab-discord',
              authenticator: DiscordAuthenticator.new,
              full_screen_login: true

register_css <<CSS

.btn-social.discord {
  background: #7289da;
}

CSS

after_initialize do
  AdminDashboardData.add_problem_check do
    if SiteSetting.discord_trusted_guilds.present? && SiteSetting.must_approve_users
      I18n.t("discord.trusted_guild_change_warning")
    end
  end
end
