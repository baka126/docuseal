# frozen_string_literal: true

Rails.application.config.after_initialize do
  next if ENV['SKIP_BRANDING_ASSET_PREPARE'] == 'true'

  Branding::PrepareAssets.call
end