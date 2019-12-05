# nodejs-10-centos builds on s2i-base-centos7 which builds on s2i-core-centos7
FROM centos/nodejs-10-centos7

USER root

# taken from https://github.com/sclorg/devtoolset-container/blob/master/7-toolchain/Dockerfile
RUN yum install -y centos-release-scl-rh \
    && INSTALL_PKGS="git devtoolset-7-gcc devtoolset-7-gcc-c++ devtoolset-8-gcc devtoolset-8-gcc-c++" \
    && yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS \
    && rpm -V $INSTALL_PKGS \
    && yum -y clean all --enablerepo='*'

EXPOSE 10240

USER default

RUN curl -LO https://github.com/Kitware/CMake/releases/download/v3.16.0/cmake-3.16.0-Linux-x86_64.tar.gz \
    && tar xf cmake-3.16.0-Linux-x86_64.tar.gz

RUN git clone --depth 1 --branch v1.9.0 https://github.com/ninja-build/ninja \
    && cd ninja \
    && ./configure.py --bootstrap \
    && mkdir /opt/app-root/bin \
    && cp ninja /opt/app-root/bin \
    && cd .. \
    && rm -rf ninja

RUN git clone --depth 1 --branch release/9.x https://github.com/llvm/llvm-project \
    && cd llvm-project \
    && mkdir build \
    && cd build \
    && CMAKE="$HOME/cmake-3.16.0-Linux-x86_64/bin/cmake" \
    && INSTALL="-DCMAKE_INSTALL_PREFIX=/opt/app-root/llvm-9" \
    && PROJECTS="-DLLVM_ENABLE_PROJECTS='clang;libcxx;libcxxabi'" \
    && scl enable devtoolset-8 -- $CMAKE -G Ninja -DCMAKE_BUILD_TYPE=Release $INSTALL $PROJECTS ../llvm \
    && ninja install \
    && cd ../.. \
    && rm -rf llvm-project

RUN rm -rf $HOME/cmake-3.16.0-Linux-x86_64 $HOME/cmake-3.16.0-Linux-x86_64.tar.gz

RUN git clone --depth 1 https://github.com/mattgodbolt/compiler-explorer ce \
    && cd ce \
    && scl enable rh-nodejs10 -- make dist

COPY c++.local.properties $HOME/ce/etc/config

CMD scl enable rh-nodejs10 -- \
    ./node_modules/.bin/supervisor -w app.js,lib/etc/config -e 'js|node|properties' --exec node -- ./app.js 
