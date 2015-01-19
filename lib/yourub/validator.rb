module Yourub
  module Validator
    class << self

      DEFAULT_COUNTRY = "US"
      COUNTRIES       = [ 'AR','AU','AT','BE','BR','CA','CL','CO','CZ','EG','FR','DE','GB','HK',
                          'HU','IN','IE','IL','IT','JP','JO','MY','MX','MA','NL','NZ','PE','PH',
                          'PL','RU','SA','SG','ZA','KR','ES','SE','CH','TW','AE','US']
      ORDERS          = ['date', 'rating', 'relevance', 'title', 'videoCount', 'viewCount']
      VALID_PARAMS    = [:country, :category, :query, :id, :max_results, :count_filter, :order, :published_after, :published_before, :location, :latitude, :longitude, :radius ]
      MINIMUM_PARAMS  = [:country, :category, :query, :id]

      def confirm(criteria)
        valid_format?(criteria)
        @criteria = symbolize_keys(criteria)

        remove_empty_and_non_valid_params
        minimum_param_present?

        keep_only_the_id_if_present
        validate_order
        countries_to_array
        add_default_country_if_category_is_present
        validate_countries
        set_filter_count_options
        set_published_options
        set_location_options

        @criteria
      end

      def symbolize_keys(hash)
        hash.inject({}){|result, (key, value)|
          new_key = case key
                    when String then key.to_sym
                    else key
                    end
          new_value = case value
                      when Hash then symbolize_keys(value)
                      else value
                      end
          result[new_key] = new_value
          result
        }
      end

      def remove_empty_and_non_valid_params
        @criteria.keep_if{|k,v| ( (VALID_PARAMS.include? k) && v.present?) }
      end

      def keep_only_the_id_if_present
        if @criteria.has_key? :id
          @criteria.keep_if{|k, _| k == :id}
        end
      end

      def countries_to_array
        if @criteria.has_key? :country
          if @criteria[:country].is_a?(String)
            @criteria[:country] = @criteria[:country].split(',').collect(&:strip)
          end
          @criteria[:country] = @criteria[:country].to_a
        end
      end

      def add_default_country_if_category_is_present
        if (@criteria.has_key? :category) && (!@criteria.has_key? :country)
          @criteria[:country] = [ DEFAULT_COUNTRY ]
        end
      end

      def set_filter_count_options
        if @criteria.has_key? :count_filter
          Yourub::CountFilter.filter = @criteria.delete(:count_filter)
        end
      end

      def set_published_options
        if @criteria.has_key? :published_before
          @criteria[:published_before] = @criteria.delete(:published_before).try(:utc).try(:iso8601)
        end
        if @criteria.has_key? :published_after
          @criteria[:published_after] = @criteria.delete(:published_after).try(:utc).try(:iso8601)
        end
      end

      def set_location_options
        if @criteria.has_key? :location
          latitude, longitude = Geocoder.coordinates(@criteria[:location])
          @criteria[:location] = "#{latitude},#{longitude}"
        elsif (@criteria.has_key? :latitude) && (@criteria.has_key :longitude)
          @criteria[:location] = "#{@criteria.delete([:latitude])},#{@criteria.delete([:longitude])}"
        else
          return
        end
        set_radius
      end

      def set_radius
        if @criteria.has_key? :radius
          @criteria[:radius] = "#{translate_miles_to_meters(@criteria[:radius].to_f)}m"
        else
          @criteria[:radius] = "10000m"
        end
      end

      def translate_miles_to_meters(radius)
        if radius.present? && radius > 0.0
          @radius_in_meters = radius * 1609.34
          radius_in_bounds(@radius_in_meters)
        end
      end

      def radius_in_bounds(radius)
        if radius < 1000
          1000
        elsif radius > 1000000
          1000000
        else
          radius
        end
      end

      def valid_category(categories, selected_category)
        return categories if selected_category == 'all'
        categories = categories.select {|k| k.has_value?(selected_category.downcase)}
        if categories.first.nil?
          raise ArgumentError.new(
            "The category #{selected_category} does not exists in the following ones: #{categories.join(',')}")
        end
        return categories
      end

      def valid_format?(criteria)
        raise ArgumentError.new(
          "give an hash as search criteria"
        ) unless( criteria.is_a? Hash )
      end

      def minimum_param_present?
        if @criteria.none?{|k,_| MINIMUM_PARAMS.include? k}
        raise ArgumentError.new(
          "minimum params to start a search is at least one of: #{MINIMUM_PARAMS.join(',')}"
        )
        end
      end

      def validate_order
        if @criteria.has_key? :order
          raise ArgumentError.new(
            "the given order is not in the available ones: #{ORDERS.join(',')}"
          ) unless( ORDERS.include? @criteria[:order] )
        end
      end

      def validate_countries
        if @criteria.has_key? :country
          raise ArgumentError.new(
            "the given country is not in the available ones: #{COUNTRIES.join(',')}"
          ) unless( (@criteria[:country] - COUNTRIES).size == 0 )
        end
      end

      def validate_max_results
        raise ArgumentError.new(
          'max 50 videos pro categories or country'
        ) unless(
          @criteria[:max_results].to_i < 51 || @criteria[:max_results].to_i == 0
        )
      end

      def available_countries
        COUNTRIES
      end
    end
  end
end
