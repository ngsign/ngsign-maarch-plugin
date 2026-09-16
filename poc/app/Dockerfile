# Maarch Courrier 2301 runtime, extended with the native NGSign connector.
#
# Build context MUST be the repository root, not poc/app:
#   docker build -f poc/app/Dockerfile -t ngsign/maarch-poc-app:dev .
#
# Before building, populate poc/app/dist/ with the NGSign-aware Angular build
# described in ../../docs/OPTION_B_FRONTEND_TEST.md.
ARG MAARCH_IMAGE=maarch/maarchcourrier:2301.1.5
FROM ${MAARCH_IMAGE}

USER root

ARG MAARCH_ROOT=/var/www/html/MaarchCourrier
WORKDIR ${MAARCH_ROOT}

# The official runtime image has no Angular toolchain.  The SPA is therefore
# compiled outside of this Docker build and deliberately checked below.
COPY poc/app/dist/ /opt/ngsign-dist/
COPY connector/src/app/external/externalSignatoryBook/ngsign/ \
     ${MAARCH_ROOT}/src/app/external/externalSignatoryBook/ngsign/
COPY poc/app/apply-ngsign-patches.php /usr/local/bin/apply-ngsign-patches.php
COPY poc/app/ngsign.cron /etc/cron.d/ngsign

RUN set -eux; \
    test -f /opt/ngsign-dist/index.html; \
    php /usr/local/bin/apply-ngsign-patches.php "${MAARCH_ROOT}"; \
    cp -a /opt/ngsign-dist/. "${MAARCH_ROOT}/dist/"; \
    rm -rf /opt/ngsign-dist /usr/local/bin/apply-ngsign-patches.php; \
    chmod 0644 /etc/cron.d/ngsign; \
    chown -R www-data:www-data "${MAARCH_ROOT}/src/app/external/externalSignatoryBook/ngsign"; \
    php -l "${MAARCH_ROOT}/src/app/action/controllers/ExternalSignatoryBookTrait.php"; \
    php -l "${MAARCH_ROOT}/src/app/action/controllers/PreProcessActionController.php"; \
    php -l "${MAARCH_ROOT}/bin/signatureBook/process_mailsFromSignatoryBook.php"; \
    php -l "${MAARCH_ROOT}/src/app/external/externalSignatoryBook/ngsign/controllers/NgsignController.php"; \
    php -l "${MAARCH_ROOT}/src/app/external/externalSignatoryBook/ngsign/Infrastructure/NgsignClient.php"

