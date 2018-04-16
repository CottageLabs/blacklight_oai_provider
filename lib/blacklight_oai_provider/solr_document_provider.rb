module BlacklightOaiProvider
  class SolrDocumentProvider < ::OAI::Provider::Base
    attr_accessor :options

    def initialize(controller, options = {})
      options[:provider] ||= {}
      options[:document] ||= {}

      options[:provider][:repository_name] ||= controller.view_context.send(:application_name)
      options[:provider][:repository_url] ||= controller.view_context.send(:oai_provider_catalog_url)

      self.class.model = SolrDocumentWrapper.new(controller, options[:document])

      options[:provider].each do |key, value|
        if value.respond_to? :call
          self.class.send key, value.call
        else
          self.class.send key, value
        end
      end
      @supported_formats = options.dig(:document, :supported_formats)
      @supported_formats = ['oai_dc'] if @supported_formats.blank?
    end

    def process_request(params = {})
      begin
        validate_metadata_format(params[:verb], params[:metadataPrefix]) if params[:resumptionToken].blank?
        validate_granularity(params[:from], params[:until]) if params[:from] && params[:until]
        params[:from] = parse_date(params[:from]) if params[:from]
        params[:until] = parse_date(params[:until]) if params[:until]
      rescue => err
        return OAI::Provider::Response::Error.new(self.class, err).to_xml
      end

      super params
    end

    def list_sets(options = {})
      Response::ListSets.new(self.class, options).to_xml
    end

    private

    def parse_date(value)
      return value if value.respond_to?(:strftime)
      Date.parse(value) # This will raise an exception for badly formatted dates

      ActiveSupport::TimeZone['UTC'].parse(value).tap do |date|
        raise 'Wrong format' unless date.utc.iso8601.include?(value)
      end
    rescue
      raise OAI::ArgumentException.new, "Invalid date: '#{value}'"
    end

    def validate_granularity(from, to)
      raise(OAI::ArgumentException.new, "Date granularities do not match! #{from} - #{to}") unless from.length == to.length
    end

    def validate_metadata_format(verb, metadata_prefix)
      if ['ListIdentifiers', 'ListRecords', 'GetRecord'].include? verb
        raise(OAI::ArgumentException.new, "metadataPrefix not provided") if metadata_prefix.blank?
        return metadata_prefix if @supported_formats.include? metadata_prefix
        raise(OAI::FormatException.new, "metadataPrefix not supported")
      end
    end
  end
end
