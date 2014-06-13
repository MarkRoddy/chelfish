#!/bin/bash

set -e


# Sensible defaults (he told himself)
ROOT=~/.chelfish
CHEFREPO="$ROOT/chef"
CONFIG="$ROOT/config.rb"
CACHEDIR="$ROOT/cache"

function install-if-missing () {
    cmd="$1"
    package="$2"
    if [ -z "$package" ]; then
	package="$cmd";
    fi
    RELEASE=`lsb_release --id --short`
    if ! which $cmd &> /dev/null; then
	if [ "Ubuntu" == "$RELEASE" ]; then
            echo -n "Installing $cmd... ";
            sudo apt-get install "$package" --assume-yes > /dev/null
            echo "done";
	else
            # Feel free to add your OS above
            echo "please install $cmd before continuing";
            exit 1;
	fi
    fi
}
    

if [ 2 != $# ]; then
    echo "usage: $0 git-repo solo-attr-in-repo"
    exit 1
fi

REMOTEREPO="$1"
JSON="$CHEFREPO/$2"

# Warm the sudo password cache
sudo ls > /dev/null

# Check for dependencies, install as required

install-if-missing git
install-if-missing curl

if ! which chef-solo &> /dev/null; then
    echo -n "Installing chef... "
    curl -L https://www.opscode.com/chef/install.sh | sudo bash > /dev/null
    echo "done"
fi


# Create directories as needed
if [ ! -d "$ROOT" ]; then
    mkdir "$ROOT";
fi
if [ ! -d "$CACHEDIR" ]; then
    mkdir "$CACHEDIR";
fi

# Make sure we have the latest copy of the chef repo
if [ ! -d "$CHEFREPO" ]; then
    git clone $REMOTEREPO "$CHEFREPO"
fi
pushd "$CHEFREPO";
status=`git status --short|grep -v ^$ || true`
if [ -z "$status" ]; then
    git pull --rebase;
else
    echo "There are unstaged files, skipping git pull";
fi
popd;

if [ ! -f "$JSON" ]; then
    echo "no such json attribut file: $JSON";
    exit 1;
fi

# Generate the config file
echo "
# Forces an ohai run which doesn't happen by default
require 'rubygems'
require 'ohai'
o = Ohai::System.new
o.all_plugins

file_cache_path \"$CACHEDIR\"
cookbook_path \"$CHEFREPO/cookbooks\"
role_path \"$CHEFREPO/roles\"
" > "$CONFIG"


# Now, let's actually do our thing
sudo chef-solo --config "$CONFIG" --json-attributes "$JSON"

