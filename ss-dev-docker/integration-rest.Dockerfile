# Multi-stage build for signservice-integration-rest.
# Build context is the integration-rest/ directory.

FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY pom.xml .
# integration-rest master is at 2.4.0-SNAPSHOT but pulls signservice-integration-{xml,impl,pdf}
# via ${sign.integration.version}, also pinned to 2.4.0-SNAPSHOT. The released 2.4.0 jars are on
# Maven Central, so override the property to resolve against the release without editing the pom.
ARG SIGN_INTEGRATION_VERSION=2.4.0
RUN mvn -B -q -Dsign.integration.version=${SIGN_INTEGRATION_VERSION} dependency:go-offline
COPY src src
COPY scripts scripts
RUN mvn -B -q -DskipTests -Dsign.integration.version=${SIGN_INTEGRATION_VERSION} package

FROM eclipse-temurin:21-jre
RUN useradd --system --uid 10001 signservice
WORKDIR /opt/signservice
COPY --from=build /src/target/signservice-integration-rest-*.jar /opt/signservice/signservice-integration-rest.jar
COPY --from=build /src/scripts/start.sh /opt/signservice/start.sh
RUN chmod +rx /opt/signservice/start.sh && mkdir -p /etc/signservice && chown -R signservice /etc/signservice /opt/signservice
USER signservice
ENV JAVA_OPTS="-Djava.net.preferIPv4Stack=true -Dorg.apache.xml.security.ignoreLineBreaks=true"
EXPOSE 8443 8449
ENTRYPOINT ["/opt/signservice/start.sh"]
