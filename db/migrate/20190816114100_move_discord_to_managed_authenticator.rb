# frozen_string_literal: true

class MoveDiscordToManagedAuthenticator < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL
      INSERT INTO user_associated_accounts (
        provider_name,
        provider_uid,
        user_id,
        info,
        created_at,
        updated_at
      ) SELECT
        'discord',
        oui.uid,
        oui.user_id,
        json_build_object('email', oui.email, 'name', oui.name),
        oui.created_at,
        oui.updated_at
      FROM oauth2_user_infos oui
      WHERE provider = 'discord'
      ON CONFLICT DO NOTHING
    SQL
  end
end
