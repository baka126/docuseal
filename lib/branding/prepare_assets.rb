# frozen_string_literal: true

module Branding
  module PrepareAssets
    ICON_SIZES = {
      'apple-icon-180x180.png' => [180, 180],
      'apple-touch-icon.png' => [192, 192],
      'apple-touch-icon-precomposed.png' => [192, 192],
      'favicon-96x96.png' => [96, 96],
      'favicon-32x32.png' => [32, 32],
      'favicon-16x16.png' => [16, 16]
    }.freeze

    module_function

    def call(force: false)
      source_path = Docuseal.logo_png_path
      return if source_path.blank?
      return unless source_path.exist?

      prepare_logo_png(source_path, force:)
      prepare_icons(source_path, force:)
    rescue StandardError => e
      Rails.logger.warn("Branding asset preparation failed: #{e.class}: #{e.message}")
    end

    def prepare_logo_png(source_path, force: false)
      destination = Rails.public_path.join('logo.png')
      return if up_to_date?(source_path, destination, force:)

      process_to_png(source_path, destination) do |pipeline|
        pipeline.resize_to_limit(512, 512)
      end
    end

    def prepare_icons(source_path, force: false)
      ICON_SIZES.each do |filename, size|
        destination = Rails.public_path.join(filename)
        next if up_to_date?(source_path, destination, force:)

        process_to_png(source_path, destination, flatten: true) do |pipeline|
          pipeline.resize_and_pad(size[0], size[1], background: [255, 255, 255])
        end
      end
    end

    def process_to_png(source_path, destination, flatten: false)
      vips_pipeline = ImageProcessing::Vips
                      .source(source_path.to_s)
                      .loader(fail: true)
                      .colourspace('srgb')

      vips_pipeline = vips_pipeline.flatten(background: [255, 255, 255]) if flatten

      yield(vips_pipeline).call(destination: destination.to_s)
    rescue StandardError => e
      Rails.logger.warn("Branding asset processing with Vips failed for #{source_path}: #{e.class}: #{e.message}")

      mini_magick_pipeline = ImageProcessing::MiniMagick
                             .source(source_path.to_s)
                             .loader(fail: true)

      mini_magick_pipeline = mini_magick_pipeline.flatten if flatten

      yield(mini_magick_pipeline).call(destination: destination.to_s)
    end

    def up_to_date?(source_path, destination, force: false)
      return false if force
      return false unless destination.exist?

      destination.binread == source_path.binread
    end
  end
end