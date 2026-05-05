# Multi-stage build for the Sweden Connect SignService demo (compound) app.
# Build context is the signservice/ repo root.
#
# `demo-apps/` is a separate Maven reactor (signservice-demo-parent), NOT a
# submodule of the root signservice-parent reactor. It pulls signservice
# artifacts from Maven Central, so we build it via its own reactor pom.

FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /src
COPY . .
RUN mvn -B -q -DskipTests -f demo-apps/pom.xml -pl app -am package

FROM eclipse-temurin:17-jre
RUN useradd --system --uid 10002 signservice
WORKDIR /opt/signservice
COPY --from=build /src/demo-apps/app/target/signservice-demo-app-*.jar /opt/signservice/signservice.jar
RUN mkdir -p /signservice/data /etc/signservice && chown -R signservice /signservice /etc/signservice /opt/signservice
USER signservice
ENV SIGNSERVICE_HOME=/signservice/data \
    JAVA_OPTS="-Djava.net.preferIPv4Stack=true -Dorg.apache.xml.security.ignoreLineBreaks=true"
EXPOSE 8443 8081
ENTRYPOINT exec java $JAVA_OPTS -jar /opt/signservice/signservice.jar
