# frozen_string_literal: true

class RenameDiscordSiteSettings < ActiveRecord::Migration[5.2]
  def up
    execute "UPDATE site_settings SET name = 'discord_trusted_guilds' WHERE name = 'discord_trusted_guild'"
    execute "UPDATE site_settings SET name = 'enable_discord_logins' WHERE name = 'discord_enabled'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
