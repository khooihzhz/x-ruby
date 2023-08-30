require_relative "../test_helper"

# Tests for errors
class ErrorsTest < Minitest::Test
  def setup
    @client = client
  end

  X::Errors::ERROR_CLASSES.each do |status, error_class|
    define_method("test_#{error_class.name.split("::").last.downcase}_error") do
      stub_request(:get, "https://api.twitter.com/2/tweets")
        .with(headers: {"Authorization" => /OAuth/})
        .to_return(status: status, headers: {"content-type" => "application/json; charset=utf-8"}, body: {}.to_json)

      assert_raises error_class do
        @client.get("tweets")
      end
    end
  end

  X::Errors::NETWORK_ERRORS.each do |error_class|
    define_method("test_#{error_class.name.split("::").last.downcase}_error") do
      stub_request(:get, "https://api.twitter.com/2/tweets").to_raise(error_class)

      assert_raises X::NetworkError do
        @client.get("tweets")
      end
    end
  end

  def test_missing_credentials
    assert_raises ArgumentError do
      X::Client.new
    end
  end

  def test_set_invalid_base_url
    assert_raises ArgumentError do
      @client.base_url = "ftp://ftp.example.com"
    end
  end

  def test_rate_limit
    headers = {"content-type" => "application/json; charset=utf-8",
               "x-rate-limit-limit" => "40000", "x-rate-limit-remaining" => "39999"}
    stub_request(:get, "https://api.twitter.com/2/tweets")
      .to_return(status: 429, headers: headers, body: {}.to_json)

    begin
      @client.get("tweets")
    rescue X::TooManyRequestsError => e
      assert_equal 40_000, e.limit
      assert_equal 39_999, e.remaining
    end
  end

  def test_rate_limit_reset_at
    Timecop.freeze do
      reset_time = Time.now.utc.to_i + 900
      headers = {"content-type" => "application/json; charset=utf-8", "x-rate-limit-reset" => reset_time.to_s}
      stub_request(:get, "https://api.twitter.com/2/tweets").to_return(status: 429, headers: headers, body: {}.to_json)

      begin
        @client.get("tweets")
      rescue X::TooManyRequestsError => e
        assert_equal Time.at(reset_time).utc, e.reset_at
      end
    end
  end

  def test_rate_limit_reset_in
    Timecop.freeze do
      reset_time = Time.now.utc.to_i + 900
      headers = {"content-type" => "application/json; charset=utf-8", "x-rate-limit-reset" => reset_time.to_s}
      stub_request(:get, "https://api.twitter.com/2/tweets").to_return(status: 429, headers: headers, body: {}.to_json)

      begin
        @client.get("tweets")
      rescue X::TooManyRequestsError => e
        assert_equal 900, e.reset_in
      end
    end
  end

  def test_unexpected_response
    stub_request(:get, "https://api.twitter.com/2/tweets")
      .with(headers: {"Authorization" => /OAuth/})
      .to_return(status: 600, headers: {"content-type" => "application/json; charset=utf-8"}, body: {}.to_json)

    assert_raises X::Error do
      client.get("tweets")
    end
  end
end