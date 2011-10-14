require "nokogiri"

module RETS
  class Client
    URL_KEYS = {:getobject => true, :login => true, :logout => true, :search => true, :getmetadata => true}
    META_DATA_KEYS = {:metadataversion => true, :minmetadataversion => true, :metadatatimestamp => true, :minmetadatatimestamp => true}

    ##
    # Attempts to login to a RETS server.
    # @param [Hash] args
    #   * url - Login URL for the RETS server
    #   * username - Username to pass for HTTP authentication
    #   * password - Password to pass for HTTP authentication
    #   * ua_auth (Optional) - Whether RETS-UA-Authorization needs to be passed, implied when using *ua_username* or *ua_password*
    #   * ua_username (Optional) - What to set the HTTP User-Agent header to. If *ua_auth* is set and this is nil, *username* is used
    #   * ua_password (Optional) - What password to use for RETS-UA-Authorization. If *ua_auth* is set and this is nil, *password* is used
    #   * user_agent (Optional) - Custom user agent, ignored when using user agent authentication.
    #
    # @return [RETS::Base::Core]
    #   Successful login will return a {RETS::Base::Core}. Otherwise it can raise a {RETS::InvalidResponse} or {RETS::ServerError} exception depending on why it was unable to login.
    def self.login(args)
      @urls = {:login => URI.parse(args[:url])}
      @meta = {}
      base_url = @urls[:login].to_s.gsub(@urls[:login].path, "")

      http = RETS::HTTP.new({:username => args[:username], :password => args[:password], :ua_auth => args[:ua_auth], :ua_username => args[:ua_username], :ua_password => args[:ua_password]}, args[:user_agent])
      http.request(:url => @urls[:login]) do |response|
        # Parse the response and figure out what capabilities we have
        unless response.code == "200"
          raise RETS::InvalidResponse.new("Expected HTTP 200, got #{response.code}")
        end

        doc = Nokogiri::XML(response.body)
        
        code = doc.xpath("//RETS").attr("ReplyCode").value
        unless code == "0"
          raise RETS::ServerError.new("#{doc.xpath("//RETS").attr("ReplyText").value} (ReplyCode #{code})")
        end

        doc.xpath("//RETS").first.content.split("\n").each do |row|
          k, v = row.split("=", 2)
          next unless k and v
          k, v = k.downcase.strip.to_sym, v.strip

          if META_DATA_KEYS[k]
            @meta[k] = v
          elsif URL_KEYS[k]
            # In case it's a relative path and doesn't include the domain
            v = "#{base_url}#{v}" unless v =~ /(http|www)/
            @urls[k] = URI.parse(v)
          end
        end

        if response["rets-version"] =~ /RETS\/(.+)/i
          @rets_version = $1.to_f
        else
          raise RETS::InvalidResponse.new("Cannot find RETS-Version header.")
        end
      end

      begin
        model = RETS.const_get("V#{@rets_version.gsub(".", "")}::Core")
        meta_v = RETS.const_get("V#{@rets_version.gsub(".", "")}::MetadataVersion")
      rescue NameError => e
        model = RETS::Base::Core
        meta_v = RETS::Base::MetadataVersion
      end
      m =  meta_v.new(@meta)
      model.new(http, @rets_version, @urls, m)
    end
  end
end