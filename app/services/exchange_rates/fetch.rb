require "net/http"
require "json"
require "uri"
require "time"
require "bigdecimal"

class ExchangeRates::Fetch
  BASE_URL = "https://fxapi.app/api"
  WORKERS = 8
  UPSERT_BATCH_SIZE = 5_000
  API_UPDATE_RETRIES = 12
  API_UPDATE_RETRY_DELAY = 15

  def self.call
    new.call
  end

  def call
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    log "Starting exchange rates update"

    expected_fetched_at = wait_for_api_update
    return unless expected_fetched_at

    currencies_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    currencies = fetch_currencies

    log "Found #{currencies.size} currencies"
    log "Currencies fetched in #{elapsed(currencies_started_at)}s"

    rates_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    results = fetch_rates(currencies)

    log "Fetched #{results[:rates].size} rates"
    log "Skipped #{results[:skipped].size} currencies"
    log "Failed #{results[:failed].size} currencies"
    log "Rates fetched in #{elapsed(rates_started_at)}s"

    save_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    save_rates(results[:rates])

    log "Saved #{results[:rates].size} rates"
    log "Rates saved in #{elapsed(save_started_at)}s"

    log "Exchange rates update finished in #{elapsed(started_at)}s"

    {
      currencies: currencies.size,
      rates: results[:rates].size,
      skipped: results[:skipped],
      failed: results[:failed],
      duration: elapsed(started_at)
    }
  end

  private

  def wait_for_api_update
    API_UPDATE_RETRIES.times do |attempt|
      expected_fetched_at = expected_api_fetched_at
      actual_fetched_at = fetch_api_timestamp

      if actual_fetched_at && actual_fetched_at >= expected_fetched_at
        log "API is updated: expected=#{expected_fetched_at}, actual=#{actual_fetched_at}"
        return expected_fetched_at
      end

      log "API is not updated: expected=#{expected_fetched_at}, actual=#{actual_fetched_at}, attempt=#{attempt + 1}/#{API_UPDATE_RETRIES}"

      sleep API_UPDATE_RETRY_DELAY
    end

    log "API did not become current within #{API_UPDATE_RETRIES * API_UPDATE_RETRY_DELAY} seconds"

    nil
  end

  def expected_api_fetched_at
    current_time = Time.current

    current_time.change(
      min: current_time.min - (current_time.min % 5),
      sec: 0
    )
  end

  def fetch_api_timestamp
    uri = URI("#{BASE_URL}/usd.json")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 10
    http.write_timeout = 10

    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)

    return nil unless data.is_a?(Hash)
    return nil unless data["timestamp"].is_a?(String)

    Time.parse(data["timestamp"])
  rescue JSON::ParserError, ArgumentError, Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, SocketError, EOFError, IOError
    nil
  end

  def fetch_currencies
    uri = URI("#{BASE_URL}/currencies.json")
    response = Net::HTTP.get_response(uri)

    raise "fxapi.app: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("currencies")
  end

  def fetch_rates(currencies)
    queue = Queue.new
    currencies.each { |currency| queue << currency }

    processed = 0
    processed_mutex = Mutex.new

    workers = WORKERS.times.map do
      Thread.new do
        rates = []
        skipped = []
        failed = []

        loop do
          currency = queue.pop(true)
          data = fetch_rate(currency)

          case data
          when Hash
            data["rates"].each do |quote_currency, rate|
              next unless rate.is_a?(Numeric)
              next unless rate.finite?

              rates << {
                base_currency: data["base"],
                quote_currency: quote_currency,
                rate: rate,
                fetched_at: data["timestamp"],
                previous_rate: rate,
                previous_rate_updated_at: data["timestamp"],
                status: 0
              }
            end
          when :not_found
            skipped << currency
          else
            failed << currency
          end

          processed_mutex.synchronize do
            processed += 1

            if processed % 25 == 0 || processed == currencies.size
              log "Processed #{processed}/#{currencies.size} currencies"
            end
          end
        rescue ThreadError
          break
        rescue StandardError => e
          failed << currency if currency
          log "Failed #{currency}: #{e.class}: #{e.message}"

          processed_mutex.synchronize do
            processed += 1

            if processed % 25 == 0 || processed == currencies.size
              log "Processed #{processed}/#{currencies.size} currencies"
            end
          end
        end

        {
          rates: rates,
          skipped: skipped,
          failed: failed
        }
      end
    end

    results = workers.map(&:value)

    {
      rates: normalize_rates(results.flat_map { |result| result[:rates] }),
      skipped: results.flat_map { |result| result[:skipped] },
      failed: results.flat_map { |result| result[:failed] }
    }
  end

  def normalize_rates(rates)
    rates_by_pair = rates.index_by { |rate| [rate[:base_currency], rate[:quote_currency]] }
    usd_rates = rates_by_pair.select { |(base_currency, _), _| base_currency == "USD" }

    rates.each do |rate|
      base_currency = rate[:base_currency]
      quote_currency = rate[:quote_currency]

      next if base_currency == quote_currency

      usd_to_base = usd_rates[["USD", base_currency]]
      usd_to_quote = usd_rates[["USD", quote_currency]]

      next unless usd_to_base
      next unless usd_to_quote
      next unless usd_to_base[:rate].to_d.nonzero?

      rate[:rate] = usd_to_quote[:rate].to_d / usd_to_base[:rate].to_d
      rate[:previous_rate] = rate[:rate]
    end

    rates
  end

  def fetch_rate(currency)
    uri = URI("#{BASE_URL}/#{currency.downcase}.json")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30
    http.write_timeout = 10

    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    return :not_found if response.code == "404"
    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)

    return nil unless data.is_a?(Hash)
    return nil unless data["base"].is_a?(String)
    return nil unless data["timestamp"].is_a?(String)
    return nil unless data["rates"].is_a?(Hash)

    data
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, SocketError, EOFError, IOError
    nil
  end

  def save_rates(rates)
    rates.each_slice(UPSERT_BATCH_SIZE) do |batch|
      Rate.upsert_all(
        batch,
        unique_by: [:base_currency, :quote_currency],
        on_duplicate: Arel.sql(
          "previous_rate = CASE
            WHEN rates.previous_rate_updated_at IS NULL
              OR rates.previous_rate_updated_at <= EXCLUDED.fetched_at - INTERVAL '24 hours'
            THEN rates.rate
            ELSE rates.previous_rate
          END,
          previous_rate_updated_at = CASE
            WHEN rates.previous_rate_updated_at IS NULL
              OR rates.previous_rate_updated_at <= EXCLUDED.fetched_at - INTERVAL '24 hours'
            THEN EXCLUDED.fetched_at
            ELSE rates.previous_rate_updated_at
          END,
          rate = EXCLUDED.rate,
          fetched_at = EXCLUDED.fetched_at,
          status = EXCLUDED.status,
          updated_at = EXCLUDED.updated_at"
        )
      )
    end
  end

  def elapsed(started_at)
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(2)
  end

  def log(message)
    puts "[ExchangeRates::Fetch] #{message}"
  end
end