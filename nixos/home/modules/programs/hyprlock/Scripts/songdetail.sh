#!/usr/bin/env bash

song_info=$(grpcurl -d '{}' grpc-api.amirsalarsafaei.com:443 playground.Spotify/GetRecentlyPlayedSong | jq -r '"\(.track)      \(.artist)"')

echo "$song_info"
