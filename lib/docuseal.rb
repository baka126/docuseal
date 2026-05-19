# frozen_string_literal: true

require 'digest'
require 'fileutils'

module Docuseal
  URL_CACHE = ActiveSupport::Cache::MemoryStore.new
  CONFIG_PATH = Rails.root.join('config/config.yml')

  PRODUCT_URL = 'https://www.docuseal.com'
  PRODUCT_EMAIL_URL = ENV.fetch('PRODUCT_EMAIL_URL', PRODUCT_URL)
  NEWSLETTER_URL = "#{PRODUCT_URL}/newsletters".freeze
  ENQUIRIES_URL = "#{PRODUCT_URL}/enquiries".freeze
  PRODUCT_NAME = 'TechTrums'
  SUPPORT_URL = 'mailto:support@docuseal.com'
  DEFAULT_APP_URL = ENV.fetch('APP_URL', 'http://localhost:3000')
  GITHUB_URL = 'https://github.com/docusealco/docuseal'
  DISCORD_URL = 'https://discord.gg/qygYCDGck9'
  TWITTER_URL = 'https://twitter.com/docusealco'
  TWITTER_HANDLE = '@docusealco'
  CHATGPT_URL = "#{PRODUCT_URL}/chat".freeze
  SUPPORT_EMAIL = 'support@docuseal.com'
  HOST = ENV.fetch('HOST', 'localhost')
  AATL_CERT_NAME = 'docuseal_aatl'
  CONSOLE_URL = if Rails.env.development?
                  'http://console.localhost.io:3001'
                elsif ENV['MULTITENANT'] == 'true'
                  "https://console.#{HOST}"
                else
                  'https://console.docuseal.com'
                end
  CLOUD_URL = if Rails.env.development?
                'http://localhost:3000'
              else
                'https://docuseal.com'
              end
  CDN_URL = if Rails.env.development?
              'http://localhost:3000'
            elsif ENV['MULTITENANT'] == 'true'
              "https://cdn.#{HOST}"
            else
              'https://cdn.docuseal.com'
            end

  CERTS = JSON.parse(ENV.fetch('CERTS', '{}'))
  TIMESERVER_URL = ENV.fetch('TIMESERVER_URL', nil)
  VERSION_FILE_PATH = Rails.root.join('.version')
  VERSION_FILE2_PATH = Rails.public_path.join('version')

  DEFAULT_URL_OPTIONS = {
    host: HOST,
    protocol: ENV['FORCE_SSL'].present? ? 'https' : 'http'
  }.freeze

  module_function

  def version
    @version ||=
      if VERSION_FILE_PATH.exist?
        VERSION_FILE_PATH.read.strip
      elsif VERSION_FILE2_PATH.exist?
        VERSION_FILE2_PATH.each_line.first.to_s.strip
      end
  end

  def multitenant?
    ENV['MULTITENANT'] == 'true'
  end

  def advanced_formats?
    multitenant?
  end

  def demo?
    ENV['DEMO'] == 'true'
  end

  def active_storage_public?
    ENV['ACTIVE_STORAGE_PUBLIC'] == 'true'
  end

  def default_pkcs
    return if Docuseal::CERTS['enabled'] == false

    @default_pkcs ||= GenerateCertificate.load_pkcs(Docuseal::CERTS)
  end

  def fulltext_search?
    return @fulltext_search unless @fulltext_search.nil?

    @fulltext_search =
      if SearchEntry.table_exists?
        Docuseal.multitenant? || AccountConfig.exists?(key: :fulltext_search, value: true)
      else
        false
      end
  end

  def enable_pwa?
    true
  end

  def pdf_format
    @pdf_format ||= ENV['PDF_FORMAT'].to_s.downcase
  end

  def trusted_certs
    @trusted_certs ||=
      ENV['TRUSTED_CERTS'].to_s.gsub('\\n', "\n").split("\n\n").map do |base64|
        OpenSSL::X509::Certificate.new(base64)
      end
  end

  def default_url_options
    return DEFAULT_URL_OPTIONS if multitenant?

    @default_url_options ||= begin
      value = EncryptedConfig.find_by(key: EncryptedConfig::APP_URL_KEY)&.value if ENV['APP_URL'].blank?
      value ||= DEFAULT_APP_URL
      url = Addressable::URI.parse(value)
      { host: url.host, port: url.port, protocol: url.scheme }
    end
  end

  def product_name
    app_config.fetch('name', PRODUCT_NAME).to_s
  end

  def support_url
    app_config.fetch('support_url', SUPPORT_URL).to_s
  end

  def logo_png_path
    raw_path = app_config['logo_png'] || app_config['logo']
    return if raw_path.blank?

    if raw_path.to_s.start_with?('http://', 'https://')
      fetch_remote_logo(raw_path.to_s)
    else
      path = Pathname.new(raw_path.to_s)
      path.absolute? ? path : Rails.root.join(path)
    end
  end

  def fetch_remote_logo(url)
    cache_dir = Rails.root.join('tmp/branding')
    FileUtils.mkdir_p(cache_dir) unless cache_dir.exist?
    cache_path = cache_dir.join("logo_#{Digest::SHA1.hexdigest(url)}")

    return cache_path if cache_path.exist? && cache_path.mtime > 1.hour.ago

    begin
      response = DownloadUtils.call(url)
      File.binwrite(cache_path, response.body)
      cache_path
    rescue StandardError => e
      Rails.logger.warn("Failed to download remote logo from #{url}: #{e.message}")
      cache_path.exist? ? cache_path : nil
    end
  end

  def refresh_default_url_options!
    @default_url_options = nil
  end

  def app_config
    return @app_config if defined?(@app_config)

    @app_config = begin
      if !CONFIG_PATH.exist?
        {}
      else
        raw = ERB.new(CONFIG_PATH.read).result
        config = YAML.safe_load(raw, aliases: true) || {}

        default_config = config['default'].is_a?(Hash) ? config['default'] : {}
        env_config = config[Rails.env].is_a?(Hash) ? config[Rails.env] : {}

        default_config.merge(env_config)
      end
    rescue StandardError => e
      Rails.logger.warn("Unable to load branding config from #{CONFIG_PATH}: #{e.class}: #{e.message}")
      {}
    end
  end
end
