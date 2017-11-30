FROM cloudfoundry/cflinuxfs2:1.170.0

ENV HEROKUISH_VERSION 0.3.33
# CloudFoundry buildpack environment variables
ENV \
    STATICFILE_BUILDPACK_VERSION=1.4.16
    JAVA_BUILDPACK_VERSION=4.6
    RUBY_BUILDPACK_VERSION=1.7.3
    NODEJS_BUILDPACK_VERSION=1.6.8
    GO_BUILDPACK_VERSION=1.8.11
    PYTHON_BUILDPACK_VERSION=1.5.26
    PHP_BUILDPACK_VERSION=4.3.42
    BINARY_BUILDPACK_VERSION=1.0.14

ENV \
    CF_STACK=cflinuxfs2 \
    MEMORY_LIMIT=2G

EXPOSE 8080

LABEL io.openshift.s2i.destination="/opt/s2i/destination" \
      io.openshift.s2i.scripts-url=image:///usr/libexec/s2i

ENV \
    # Variables copied from OpenShift's s2i-base
    HOME=/opt/app-root/src \
    PATH=/opt/app-root/src/bin:/opt/app-root/bin:$PATH \
    TMPDIR=$HOME/tmp \
    STI_SCRIPTS_PATH=/usr/libexec/s2i \
    # Variables needed by Herokuish for buildpacks
    APP_PATH=$HOME/app \
    ENV_PATH=$HOME/tmp/env \
    BUILD_PATH=$HOME/tmp/build \
    CACHE_PATH=$HOME/tmp/cache \
    BUILDPACK_PATH=$HOME/tmp/buildpacks \
    # Other variables
    USER=1001 \
    PORT=8080

# Setup copied from OpenShift's s2i-base
RUN mkdir -p ${HOME}/.pki/nssdb && \
    chown -R 1001:0 ${HOME}/.pki && \
    useradd -u 1001 -r -g 0 -d ${HOME} -s /sbin/nologin \
        -c "Default Application User" default && \
    chown -R 1001:0 /opt/app-root

WORKDIR ${HOME}


# Install Herokuish to detect and run buildpacks
RUN curl -Lfs https://github.com/gliderlabs/herokuish/releases/download/v{$HEROKUISH_VERSION}/herokuish_${HEROKUISH_VERSION}_linux_x86_64.tgz | tar -xzC /bin && \
    ln -s /bin/herokuish /build && \
    ln -s /bin/herokuish /start && \
    ln -s /bin/herokuish /exec


# Install the CloudFoundry Staticfile buildpack
RUN mkdir -p $BUILDPACK_PATH/staticfile-buildpack && \
    wget -nv -O /tmp/staticfile-buildpack.zip "https://github.com/cloudfoundry/staticfile-buildpack/releases/download/v${STATICFILE_BUILDPACK_VERSION}/staticfile-buildpack-v${STATICFILE_BUILDPACK_VERSION}.zip" && \
    unzip /tmp/staticfile-buildpack.zip -d $BUILDPACK_PATH/staticfile-buildpack && \
    rm -f /tmp/staticfile-buildpack.zip


# Install the CloudFoundry Java buildpack
RUN mkdir -p $BUILDPACK_PATH/java-buildpack && \
    wget -nv -O /tmp/java-buildpack.zip "https://github.com/cloudfoundry/java-buildpack/releases/download/v${JAVA_BUILDPACK_VERSION}/java-buildpack-offline-v${JAVA_BUILDPACK_VERSION}.zip" && \
    unzip /tmp/java-buildpack.zip -d $BUILDPACK_PATH/java-buildpack/ && \
    rm -f /tmp/java-buildpack.zip


# Install the CloudFoundry Ruby buildpack
RUN mkdir -p $BUILDPACK_PATH/ruby-buildpack && \
    wget -nv -O /tmp/ruby-buildpack.zip "https://github.com/cloudfoundry/ruby-buildpack/releases/download/v${RUBY_BUILDPACK_VERSION}/ruby-buildpack-v${RUBY_BUILDPACK_VERSION}.zip" && \
    unzip /tmp/ruby-buildpack.zip -d $BUILDPACK_PATH/ruby-buildpack/ && \
    rm -f /tmp/ruby-buildpack.zip


# Install the CloudFoundry NodeJS buildpack
RUN mkdir -p $BUILDPACK_PATH/nodejs-buildpack && \
    wget -nv -O /tmp/nodejs-buildpack.zip "https://github.com/cloudfoundry/nodejs-buildpack/releases/download/v${NODEJS_BUILDPACK_VERSION}/nodejs-buildpack-v${NODEJS_BUILDPACK_VERSION}.zip" && \
    unzip /tmp/nodejs-buildpack.zip -d $BUILDPACK_PATH/nodejs-buildpack/ && \
    rm -f /tmp/nodejs-buildpack.zip


# Install the CloudFoundry Go buildpack
RUN mkdir -p $BUILDPACK_PATH/go-buildpack && \
    wget -nv -O /tmp/go-buildpack.zip "https://github.com/cloudfoundry/go-buildpack/releases/download/v${GO_BUILDPACK_VERSION}/go-buildpack-v${GO_BUILDPACK_VERSION}.zip" && \
    unzip /tmp/go-buildpack.zip -d $BUILDPACK_PATH/go-buildpack/ && \
    rm -f /tmp/go-buildpack.zip


# Install the CloudFoundry Python buildpack
RUN mkdir -p $BUILDPACK_PATH/python-buildpack && \
    wget -nv -O /tmp/python-buildpack.zip "https://github.com/cloudfoundry/python-buildpack/releases/download/v${PYTHON_BUILDPACK_VERSION}/python-buildpack-v${PYTHON_BUILDPACK_VERSION}.zip" && \
    unzip /tmp/python-buildpack.zip -d $BUILDPACK_PATH/python-buildpack/ && \
    rm -f /tmp/python-buildpack.zip


# Install the CloudFoundry PHP buildpack
RUN mkdir -p $BUILDPACK_PATH/php-buildpack && \
    wget -nv -O /tmp/php-buildpack.zip "https://github.com/cloudfoundry/php-buildpack/releases/download/v${PHP_BUILDPACK_VERSION}/php-buildpack-v${PHP_BUILDPACK_VERSION}.zip" && \
    unzip /tmp/php-buildpack.zip -d $BUILDPACK_PATH/php-buildpack/ && \
    rm -f /tmp/php-buildpack.zip


# Install the CloudFoundry Binary buildpack
RUN mkdir -p $BUILDPACK_PATH/binary-buildpack && \
    wget -nv -O /tmp/binary-buildpack.zip "https://github.com/cloudfoundry/binary-buildpack/releases/download/v${BINARY_BUILDPACK_VERSION}/binary-buildpack-v${BINARY_BUILDPACK_VERSION}.zip" && \
    unzip /tmp/binary-buildpack.zip -d $BUILDPACK_PATH/binary-buildpack/ && \
    rm -f /tmp/binary-buildpack.zip


# Copy our OpenShift S2I scripts
RUN mkdir -p $STI_SCRIPTS_PATH
COPY bin/assemble bin/run bin/vcap_env /${STI_SCRIPTS_PATH}/

# Tie up loose ends
RUN mkdir -p /opt/s2i/destination/src \
    && chmod -R go+rw /opt/s2i/destination \
    && chmod +x $STI_SCRIPTS_PATH/* \
    && mkdir -p $APP_PATH \
    && chown -R $USER:$USER $APP_PATH \
    && chmod -R go+rw $APP_PATH \
    && mkdir -p $HOME/tmp \
    && chown -R $USER:$USER $HOME/tmp \
    && chmod -R go+rw $HOME/tmp

# Herokuish is already running as an unprivileged user so stub out
# any usermod commands it uses.
# TODO: Long-term, fork Herokuish to work natively on CentOS / RHEL
RUN mkdir -p $HOME/bin \
    && echo '' > $HOME/bin/usermod \
    && echo '' > $HOME/bin/chown \
    && echo 'shift\neval "$@"' > $HOME/bin/setuidgid \
    && chmod +x $HOME/bin/*

# Uncomment to enable debug logging for buildpacks
# ENV TRACE=1 \
#     JBP_LOG_LEVEL=DEBUG

USER $USER
