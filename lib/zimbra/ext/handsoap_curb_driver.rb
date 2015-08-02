class Handsoap::Http::Drivers::CurbDriver
  def get_curl(url)
    if @curl
      @curl.url = url
    else
      @curl                 = ::Curl::Easy.new(url)
      @curl.timeout         = Handsoap.timeout
      @curl.enable_cookies  = @enable_cookies

      # enables both deflate and gzip compression of responses
      @curl.encoding = ''

      if Handsoap.follow_redirects?
        @curl.follow_location = true
          @curl.max_redirects = Handsoap.max_redirects
        end
      end
    @curl.ssl_verify_peer = false
    @curl
  end
end
