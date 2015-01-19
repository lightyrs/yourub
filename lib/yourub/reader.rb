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
          channel_id:   video['snippet']['channelId'],
          category_id:  video['snippet']['categoryId']
          published_at: published_at(video),
          title:        video['snippet']['title'],
          description:  description(video),
          thumbnail:    highest_res_thumbnail(video),
          url:          "https://www.youtube.com/watch?v=#{video_id(video)}",
          latitude:     latitude(video),
          longitude:    longitude(video)
        }
      end

      def video_id(video)
        video['id']
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
      end

      def published_at(video)
        video['snippet']['publishedAt'] || video['recording_details']['recordingDate']
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
      end

      def description(video)
        video['snippet']['description'] || video['snippet']['title']
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
      end

      def highest_res_thumbnail(video)
        thumbs = video['snippet']['thumbnails']
        %w(maxres standard high medium default).each do |size|
          break thumbs[size]['url'] if thumbs[size] && thumbs[size]['url'].present?
        end
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
      end

      def latitude(video)
        geo = video['recordingDetails']['location']
        geo['latitude'].to_f if geo.present?
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
      end

      def longitude(video)
        geo = video['recordingDetails']['location']
        geo['longitude'].to_f if geo.present?
      rescue => e
        puts "#{__method__}"
        puts "#{e.class}: #{e.message}"
      end
    end
  end
end
