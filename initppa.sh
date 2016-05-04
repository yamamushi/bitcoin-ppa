#!/bin/bash
# initppa - A script for updating the bitcoinclassic ppa
# Usage:
# ./initppa.sh -b <git branch> -s <commit sha> -v <new version string> -c <changelog> -n <name> -m <email> -p <upstream ppa> 
#
# Branch will typically be "develop"
# -b develop
#
# Commit sha does not have to be the full string, ie:
# -s 841705f6
# 
# Version string must be formatted properly, or things will break upstream, DOUBLE CHECK THIS ie:
# -v 0.12.0-trusty5
#
# Changelog newlines can be formatted with \n , do not include *'s , like so:
# -c 'foo\n bar\n'
# 
# !!! gpg-agent MUST be running with the same key that you're using to upload into launchpad, and it must be associated with your chosen email !!!
# 
# Name in quotes, you can include your nickname here too.
# -n "Will Navidson (yamamushi)"
#
# Email (quotes)
# -m "yamamushi@gmail.com"
#
# Upstream ppa formatted as follows (you can get this from the launchpad page for the ppa you're trying to push into):
# -p ppa:yamamushi/sandbox
#
# As an example of valid usage, the following would push up changes from commit sha '841705f62' into yamamushi's sandbox ppa (assuming you had his private key):
# ./initppa.sh -b develop -s 841705f62 -v 0.12.0-1-trusty1 -c "Testing\n PPA Script\n" -n "Will Navidson" -m "yamamushi@gmail.com" -p ppa:yamamushi/sandbox
#
#
# After you have thoroughly read and understood this readme, change the below variable to YES
README="NO"


if [ $README = "NO" ]; then
    echo "Please check the Readme for this script"
    exit 1
fi

if [ $# -ne 14 ]
    then echo "Usage: initppa.sh -b <git branch> -s <commit sha> -v <new version string> -c <changelog> -n <name> -m <email> -p <upstream ppa>"
    exit 1
fi

# Read Command Line Arguments

while [[ $# > 1 ]]
do
key="$1"
case $key in
    -b|--branch)
    BRANCH="$2"
    shift
    ;;
    -s|--sha)
    COMMIT_SHA="$2"
    shift
    ;;
    -v|--version)
    VERSIONSTRING="$2"
    shift
    ;;
    -c|--changelog)
    CHANGELOG="$2"
    shift
    ;;
    -n|--name)
    NAME="$2"
    shift
    ;;
    -m|--mail)
    EMAIL="$2"
    shift
    ;;    
    -p|--ppa)
    PPA_URL="$2"
    shift
    ;;
    *)
        # Unknown Option
    ;;
esac
shift
done


# Setup Directories
mkdir ~/ppawork
cd ~/ppawork


# Grab Upstream Changes
git clone https://github.com/bitcoinclassic/bitcoinclassic upstream

cd upstream && git checkout $BRANCH && git checkout $COMMIT_SHA
cd ..

# Grab version string
sudo add-apt-repository ppa:bitcoinclassic/bitcoinclassic -y
sudo apt-get update

VERSION=$(grep bitcoind /var/lib/apt/lists/ppa.launchpad.net_bitcoinclassic_bitcoinclassic_ubuntu_dists_trusty_main_binary-amd64_Packages -A 8 | grep Version | awk '{ print $2 }')

# Grab launchpad's latest packages
wget https://launchpad.net/~bitcoinclassic/+archive/ubuntu/bitcoinclassic/+files/bitcoinclassic_$VERSION.debian.tar.gz
wget https://launchpad.net/~bitcoinclassic/+archive/ubuntu/bitcoinclassic/+files/bitcoinclassic_$VERSION.dsc

ORIGVERSION=${VERSION::-8}
wget https://launchpad.net/~bitcoinclassic/+archive/ubuntu/bitcoinclassic/+files/bitcoinclassic_$ORIGVERSION.orig.tar.gz

# Unpack and replay changes over launchpad tgz
tar -xzf bitcoinclassic_$ORIGVERSION.orig.tar.gz
tar -xf bitcoinclassic_$VERSION.debian.tar.gz -C ./bitcoinclassic/

cp -R ./upstream/* ./bitcoinclassic/


# Update changelog
cd ./bitcoinclassic/debian/

DATE=$(date +"%a, %d %b %Y %T %z")

#CHANGELOG=$(echo "$CHANGELOG" | sed 's/\\n/ \n  */g')

# This is backwards on purpose
echo " " | cat - changelog > temp && mv temp changelog
echo " -- $NAME <$EMAIL>  $DATE " | cat - changelog > temp && mv temp changelog
echo " " | cat - changelog > temp && mv temp changelog
echo -e "  * $CHANGELOG" | cat - changelog > temp && mv temp changelog
echo " " | cat - changelog > temp && mv temp changelog
echo "bitcoinclassic ($VERSIONSTRING) trusty; urgency=medium" | cat - changelog > temp && mv temp changelog


# Prepare patches

# Cleanup in case we have an old diff in tmp
if [[ $(ls -A "/tmp/bitcoinclassic_$VERSIONSTRING.diff.*") ]]; then
    rm "/tmp/bitcoinclassic_$VERSIONSTRING.diff.*"
fi

# This command may fail the first time, that is because it can't apply our patches for us, we're going to do that manually if so
debuild -S

if [[ $(ls -A /tmp/bitcoinclassic_$VERSIONSTRING.diff.*) ]]; then
    echo "second pass"
    mv /tmp/bitcoinclassic_${VERSIONSTRING}.diff.* ~/ppawork/bitcoinclassic/debian/patches/bitcoinclassic_${VERSIONSTRING}
    echo "bitcoinclassic_$VERSIONSTRING" >> ~/ppawork/bitcoinclassic/debian/patches/series
    
    # This should now correctly apply our patches
    debuild -S 
fi

# Now upload to launchpad
cd ~/ppawork/ 

dput $PPA "bitcoinclassic_${VERSIONSTRING}_source.changes"
