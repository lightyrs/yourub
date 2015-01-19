require 'yourub/rest/request'

module Yourub
  module REST
    module Search

      def search(criteria)
        begin
          @api_options= {
            :part            => 'snippet',
            :type            => 'video',
            :order           => 'relevance',
            :safeSearch      => 'none',
           }

          @categories, @videos = [], []
          @count_filter = {}
          @include_avatars = criteria.delete(:avatars) if criteria.is_a?(Hash) && criteria[:avatars]
          @pages = criteria.is_a?(Hash) && criteria[:pages] ? criteria.delete(:pages) : 1
          @criteria = Yourub::Validator.confirm(criteria)
          search_by_criteria
        rescue ArgumentError => e
          Yourub.logger.error "#{e}"
        end
      end

      def search_by_criteria
        if @criteria.is_a?(String)
          search_one(@criteria)
        elsif @criteria.has_key? :id
          search_one(@criteria[:id])
        else
          search_many
        end
      end

      def search_one(video_id)
        @include_avatars = true
        get_details_and_store(extended_video_params(video_id))
      end

      def search_many
        merge_criteria_with_api_options
        retrieve_categories
        retrieve_videos
      end

      def merge_criteria_with_api_options
        mappings = {query: :q, max_results: :maxResults, country: :regionCode, published_after: :publishedAfter, published_before: :publishedBefore, radius: :locationRadius}
        @api_options.merge! @criteria
        @api_options.keys.each do |k|
          @api_options[ mappings[k] ] = @api_options.delete(k) if mappings[k]
        end
      end

      def retrieve_categories
        if @criteria.has_key? :category
          get_categories_for_country(@criteria[:country])
          @categories = Yourub::Validator.valid_category(@categories, @criteria[:category])
        end
      end

      def retrieve_videos
        consume_criteria do |criteria|
          begin
            @pages.times do |page|
              req = search_list_request(search_params(criteria))
              @nextPageToken = req.data.nextPageToken if @pages > 1
              video_ids = req.data.items.map do |video_item|
                video_item.id.videoId rescue nil
              end
              params = video_params(video_ids.compact.join(","))
              get_details_and_store(params)
            end
          rescue StandardError => e
            Yourub.logger.error "Error #{e} retrieving videos for the criteria: #{criteria.to_s}"
          end
        end
      end

      def get_details_and_store(params)
        videos = Yourub::Reader.parse_videos(videos_list_request(params))
        map_avatars(videos) if @include_avatars
        add_videos_to_search_results(videos) if videos
      end

      def get_categories_for_country(country)
        param = {"part" => "snippet","regionCode" => country }
        categories_list = video_categories_list_request(param)
        categories_list.data.items.each do |cat_result|
          category_name = parse_name(cat_result["snippet"]["title"])
          @categories.push(cat_result["id"] => category_name)
        end
      end

      def consume_criteria
        to_consume = @api_options
        if @criteria[:country]
          @criteria[:country].each do |country|
            to_consume[:regionCode] = country
            consume_categories(to_consume) do |cat|
              yield cat
            end
          end
        else
          yield to_consume
        end
      end

      def consume_categories(to_consume)
        if @categories.size > 0
          @categories.each do |cat|
            to_consume[:videoCategoryId] = cat.keys[0].to_i
            yield to_consume
          end
        else
          yield to_consume
        end
      end

      def map_avatars(videos)
        avatar_map = {}

        channel_ids = videos.map { |vid| vid[:channel_id] }.uniq
        params = channel_params(channel_ids.compact.join(","))
        channels = Yourub::Reader.parse_channels(channels_list_request(params))
        channels.each { |channel| avatar_map[ channel['id'] ] = channel['snippet']['thumbnails']['default']['url'] }

        videos.each { |video| video[:avatar] = avatar_map[ video[:channel_id] ] }
      end

      def search_list_request(params)
        send_request("search", "list", params)
      end

      def videos_list_request(params)
        send_request("videos", "list", params)
      end

      def channels_list_request(params)
        send_request("channels", "list", params)
      end

      def video_categories_list_request(params)
        send_request("video_categories", "list", params)
      end

      def send_request(resource_type, method, params)
        #byebug
        Yourub::REST::Request.new(self, resource_type, method, params)
      end

      def search_params(criteria)
        criteria = criteria.merge(pageToken: @nextPageToken) if @nextPageToken
        criteria.merge(part: "id,nextPageToken,items")
        criteria
      end

      def video_params(video_ids)
        { :id => video_ids,
          :part => "id,snippet,recordingDetails,contentDetails",
          :fields => default_video_fields }
      end

      def default_video_fields
        URI::encode("items(id,snippet/description,snippet/title,snippet/publishedAt,snippet/channelId,snippet/channelTitle,snippet/thumbnails,snippet/categoryId,recordingDetails/recordingDate,recordingDetails/location/latitude,recordingDetails/location/longitude,contentDetails/duration)")
      end

      def extended_video_params(video_ids)
        { :id => video_ids,
          :part => "id,snippet,recordingDetails,contentDetails,statistics",
          :fields => extended_video_fields }
      end

      def extended_video_fields
        URI::encode("items(id,snippet/description,snippet/title,snippet/publishedAt,snippet/channelId,snippet/channelTitle,snippet/thumbnails,snippet/categoryId,recordingDetails/recordingDate,recordingDetails/location/latitude,recordingDetails/location/longitude,contentDetails/duration,statistics/viewCount)")
      end

      def channel_params(channel_ids)
        fields = URI::encode(
          "items(id,snippet/thumbnails/default/url)"
        )
        { :id => channel_ids,
          :part => "id,snippet",
          :fields => fields }
      end

      def add_videos_to_search_results(entries)
        entries.flatten.each do |entry|
          @videos.push(entry) if Yourub::CountFilter.accept?(entry)
        end
      end

      def parse_name(name)
        return name.gsub("/", "-").downcase.gsub(/\s+/, "")
      end

      def get_views(id)
        params = {:id => id, :part => 'statistics'}
        request = videos_list_request(params)
        v = Yourub::Reader.parse_videos(request)
        v ? Yourub::CountFilter.get_views_count(v.first) : nil
      end
    end
  end
end
