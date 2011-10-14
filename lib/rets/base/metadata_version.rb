module RETS
  module Base
    class MetadataVersion
        attr_reader  :version, :min_version, :timestamp, :min_timestamp
        
        def initialize(args)
            @version = args[:metadataversion]
            @min_version = args[:minmetadataversion]
            @timestamp = args[:metadatatimestamp]
            @min_timestamp = args[:minmetadatatimestamp]
        end

    end
  end
end