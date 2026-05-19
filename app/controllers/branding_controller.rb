# frozen_string_literal: true

class BrandingController < ActionController::Base
  def logo
    logo_path = source_logo_path
    return head :not_found unless logo_path&.exist?

    send_resized_png(logo_path, size: 512, transparent: true)
  end

  def favicon
    logo_path = source_logo_path
    return head :not_found unless logo_path&.exist?

    size = params[:size].to_i
    size = 32 unless size.positive?
    size = [[size, 512].min, 16].max

    send_resized_png(logo_path, size:)
  end

  def apple_touch_icon
    logo_path = source_logo_path
    return head :not_found unless logo_path&.exist?

    send_resized_png(logo_path, size: 180)
  end

  private

  def source_logo_path
    configured_logo_path = Docuseal.logo_png_path

    [
      configured_logo_path,
      Rails.public_path.join('logo.png'),
      Rails.root.join('lib/pdf_icons/logo.png')
    ].compact.find(&:exist?)
  end

  def send_resized_png(logo_path, size:, transparent: false)
    processed = begin
      pipeline = ImageProcessing::Vips
                 .source(logo_path.to_s)
                 .loader(fail: true)
                 .convert('png')

      if transparent
        pipeline = pipeline.resize_to_limit(size, size)
      else
        pipeline = pipeline.flatten(background: 255)
                           .resize_and_pad(size, size, background: 255)
      end

      pipeline.call
    rescue StandardError => e
      Rails.logger.warn("Branding image processing with Vips failed for #{logo_path}: #{e.class}: #{e.message}")

      pipeline = ImageProcessing::MiniMagick
                 .source(logo_path.to_s)
                 .loader(fail: true)
                 .convert('png')

      if transparent
        pipeline = pipeline.resize_to_limit("#{size}x#{size}")
      else
        pipeline = pipeline.flatten
                           .resize_and_pad(size, size, background: 'white')
      end

      pipeline.call
    end

    send_data File.binread(processed.path), type: 'image/png', disposition: 'inline'
  ensure
    processed&.close
    processed&.unlink
  end
end