# Multi-stage build for signservice-integration-rest.
# Build context is the integration-rest/ directory.

FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY pom.xml .
# Since 2.4.1 the pom names release versions only, all on Maven Central, so the
# build needs no version override.
RUN mvn -B -q dependency:go-offline
COPY src src
COPY scripts scripts
RUN mvn -B -q -DskipTests package

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
