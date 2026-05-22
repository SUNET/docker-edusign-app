# Build context is ss-dev-src/sigval (the SUNET docker-sigval tree).
#
# The upstream Dockerfile references docker.sunet.se/openjdk-jre-luna:luna7.4-jre21
# (an internal SUNET image with Luna HSM bindings) and pulls the jar via a
# host-side build.sh + GPG verify dance. For local dev we sidestep both:
#   - download the jar from Maven Central inside the build (no GPG verify)
#   - run on public Temurin 21
#   - install softhsm2 to satisfy the PKCS11 lib path referenced in
#     resources/eduSign/application.properties (SVT issuer is disabled, so no
#     tokens are exercised - the lib just needs to be loadable)
#   - listen on plain HTTP; nginx-proxy terminates TLS at the edge

ARG SIGVAL_VERSION=1.3.5

FROM eclipse-temurin:21-jre AS download
ARG SIGVAL_VERSION
WORKDIR /dl
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSLo sigval-service.jar \
      "https://repo1.maven.org/maven2/se/idsec/sigval/sigval-service/${SIGVAL_VERSION}/sigval-service-${SIGVAL_VERSION}.jar"

FROM eclipse-temurin:21-jre
RUN useradd --system --uid 10003 sigval \
 && apt-get update && apt-get install -y --no-install-recommends softhsm2 \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /data /opt/sigval && chown -R sigval /data /opt/sigval
COPY --from=download /dl/sigval-service.jar /opt/sigval/app.jar
COPY resources/eduSign/ /data/
USER sigval
ENV JAVA_OPTS="-Djava.net.preferIPv4Stack=true"
EXPOSE 8080
ENTRYPOINT exec java $JAVA_OPTS -jar /opt/sigval/app.jar --spring.config.additional-location=file:/data/
