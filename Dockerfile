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

WORKDIR $HOME
RUN curl -LO https://github.com/Kitware/CMake/releases/download/v3.16.0/cmake-3.16.0-Linux-x86_64.tar.gz \
    && tar xf cmake-3.16.0-Linux-x86_64.tar.gz

ENV PATH=$HOME/cmake-3.16.0-Linux-x86_64/bin:$PATH
WORKDIR $HOME
RUN git clone --depth 1 --branch v1.9.0 https://github.com/ninja-build/ninja

WORKDIR $HOME/ninja
RUN ./configure.py --bootstrap \
    && mkdir /opt/app-root/bin \
    && cp ninja /opt/app-root/bin

WORKDIR $HOME
RUN rm -rf ninja

WORKDIR $HOME
RUN git clone --depth 1 --branch release/9.x https://github.com/llvm/llvm-project

WORKDIR $HOME/llvm-project
RUN INSTALL="-DCMAKE_INSTALL_PREFIX=/opt/app-root/llvm-9" \
    && PROJECTS="-DLLVM_ENABLE_PROJECTS='clang;libcxx;libcxxabi'" \
    && scl enable devtoolset-8 -- cmake -Bbuild -G Ninja -DCMAKE_BUILD_TYPE=Release $INSTALL $PROJECTS llvm \
    && cmake --build build --target install

WORKDIR $HOME
RUN rm -rf llvm-project $HOME/cmake-3.16.0-Linux-x86_64 $HOME/cmake-3.16.0-Linux-x86_64.tar.gz

ENV PATH=/opt/app-root/llvm-9/bin:$PATH
WORKDIR $HOME
RUN git clone --depth 1 https://github.com/mattgodbolt/compiler-explorer ce

WORKDIR $HOME/ce
RUN scl enable rh-nodejs10 -- make dist
RUN rm etc/config/*
COPY c++.local.properties etc/config

CMD scl enable devtoolset-7 devtoolset-8 rh-nodejs10 -- \
    ./node_modules/.bin/supervisor -w app.js,lib/etc/config -e 'js|node|properties' --exec node -- ./app.js 
