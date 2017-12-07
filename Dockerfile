FROM cloudfoundry/cflinuxfs2:1.170.0

EXPOSE 8080

LABEL io.openshift.s2i.destination="/opt/s2i/destination" \
      io.openshift.s2i.scripts-url=image:///usr/libexec/s2i

ENV HEROKUISH_VERSION 0.3.33

# CloudFoundry buildpack environment variables
ENV STATICFILE_BUILDPACK_VERSION=1.4.16 \
    JAVA_BUILDPACK_VERSION=4.6 \
    RUBY_BUILDPACK_VERSION=1.7.3 \
    NODEJS_BUILDPACK_VERSION=1.6.8 \
    GO_BUILDPACK_VERSION=1.8.11 \
    PYTHON_BUILDPACK_VERSION=1.5.26 \
    PHP_BUILDPACK_VERSION=4.3.42 \
    BINARY_BUILDPACK_VERSION=1.0.14

ENV CF_STACK=cflinuxfs2 \
    MEMORY_LIMIT=2G

# Variables copied from OpenShift's s2i-base
ENV HOME=/opt/app-root/src
ENV PATH=/opt/app-root/src/bin:/opt/app-root/bin:$PATH \
    TMPDIR=$HOME/tmp \
    STI_SCRIPTS_PATH=/usr/libexec/s2i
# Variables needed by Herokuish for buildpacks
ENV APP_PATH=$HOME/app \
    ENV_PATH=$HOME/tmp/env \
    BUILD_PATH=$HOME/tmp/build \
    CACHE_PATH=$HOME/tmp/cache \
    BUILDPACK_PATH=$HOME/tmp/buildpacks
# Other variables
ENV USER=1001 \
    PORT=8080

# Setup copied from OpenShift's s2i-base
RUN mkdir -p ${HOME}/.pki/nssdb && \
    chown -R 1001:0 ${HOME}/.pki && \
    useradd -u 1001 -r -g 0 -d ${HOME} -s /sbin/nologin -c "Default Application User" default && \
    mkdir -p $TMPDIR && \
    chown -R 1001:0 /opt/app-root

WORKDIR $HOME

# Copy our OpenShift S2I scripts
RUN mkdir -p $STI_SCRIPTS_PATH
COPY bin/assemble bin/run bin/vcap_env /${STI_SCRIPTS_PATH}/

# Install Herokuish to detect and run buildpacks
RUN curl -Lfs https://github.com/gliderlabs/herokuish/releases/download/v{$HEROKUISH_VERSION}/herokuish_${HEROKUISH_VERSION}_linux_x86_64.tgz | tar -xzC /bin && \
    ln -s /bin/herokuish /build && \
    ln -s /bin/herokuish /start && \
    ln -s /bin/herokuish /exec

# Install the CloudFoundry Staticfile buildpack
RUN herokuish buildpack install https://github.com/cloudfoundry/staticfile-buildpack.git v${STATICFILE_BUILDPACK_VERSION} staticfile-buildpack

# Install the CloudFoundry Java buildpack
RUN herokuish buildpack install https://github.com/cloudfoundry/java-buildpack.git v${JAVA_BUILDPACK_VERSION} java-buildpack

# Install the CloudFoundry Ruby buildpack
RUN herokuish buildpack install https://github.com/cloudfoundry/ruby-buildpack.git v${RUBY_BUILDPACK_VERSION} ruby-buildpack

# Install the CloudFoundry NodeJS buildpack
RUN herokuish buildpack install https://github.com/cloudfoundry/nodejs-buildpack.git v${NODEJS_BUILDPACK_VERSION} nodejs-buildpack

# Install the CloudFoundry Go buildpack
RUN herokuish buildpack install https://github.com/cloudfoundry/go-buildpack.git v${GO_BUILDPACK_VERSION} go-buildpack

# Install the CloudFoundry Python buildpack
RUN herokuish buildpack install https://github.com/cloudfoundry/python-buildpack.git v${PYTHON_BUILDPACK_VERSION} python-buildpack

# Install the CloudFoundry PHP buildpack
RUN herokuish buildpack install https://github.com/cloudfoundry/php-buildpack.git v${PHP_BUILDPACK_VERSION} php-buildpack

# Install the CloudFoundry Binary buildpack
RUN herokuish buildpack install https://github.com/cloudfoundry/binary-buildpack.git v${BINARY_BUILDPACK_VERSION} binary-buildpack

# Tie up loose ends
RUN mkdir -p /opt/s2i/destination/src && \
    chmod -R go+rw /opt/s2i/destination && \
    chmod +x $STI_SCRIPTS_PATH/* && \
    mkdir -p $APP_PATH && \
    chown -R $USER:$USER $APP_PATH && \
    chmod -R go+rw $APP_PATH && \
    mkdir -p $HOME/tmp && \
    chown -R $USER:$USER $HOME/tmp && \
    chmod -R go+rw $HOME/tmp && \
    ln -snf $APP_PATH /app

# Herokuish is already running as an unprivileged user so stub out
# any usermod commands it uses.
# TODO: Long-term, fork Herokuish to work natively on CentOS / RHEL
RUN mkdir -p $HOME/bin \
    && echo '' > $HOME/bin/usermod \
    && echo '' > $HOME/bin/chown \
    && echo 'shift\neval "$@"' > $HOME/bin/setuidgid \
    && chmod +x $HOME/bin/*

USER $USER
