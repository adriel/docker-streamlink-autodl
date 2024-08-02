FROM python:3.13.0rc1-slim-bullseye
LABEL maintainer="Adriel"

ENV streamlink_version=6.7.2
ENV twitch_version=1.1.22

RUN apt-get update && apt-get -y install gosu jq ffmpeg

# Streamlink
RUN pip3 install "streamlink==${streamlink_version}"

# Twitch CLI
ADD "https://github.com/twitchdev/twitch-cli/releases/download/v${twitch_version}/twitch-cli_${twitch_version}_Linux_x86_64.tar.gz" /opt/
RUN mkdir "/opt/twitch" && \
  tar -xzf "/opt/twitch-cli_${twitch_version}_Linux_x86_64.tar.gz" -C /opt/twitch && \
	rm "/opt/twitch-cli_${twitch_version}_Linux_x86_64.tar.gz" && \
  mv "/opt/twitch/twitch-cli_${twitch_version}_Linux_x86_64/twitch" "/usr/local/bin/" && \
  rm -r "/opt/twitch/"
RUN ["chmod", "755", "/usr/local/bin/twitch"]
RUN mkdir -p "/.config/twitch-cli"
RUN chown 1000:1000 "/.config/twitch-cli"

RUN mkdir /home/download
RUN mkdir /home/script
RUN mkdir /home/plugins

COPY ./streamlink-recorder.sh /home/script/
COPY ./entrypoint.sh /home/script

RUN ["chmod", "+x", "/home/script/entrypoint.sh"]

ENTRYPOINT [ "/home/script/entrypoint.sh" ]

CMD /bin/bash /home/script/streamlink-recorder.sh "$stream_options" "$stream_link" "$stream_quality" "$stream_name"
