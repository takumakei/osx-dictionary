# CLI for OSX Dictionary.app

## INSTALL

```
brew install https://raw.githubusercontent.com/takumakei/osx-dictionary/master/osx-dictionary.rb --HEAD
```

## USAGE

```
usage: osx-dictionary [-a | -A | -d name [-d name]...] [-j] <word> ...
   or: osx-dictionary -l [-A]

options:
    -h, --help            print this
    -d, --dictionary <name>
                          look up words in selected dictionaries
    -a, --active          look up words in active dictionaries
    -A, --all             look up words in all dictionaries
    -j, --json            output in json format
    -l, --list            print list of dictionaries
                          with '-A', print list of all available dictionaries

environment variables:
    OSX_DICTIONARY        A colon-separated list of dictionaries
                          used if there is no dictionary in the command line.
                          You can specify ALL or ACTIVE.
```

## LICENSE

Copyright (c) 2015 takumakei

This software is released under the [MIT License](http://opensource.org/licenses/mit-license.php).
