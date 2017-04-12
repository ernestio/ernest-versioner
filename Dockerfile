FROM ubuntu:16.04

# prerequisites
RUN apt update && apt install git -y

# install languages
RUN git clone https://github.com/rbenv/rbenv.git ~/.rbenv
RUN git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
RUN echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc

RUN rbenv install 2.2.0

RUN wget https://storage.googleapis.com/golang/go1.8.1.linux-amd64.tar.gz
RUN tar -C /usr/local -xzf go1.8.1.linux-amd64.tar.gz
RUN mkdir /opt/go
RUN echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
RUN echo 'export GOPATH=/opt/go' >> ~/.bashrc

RUN source ~/.bashrc

# setup tooling
RUN make deps
RUN make install

ENTRYPOINT /bin/bash
