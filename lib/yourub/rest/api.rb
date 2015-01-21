require 'yourub/rest/search'
require 'yourub/rest/playlists'

module Yourub
  module REST
  # @note WIP, the modules will follow the same grouping used in https://developers.google.com/youtube/v3/docs/.
    module API
      include Yourub::REST::Search
      include Yourub::REST::Playlists
    end
  end
end
