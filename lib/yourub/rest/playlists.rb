require 'yourub/rest/request'

module Yourub
  module REST
    module Playlists

      def playlist_items(criteria)
        begin
          @api_options= {
            :part            => 'snippet',
            :order           => 'relevance',
            :safeSearch      => 'none'
           }

          @videos = []
          @count_filter = {}
          @include_avatars = criteria.delete(:avatars) if criteria.is_a?(Hash) && criteria[:avatars]
          @pages = criteria.is_a?(Hash) && criteria[:pages] ? criteria.delete(:pages) : 1
          @criteria = Yourub::Validator.confirm(criteria)
          playlist_items_by_criteria
        rescue ArgumentError => e
          Yourub.logger.error "#{e}"
        end
      end

      def playlist_items_by_criteria
        merge_criteria_with_api_options
        retrieve_playlist_items
      end

      def merge_criteria_with_api_options
        mappings = { max_results: :maxResults, playlist_id: :playlistId }
        @api_options.merge! @criteria
        @api_options.keys.each do |k|
          @api_options[ mappings[k] ] = @api_options.delete(k) if mappings[k]
        end
      end

      def consume_criteria
        to_consume = @api_options
        yield to_consume
      end

      def retrieve_playlist_items
        consume_criteria do |criteria|
          begin
            @pages.times do |page|
              req = playlist_items_list_request(playlist_params(criteria))
              if @pages > 1
                @nextPageToken = req.data.nextPageToken
                sleep 0.2
              end
              video_ids = req.data.items.map do |playlist_item|
                playlist_item.contentDetails.videoId rescue nil
              end
              params = extended_video_params(video_ids.compact.join(","))
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

      def map_avatars(videos)
        avatar_map = {}

        channel_ids = videos.map { |vid| vid[:channel_id] }.uniq
        params = channel_params(channel_ids.compact.join(","))
        channels = Yourub::Reader.parse_channels(channels_list_request(params))
        channels.each { |channel| avatar_map[ channel['id'] ] = channel['snippet']['thumbnails']['default']['url'] }

        videos.each { |video| video[:avatar] = avatar_map[ video[:channel_id] ] }
      end

      def playlist_items_list_request(params)
        send_request("playlist_items", "list", params)
      end

      def videos_list_request(params)
        send_request("videos", "list", params)
      end

      def send_request(resource_type, method, params)
        Yourub::REST::Request.new(self, resource_type, method, params)
      end

      def playlist_params(criteria)
        criteria = criteria.merge(pageToken: @nextPageToken) if @nextPageToken
        criteria = criteria.merge(part: "id,snippet,contentDetails", fields: default_playlist_fields)
        criteria
      end

      def default_playlist_fields
        URI::encode("nextPageToken,items(contentDetails/videoId)")
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

      def add_videos_to_search_results(entries)
        entries.flatten.each do |entry|
          @videos.push(entry) if Yourub::CountFilter.accept?(entry)
        end
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
