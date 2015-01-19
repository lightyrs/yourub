module Yourub
  module Reader
    class << self
      def parse_videos(videos)
        res = videos.data['items']
        return nil if res.empty?
        res.map { |video| parse_video(video) }
      end

      def parse_channels(channels)
        res = channels.data['items']
        return nil if res.empty?
        res
      end

      def parse_video(video)
        {
          id:           video_id(video),
          channel_id:   channel_id(video),
          category_id:  category_id(video),
          published_at: published_at(video),
          title:        title(video),
          description:  description(video),
          thumbnail:    highest_res_thumbnail(video),
          url:          video_url(video),
          duration:     duration_in_seconds(video),
          latitude:     latitude(video),
          longitude:    longitude(video),
          views:        view_count(video)
        }
      end

      def video_id(video)
        video['id']
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
        nil
      end

      def channel_id(video)
        video['snippet']['channelId'] if video['snippet']
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
        nil
      end

      def category_id(video)
        video['snippet']['categoryId'] if video['snippet']
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
        nil
      end

      def published_at(video)
        if video['snippet']
          video['snippet']['publishedAt']
        elsif video['recordingDetails']
          video['recording_details']['recordingDate']
        end
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
        nil
      end

      def title(video)
        video['snippet']['title'] if video['snippet']
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
        nil
      end

      def description(video)
        if video['snippet']
          video['snippet']['description'] || video['snippet']['title']
        end
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
        nil
      end

      def highest_res_thumbnail(video)
        if video['snippet']
          thumbs = video['snippet']['thumbnails']
          %w(maxres standard high medium default).each do |size|
            break thumbs[size]['url'] if thumbs[size] && thumbs[size]['url'].present?
          end
        end
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
        nil
      end

      def video_url(video)
        "https://www.youtube.com/watch?v=#{video_id(video)}"
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
        nil
      end

      def duration_in_seconds(video)
        if video['contentDetails']
          ISO8601::Duration.new(video['contentDetails']['duration']).to_seconds
        end
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
        nil
      end

      def latitude(video)
        geo = video['recordingDetails']['location'] if video['recordingDetails']
        geo['latitude'].to_f if geo.present?
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
        nil
      end

      def longitude(video)
        geo = video['recordingDetails']['location'] if video['recordingDetails']
        geo['longitude'].to_f if geo.present?
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
        nil
      end

      def view_count(video)
        video['statistics']['viewCount'].to_i if video['statistics']
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
        nil
      end
    end
  end
end
