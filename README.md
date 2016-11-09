# Ernest-versioner 

_master: [![CircleCI Master](https://circleci.com/gh/ernestio/ernest-versioner/tree/master.svg?style=svg)](https://circleci.com/gh/ernestio/ernest-versioner/tree/master) | develop: [![CircleCI Develop](https://circleci.com/gh/ernestio/ernest-versioner/tree/develop.svg?style=svg)](https://circleci.com/gh/ernestio/ernest-versioner/tree/develop)_

This software intends to be an automation on the ernest release process. 
It will follow the next steps in order to completely release ernest.

- [x] For each repo will verify if develop and master branches have diverged
- [x] For each repo will merge develop on master and create a release tag
- [x] Creates a github release on ernest-cli
- [x] Uploads to docker-hub every single service
- [x] Generates vagrant package and uploads it to atlas


## Installation

```
make deps && make install
```

## Using versioner

Before running the script you need to be sure all the repos you want to version are listed on ernest-repositories-list.txt file.
Once you're sure these repos are correct, you only need to run the script as follows:

```
$ ruby versioner.rb version NUMBER FILE
```

Where:

- *NUMBER* : is the version number
- *FILE* : a file with the list of the repos to release

So a real example could look like this:

```
$ ruby versioner.rb version 0.0.1 ernest-repositories-list.txt
```

Additionally in case you want to skip some of the inline questions you can define the following environment variables:

- *GITHUB_TOKEN* : In order to merge develop in master, push, create tags...
- *SLACK_WEBHOOK_URL* : In case you want slack to be notifying each release step
- *ATLAS_TOKEN* : In order to upload packaged vagrant boxes

So the command will look like:

```
$ GITHUB_TOKEN=my_token SLACK_WEBHOOK_URL=url ATLAS_TOKEN=token ruby versioner.rb version 0.0.1 ernest-repositories-list.txt
```

## Contributing

Please read through our
[contributing guidelines](CONTRIBUTING.md).
Included are directions for opening issues, coding standards, and notes on
development.

Moreover, if your pull request contains patches or features, you must include
relevant unit tests.

## Versioning

For transparency into our release cycle and in striving to maintain backward
compatibility, this project is maintained under [the Semantic Versioning guidelines](http://semver.org/).

## Copyright and License

Code and documentation copyright since 2015 r3labs.io authors.
Code released under
[the Mozilla Public License Version 2.0](LICENSE).
