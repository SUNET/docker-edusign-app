# Multi-stage build for SUNET/signservice-modules edusign-signservice app.
# Build context is the signservice-modules/ repo root (ss-dev-src/signservice-modules).
#
# Builds the saml-plugin / keycert-plugin / harica plugins along with the
# signservice-app Spring Boot fat jar. The SUNET app already wires
# SwamidSamlAuthenticationHandlerFactory, so RequestedAuthnContext is not
# enforced against the IdP's assurance-certification metadata.

FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /src
COPY . .
RUN mvn -B -q -DskipTests -pl signservice-app -am package

FROM eclipse-temurin:17-jre
RUN useradd --system --uid 10002 signservice
WORKDIR /opt/signservice
COPY --from=build /src/signservice-app/target/edusign-signservice-*.jar /opt/signservice/signservice.jar
RUN mkdir -p /signservice/data /etc/signservice && chown -R signservice /signservice /etc/signservice /opt/signservice
USER signservice
ENV SIGNSERVICE_HOME=/signservice/data \
    JAVA_OPTS="-Djava.net.preferIPv4Stack=true -Dorg.apache.xml.security.ignoreLineBreaks=true"
EXPOSE 8443 8081
ENTRYPOINT exec java $JAVA_OPTS -jar /opt/signservice/signservice.jar
