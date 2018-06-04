# Use the the recommended version [from https://github.com/baskerville/plato/blob/master/doc/BUILD.md]
FROM ubuntu:precise

# By Rohit Goswami
LABEL maintainer="Rohit Goswami <rohit.1995@mail.ru>"
LABEL name="platoBot"

# Suppress debconf errors [from https://github.com/phusion/baseimage-docker/issues/58]
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Suppress policy restart errors [from https://forums.docker.com/t/error-in-docker-image-creation-invoke-rc-d-policy-rc-d-denied-execution-of-restart-start/880]
RUN echo exit 0 > /usr/sbin/policy-rc.d

# Grab faster mirrors [from https://linuxconfig.org/how-to-select-the-fastest-apt-mirror-on-ubuntu-linux]
RUN apt-get update && apt-get install --yes wget
RUN wget http://ftp.au.debian.org/debian/pool/main/n/netselect/netselect_0.3.ds1-26_amd64.deb
RUN dpkg -i netselect_0.3.ds1-26_amd64.deb
RUN rm -rf netselect_*
RUN netselect -s 20 -t 40 $(wget -qO - mirrors.ubuntu.com/mirrors.txt)
RUN sed -i 's/http:\/\/us.archive.ubuntu.com\/ubuntu\//http:\/\/ubuntu.uberglobalmirror.com\/archive\//' /etc/apt/sources.list

# Update apt and get build reqs [from https://github.com/koreader/koreader]
RUN apt-get install --yes curl git libtool automake cmake ragel \
zlib1g-dev libjpeg8-dev libjbig2dec0-dev \
gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf

# Additional build deps
RUN apt-get install -y texinfo libtool m4 \
gettext ccache git

# Clean up APT when done. [Phusion]
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add the build user, update password to build and add to sudo group
ENV USER build
RUN useradd --create-home ${USER} && echo "${USER}:${USER}" | chpasswd && adduser ${USER} sudo

# Switch to the new user by default and make ~/ the working dir
WORKDIR /home/${USER}/

# ccache specifics [https://github.com/stucki/docker-lineageos]
ENV \
    CCACHE_SIZE=50G \
    CCACHE_DIR=$HOME/.ccache \
    USE_CCACHE=1 \
    CCACHE_COMPRESS=1

# Use the shared volume for ccache storage
ENV CCACHE_DIR /home/build/.ccache
RUN ccache -M 50G

# Fix permissions on home
RUN sudo chown -R ${USER}:${USER} /home/${USER}

USER ${USER}

# Setup dummy git config
RUN git config --global user.name "${USER}" && git config --global user.email "${USER}@localhost"

# Get a transfer.sh macro
RUN echo 'transfer() { if [ $# -eq 0 ]; then echo -e "No arguments specified. Usage:\necho transfer /tmp/test.md\ncat /tmp/test.md | transfer test.md"; return 1; fi tmpfile=$( mktemp -t transferXXX ); if tty -s; then basefile=$(basename "$1" | sed -e 's/[^a-zA-Z0-9._-]/-/g'); curl --progress-bar --upload-file "$1" "https://transfer.sh/$basefile" >> $tmpfile; else curl --progress-bar --upload-file "-" "https://transfer.sh/$1" >> $tmpfile ; fi; cat $tmpfile; rm -f $tmpfile; }' >> ~/.bashrc

# Get rust (don't use this)
RUN curl https://sh.rustup.rs -sSf | sh
RUN rustup target add arm-unknown-linux-gnueabihf

# Get Sources
RUN git clone https://github.com/baskerville/plato ~/Git/Github/eReaders/plato

# Setup cargo
RUN touch ~/.cargo/config
RUN echo $'[target.arm-unknown-linux-gnueabihf]\nlinker = "arm-linux-gnueabihf-gcc"\nrustflags = ["-C", "target-feature=+v7,+vfp3,+a9,+neon"]' >> ~/.cargo/config
