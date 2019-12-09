FROM wesleygriffin/llvm-trunk

EXPOSE 10240

USER default

WORKDIR $HOME
RUN git clone --depth 1 https://github.com/mattgodbolt/compiler-explorer ce

WORKDIR $HOME/ce
RUN scl enable rh-nodejs10 -- make dist
RUN rm etc/config/*
COPY c++.local.properties etc/config

CMD scl enable rh-nodejs10 -- \
    ./node_modules/.bin/supervisor -w app.js,lib/etc/config -e 'js|node|properties' --exec node -- ./app.js 
