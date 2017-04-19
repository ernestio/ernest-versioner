FROM ubuntu:17.04

# prerequisites
RUN apt update && apt install -y git build-essential wget libffi-dev zlib1g-dev libssl-dev libreadline-dev libyaml-dev libxml2-dev libxslt-dev

# setup env
ENV PATH /root/.rbenv/bin:$PATH
ENV PATH $PATH:/usr/local/go/bin
ENV PATH $PATH:/opt/go/bin
ENV GOPATH /opt/go

ADD . /root/
WORKDIR /root/

# install languages
RUN git clone https://github.com/rbenv/rbenv.git ~/.rbenv
RUN git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
RUN echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh # or /etc/profile
RUN echo 'eval "$(rbenv init -)"' >> .bashrc
RUN rbenv install 2.4.0
RUN rbenv global 2.4.0

RUN wget https://storage.googleapis.com/golang/go1.8.1.linux-amd64.tar.gz
RUN tar -C /usr/local -xzf go1.8.1.linux-amd64.tar.gz
RUN mkdir /opt/go

# setup tooling
RUN bash -l -c 'cd /root/ && make deps'
RUN bash -l -c 'cd /root/ && make install'


# switch to https for git
RUN sed -i s%git@github.com:ernestio/ernest-versioner%https://github.com/ernestio/ernest-versioner.git%g .git/config

ENTRYPOINT ./entrypoint.sh
