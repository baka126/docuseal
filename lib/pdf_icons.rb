# frozen_string_literal: true

module PdfIcons
  PATH = Rails.root.join('lib/pdf_icons')

  WIDTH = 240
  HEIGHT = 240

  module_function

  def check_io
    StringIO.new(check_data)
  end

  def paperclip_io
    StringIO.new(paperclip_data)
  end

  def logo_io
    StringIO.new(logo_data)
  end

  def stamp_logo_io
    StringIO.new(stamp_logo_data)
  end

  def check_data
    @check_data ||= PATH.join('check.png').read
  end

  def paperclip_data
    @paperclip_data ||= PATH.join('paperclip.png').read
  end

  def logo_data
    @logo_data ||= begin
      logo_path = Docuseal.logo_png_path
      logo_path = Rails.public_path.join('logo.png') if logo_path.blank?

      logo_path.exist? ? logo_path.binread : PATH.join('logo.png').binread
    end
  end

  def stamp_logo_data
    @stamp_logo_data ||= PATH.join('stamp-logo.png').read
  end
end
