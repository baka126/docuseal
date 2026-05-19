# frozen_string_literal: true

namespace :branding do
  desc 'Generate public logo and favicon assets from config/config.yml logo PNG'
  task prepare: :environment do
    Branding::PrepareAssets.call(force: true)
    puts 'Branding assets prepared'
  end
end