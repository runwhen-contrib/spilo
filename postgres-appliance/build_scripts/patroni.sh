#!/bin/bash

## ----------------
## Install patroni
## ----------------

export DEBIAN_FRONTEND=noninteractive

set -ex

BUILD_PACKAGES=(python3-pip python3-wheel python3-dev git patchutils binutils gcc)

apt-get update

# install most of the patroni dependencies from ubuntu packages
apt-cache depends patroni \
        | sed -n -e 's/.* Depends: \(python3-.\+\)$/\1/p' \
        | grep -Ev '^python3-(sphinx|etcd|consul|kazoo|kubernetes)' \
        | xargs apt-get install -y "${BUILD_PACKAGES[@]}" python3-pystache python3-requests

pip3 install setuptools

if [ "$DEMO" != "true" ]; then
    # zookeeper/kazoo deliberately omitted: python3-kazoo Depends on
    # python3-gevent, and jammy ships gevent 21.8.0 which carries
    # CVE-2023-41419 with no fixed package available for 22.04 (Ubuntu marks
    # jammy "needed"; only noble is not-affected). Nothing in this appliance's
    # deployment uses ZooKeeper as a DCS — the runwhen-platform chart runs
    # Patroni against the Kubernetes DCS exclusively ("no etcd/zookeeper ...
    # the only production-supported mode"), so kazoo was dead weight that
    # existed only to pull in a vulnerable transitive dependency.
    EXTRAS=",etcd,consul,aws"
    apt-get install -y \
        python3-etcd \
        python3-consul \
        python3-boto3 \
        python3-botocore \
        python3-cachetools \
        python3-pyasn1-modules \
        python3-rsa \
        python3-s3transfer

    find /usr/share/python-babel-localedata/locale-data -type f ! -name 'en_US*.dat' -delete

    pip3 install protobuf \
            'git+https://github.com/zalando/pg_view.git@master#egg=pg-view'
else
    EXTRAS=""
fi

pip3 install "patroni[kubernetes$EXTRAS]==$PATRONIVERSION"

for d in /usr/local/lib/python3.10 /usr/lib/python3; do
    cd $d/dist-packages
    find . -type d -name tests -print0 | xargs -0 rm -fr
    find . -type f -name 'test_*.py*' -delete
done
find . -type f -name 'unittest_*.py*' -delete
find . -type f -name '*_test.py' -delete
find . -type f -name '*_test.cpython*.pyc' -delete

# Clean up
apt-get purge -y "${BUILD_PACKAGES[@]}"
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/* \
        /var/cache/debconf/* \
        /root/.cache \
        /usr/share/doc \
        /usr/share/man \
        /usr/share/locale/?? \
        /usr/share/locale/??_?? \
        /usr/share/info
find /var/log -type f -exec truncate --size 0 {} \;
