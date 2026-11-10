require 'net/http'
require 'uri'

module LogoDev
  class Search
    API_URL = 'https://api.logo.dev/search'
    LOGO_URL = 'https://img.logo.dev'
    MIN_QUERY_LENGTH = 3

    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 30

    def self.call(query)
      new(query).call
    end

    def self.logo(domain)
      new(domain).logo
    end

    def initialize(query)
      @query = query.to_s.strip
    end

    def call
      return [] if @query.length < MIN_QUERY_LENGTH

      uri = URI(API_URL)
      uri.query = URI.encode_www_form(
        q: @query,
        strategy: 'suggest'
      )

      response = get(uri) do |request|
        request['Authorization'] = "Bearer #{ENV.fetch('LOGO_DEV_SECRET_KEY')}"
      end

      return [] unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout
      []
    rescue StandardError
      []
    end

    def logo
      return if @query.blank?

      filename = "#{@query.parameterize}.png"
      directory = Rails.root.join('public', 'brand_logos')
      filepath = directory.join(filename)
      public_path = "/brand_logos/#{filename}"

      return public_path if File.exist?(filepath)

      uri = URI("#{LOGO_URL}/#{@query}")
      uri.query = URI.encode_www_form(
        token: ENV.fetch('LOGO_DEV_PUBLISHABLE_KEY')
      )

      response = get(uri)

      return unless response.is_a?(Net::HTTPSuccess)
      return if response.body.blank?

      FileUtils.mkdir_p(directory)
      File.binwrite(filepath, response.body)

      public_path
    rescue Net::OpenTimeout, Net::ReadTimeout
      nil
    rescue StandardError
      nil
    end

    private

    def get(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.write_timeout = READ_TIMEOUT

      request = Net::HTTP::Get.new(uri)
      request['Accept-Encoding'] = 'identity'
      request['Connection'] = 'close'

      yield(request) if block_given?

      http.request(request)
    end
  end
end