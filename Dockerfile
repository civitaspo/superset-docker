FROM node:10.16.0-stretch as assets-builder

ENV SUPERSET_REPO_ORG         apache
ENV SUPERSET_REPO_NAME        incubator-superset
ENV SUPERSET_VERSION          0.33.0rc1
ENV SUPERSET_ARCHIVE_URL      https://github.com/${SUPERSET_REPO_ORG}/${SUPERSET_REPO_NAME}/archive/${SUPERSET_VERSION}.tar.gz
ENV SUPERSET_ASSETS_DIST_PATH /superset-assets-dist

WORKDIR /
RUN curl -sL ${SUPERSET_ARCHIVE_URL} | tar zx \
 && cd ${SUPERSET_REPO_NAME}-${SUPERSET_VERSION}/superset/assets \
 && npm ci \
 && npm run build \
 && mv dist /superset-assets-dist \
 && cd / \
 && rm -rf ${SUPERSET_REPO_NAME}-${SUPERSET_VERSION}


FROM python:3.6-stretch

# Never prompts the user for choices on installation/configuration of packages
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux

ENV SUPERSET_HOME    /usr/app/superset
ENV SUPERSET_USER    superset
ENV SUPERSET_UID     54321
ENV SUPERSET_GROUP   ${SUPERSET_USER}
ENV SUPERSET_GID     ${SUPERSET_UID}
ENV SUPERSET_SHELL   /bin/bash

# superset details
ENV SUPERSET_REPO_ORG         apache
ENV SUPERSET_REPO_NAME        incubator-superset
ENV SUPERSET_VERSION          0.33.0rc1
ENV SUPERSET_ARCHIVE_URL      https://github.com/${SUPERSET_REPO_ORG}/${SUPERSET_REPO_NAME}/archive/${SUPERSET_VERSION}.tar.gz
ENV SUPERSET_SOURCE_PATH      ${SUPERSET_HOME}/${SUPERSET_REPO_NAME}-${SUPERSET_VERSION}
ENV SUPERSET_APP_PATH         ${SUPERSET_SOURCE_PATH}/superset
ENV SUPERSET_ASSETS_PATH      ${SUPERSET_APP_PATH}/assets
ENV PATH                      ${SUPERSET_APP_PATH}/bin:${PATH}
ENV PYTHONPATH                ${SUPERSET_APP_PATH}:${PYTHONPATH}
ENV SUPERSET_ASSETS_DIST_PATH /superset-assets-dist

# Define en_US.
ENV LANGUAGE    en_US.UTF-8
ENV LANG        en_US.UTF-8
ENV LC_ALL      en_US.UTF-8
ENV LC_CTYPE    en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8
ENV LC_ALL      en_US.UTF-8


COPY --from=assets-builder ${SUPERSET_ASSETS_DIST_PATH} ${SUPERSET_ASSETS_DIST_PATH}

WORKDIR /workspace
COPY requirements-extras.txt .
RUN set -ex \
 && buildDeps=' \
        build-essential \
        libffi-dev \
        libpq-dev \
        libsasl2-dev \
        libssl-dev \
        python3-dev \
        python3-pip \
        zlib1g-dev \
    ' \
 && apt-get update -yqq \
 && apt-get install -yqq --no-install-recommends \
        $buildDeps \
        apt-utils \
        curl \
        locales \
        postgresql-client \
        redis-tools \
        gettext-base \
 && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
 && locale-gen \
 && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
 && mkdir -p $(dirname ${SUPERSET_HOME}) \
 && groupadd -r -g ${SUPERSET_GID} ${SUPERSET_GROUP} \
 && useradd -r -m -N \
        -d ${SUPERSET_HOME} \
        -g ${SUPERSET_GROUP} \
        -s ${SUPERSET_SHELL} \
        -u ${SUPERSET_UID} \
        ${SUPERSET_USER} \
 && curl -sL ${SUPERSET_ARCHIVE_URL} | tar zx -C ${SUPERSET_HOME} \
 && pip install --no-cache-dir -r requirements-extras.txt -r ${SUPERSET_SOURCE_PATH}/requirements.txt \
 && apt-get remove --purge -yqq $buildDeps \
 && apt-get clean \
 && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base \
 && mv ${SUPERSET_ASSETS_DIST_PATH} ${SUPERSET_ASSETS_PATH}/dist \
 && chown ${SUPERSET_USER}:${SUPERSET_GROUP} -R ${SUPERSET_SOURCE_PATH}

USER       ${SUPERSET_USER}
WORKDIR    ${SUPERSET_SOURCE_PATH}

COPY       superset_config.py ${SUPERSET_APP_PATH}
COPY       entrypoint.sh .
ENTRYPOINT ["./entrypoint.sh"]

HEALTHCHECK CMD ["curl", "-f", "http://localhost:8088/health"]
EXPOSE     8088
