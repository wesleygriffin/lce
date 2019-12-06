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

ARG CMAKE_VER=3.16.0
ENV CMAKE_URL=https://github.com/Kitware/CMake/releases/download/v$CMAKE_VER/cmake-$CMAKE_VER-Linux-x86_64.tar.gz

WORKDIR $HOME
RUN curl -LO $CMAKE_URL && tar xf cmake-$CMAKE_VER-Linux-x86_64.tar.gz

WORKDIR $HOME
RUN git clone --depth 1 --branch v1.9.0 https://github.com/ninja-build/ninja

WORKDIR $HOME/ninja
RUN ./configure.py --bootstrap \
    && mkdir /opt/app-root/bin \
    && cp ninja /opt/app-root/bin

WORKDIR $HOME
RUN git clone https://github.com/llvm/llvm-project

ENV CMAKE=$HOME/cmake-3.16.0-Linux-x86_64/bin/cmake \
    LLVM_PROJECTS="-DLLVM_ENABLE_PROJECTS='clang;libcxx;libcxxabi'" \
    LLVM_TARGETS="-DLLVM_TARGETS_TO_BUILD='X86'" \
    LLVM_OPTIONS="-G Ninja -DCMAKE_BUILD_TYPE=Release"

WORKDIR $HOME/llvm-project
RUN git checkout release/9.x \
    && INSTALL="-DCMAKE_INSTALL_PREFIX=/opt/app-root/llvm-9" \
    && scl enable devtoolset-8 -- $CMAKE -Bbuild $LLVM_OPTIONS $INSTALL $LLVM_PROJECTS $LLVM_TARGETS llvm \
    && $CMAKE --build build --target install

RUN git checkout master \
    && INSTALL="-DCMAKE_INSTALL_PREFIX=/opt/app-root/llvm-trunk" \
    && scl enable devtoolset-8 -- $CMAKE -Bbuild $LLVM_OPTIONS $INSTALL $LLVM_PROJECTS $LLVM_TARGETS llvm \
    && $CMAKE --build build --target install

WORKDIR $HOME
RUN git clone --depth 1 https://github.com/mattgodbolt/compiler-explorer ce

WORKDIR $HOME/ce
RUN scl enable rh-nodejs10 -- make dist
RUN rm etc/config/*
COPY c++.local.properties etc/config

CMD scl enable rh-nodejs10 -- \
    ./node_modules/.bin/supervisor -w app.js,lib/etc/config -e 'js|node|properties' --exec node -- ./app.js 
