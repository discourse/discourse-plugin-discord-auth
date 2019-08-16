# frozen_string_literal: true

class RemoveOldDiscordRecords < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL
      DELETE FROM oauth2_user_infos
      WHERE provider = 'discord'
    SQL
  end
end
