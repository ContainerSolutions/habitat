#!/bin/bash

set -e

# fail fast if we aren't on the desired branch or if this is a pull request
if  [[ "${TRAVIS_BRANCH}" != "$(cat VERSION)" && ("${TRAVIS_PULL_REQUEST}" != "false" || "${TRAVIS_BRANCH}" != "master") ]]; then
    echo "We only publish on successful builds of master."
    exit 0
fi

BINTRAY_REPO=unstable
if [ "$(cat VERSION)" == "$TRAVIS_TAG" ]; then
  BINTRAY_REPO=stable
fi

# kick off the mac unstable build
echo "Kicking off the $BINTRAY_REPO mac build"
var_file=/tmp/our-awesome-vars
mac_builder=admin@74.80.245.236

# first update the copy of the habitat code stored on the mac server to the latest
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i /tmp/habitat-srv-admin ${mac_builder} << EOF
    hab_src_dir="\$HOME/code/$TRAVIS_BUILD_NUMBER"
    mkdir -p \${hab_src_dir}
    cd \${hab_src_dir}
    git clone https://github.com/habitat-sh/habitat
    cd habitat
    git checkout $TRAVIS_COMMIT
    chmod 755 support/ci/deploy_mac.sh
EOF

# passing environment variables over ssh is a pain and never worked quite right.
# instead, write this out to a file and scp it over, to source later.
cat << EOF >${var_file}
export BINTRAY_REPO=$BINTRAY_REPO
export HAB_ORIGIN_KEY=$HAB_ORIGIN_KEY
export BINTRAY_USER=$BINTRAY_USER
export BINTRAY_KEY=$BINTRAY_KEY
export BINTRAY_PASSPHRASE=$BINTRAY_PASSPHRASE
export TRAVIS_BUILD=$TRAVIS_BUILD_NUMBER
EOF

scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i /tmp/habitat-srv-admin ${var_file} ${mac_builder}:~/tmp
rm ${var_file}

# kick off the build
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i /tmp/habitat-srv-admin ${mac_builder} \
  "sudo ~/code/habitat/support/ci/deploy_mac.sh"
