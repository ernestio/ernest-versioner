FROM ubuntu:16.04

# prerequisites
RUN apt update && apt install git -y

# setup env
ENV PATH $HOME/.rbenv/bin:$PATH
ENV PATH $PATH:/usr/local/go/bin
ENV GOPATH /opt/go

# install languages
RUN git clone https://github.com/rbenv/rbenv.git ~/.rbenv
RUN git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
RUN echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh # or /etc/profile
RUN echo 'eval "$(rbenv init -)"' >> .bashrc

RUN rbenv install 2.2.0

RUN wget https://storage.googleapis.com/golang/go1.8.1.linux-amd64.tar.gz
RUN tar -C /usr/local -xzf go1.8.1.linux-amd64.tar.gz
RUN mkdir /opt/go

# setup tooling
RUN make deps
RUN make install

ENTRYPOINT /bin/bash
