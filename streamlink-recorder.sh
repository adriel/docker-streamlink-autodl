#!/usr/bin/env bash

# Check if input is json
function is_json {
  jq -e . >/dev/null 2>&1 <<<"$1"
}

# Test if live
function is_live {
  json="$1"
  is_json "$json" && test "$(echo "$json" | jq --raw-output '.data[0].type')" == "live" # only tests live if json
}

# Returns true only if somewhere in the json there is key + value (not just keys with empty values)
function has_value {
  json="$1"
  echo "$json" | jq -e 'all(.. | strings, arrays; IN("", [], [""])) | not' >/dev/null # true == data, false == no data
}

# Check if API returned message then log if message
# check_api "twitch api json" "json filter"
function check_api {
  channel_json="$1"
  filter="$2"

  # Check if token is missing
  if [[ "$channel_json" =~ "twitch token" || "$channel_json" =~  "Invalid OAuth token" ]]; then
    echo "Token missing, refreshing it.";
    twitch token
    echo "Token refreshed, now waiting for stream to go live."
  elif is_json "$channel_json"; then
    filter_response=$(echo "$channel_json" | jq --raw-output "$filter" 2>&1)
    if has_value "$channel_json" && [[ "$filter_response" != "live" ]]; then # if json has values + not live
      echo "Twitch returned unexpected JSON data."
      echo "filter: $filter"
      echo "filter_response: $filter_response"
      echo "channel_json: $channel_json"
    fi
  elif [[ "$channel_json" =~ "Client.Timeout" ]]; then
    echo "Timeout - couldn't connect to twitch.com - filter: $filter"
  elif [[ "$channel_json" =~ "no route to host" ]]; then
    echo "No route to host - couldn't connect to twitch.com - filter: $filter"
  else
    echo "Unknown response from Twitch."
    echo "filter: $filter"
    echo "channel_json: $channel_json"
  fi
}

echo "Saving config file."
twitch configure --client-id "$client_id" --client-secret "$client_secret"

echo "Waiting for stream to go live."
while [[ true ]]; do

  channel_json=$(twitch api get /streams -q "user_login=${stream_name}" 2>&1)
  check_api "$channel_json" ".data[0].type"

  if is_live "$channel_json"; then
    echo "$stream_name is LIVE!"

    date_unix=$(date +'%s')
    user_name=$(      echo "$channel_json" | jq --raw-output '.data[0].user_name')
    user_id=$(        echo "$channel_json" | jq --raw-output '.data[0].user_id')
    started_at=$(     echo "$channel_json" | jq --raw-output '.data[0].started_at')
    started_at_safe=$(echo "$started_at"   | sed -e 's/[^A-Za-z0-9._-]/./g') # safe name for filesystems
    game_name=$(      echo "$channel_json" | jq --raw-output '.data[0].game_name')
    title=$(          echo "$channel_json" | jq --raw-output '.data[0].title')
    title_safe=$(     echo "$title" | sed -e 's/[^A-Za-z0-9._\(\) -]/./g') # safe name for filesystems
    viewer_count=$(   echo "$channel_json" | jq --raw-output '.data[0].viewer_count')

    echo "user_name: $user_name"
    echo "user_id: $user_id"
    echo "started_at: $started_at"
    echo "started_at_safe: $started_at_safe"
    echo "game_name: $game_name"
    echo "title: $title"
    echo "title_safe: $title_safe"
    echo "viewer_count: $viewer_count"

    save_dir="/home/download/${user_name}/${game_name}"
    mkdir -p "$save_dir"
    max_length=255

    # If filename too long, truncate it
    if [ ${#save_file} -gt $max_length ]; then
      # Calculate the amount of characters to trim from the title
      trim_length=$(( ${#save_file} - max_length ))
      
      # Trim the title
      title_safe="${title_safe:0:$((${#title_safe} - trim_length))}"
    fi
    save_file="${user_name} ${date_unix} ${started_at_safe} ${title_safe} [viewers $viewer_count] (live_dl).mp4"

    streamlink "$stream_link" "$stream_quality" $stream_options --loglevel error --stdout | \
      ffmpeg \
      	-hide_banner \
        -loglevel error \
      	-i pipe: \
        -metadata title="$title" \
        -metadata album_artist="$user_name" \
        -metadata show="$game_name" \
        -c copy \
        -movflags faststart \
        "${save_dir}/${save_file}"

    echo "Stream ended, finished processing. Watching for next live event."
  fi
  sleep 60s
done
