# SignService dev stack

A docker-compose deployment for local development of:

- **[SUNET/signservice-modules](https://github.com/SUNET/signservice-modules)** — SUNET's packaging of the Sweden Connect SignService, bundling the SUNET `saml-plugin` (`SwamidSamlAuthenticationHandler` — does not enforce `RequestedAuthnContext` against the IdP's `assurance-certification` metadata, so plain `PasswordProtectedTransport` works against SWAMID IdPs).
- **[idsec-solutions/signservice-integration-rest](https://github.com/idsec-solutions/signservice-integration-rest)** — the IDsec REST integration API used by relying-party applications to build SignRequest / parse SignResponse messages.
- **[SUNET/docker-sigval](https://github.com/SUNET/docker-sigval)** — the eduSign signature validator (`se.idsec.sigval:sigval-service`), used by the webapp to validate signed documents and add SVTs.
- **redis** — backs the integration-rest cache so state survives restarts.

The signservice is wired into the **SWAMID QA federation** (`https://mds.swamid.se/qa/`). See [SWAMID QA federation integration](#swamid-qa-federation-integration) for the registration workflow.

Reference docs: <https://docs.swedenconnect.se/signservice/> and <https://wiki.sunet.se/display/SWAMID/Metadata+for+SWAMID+QA>.

```
                HTTPS                              HTTPS                     HTTPS
relying-party  ──────►  integration-rest  ──── user browser ────►  signservice
   app           REST       (signs                                    (verifies sig,
                          SignRequest)                                authenticates user via SAML,
                              │                                       issues cert, signs document)
                              ▼
                           redis

       relying-party  ──── HTTPS ────►  sigval
          app          (validate +
                       add SVT)
```

## Layout

```
.
├── docker-compose.yml         # the stack
├── ss-dev-docker/             # per-service Dockerfiles
│   ├── signservice.Dockerfile
│   ├── integration-rest.Dockerfile
│   └── sigval.Dockerfile
├── ss-dev-config/             # bind-mounted into containers
│   ├── signservice/           # → /etc/signservice
│   └── integration-rest/      # → /etc/signservice
├── ss-dev-src/                # upstream source trees (gitignored)
│   ├── signservice-modules/   # SUNET; built into signservice container
│   ├── integration-rest/      # IDsec; built into integration-rest container
│   ├── sigval/                # SUNET docker-sigval; sigval container build context
│   ├── signservice/           # swedenconnect base (no longer built; kept for reference)
│   └── validator/             # sig-validation-base library (upstream of sigval-service; reference only)
├── scripts/
│   ├── gen-keys.sh            # generates dev keys, fetches SWAMID QA trust
│   └── fetch-sp-metadata.sh   # pulls the SignService SP metadata for SWAMID upload
├── secrets/                   # generated; gitignored
└── data/signservice/          # SIGNSERVICE_HOME (audit logs, CRL, MDQ cache); gitignored
```

## Prerequisites

- Docker + Compose v2
- `openssl`
- The upstream repos cloned under `ss-dev-src/`:

  ```bash
  cd ss-dev-src
  git clone https://github.com/SUNET/signservice-modules.git
  git clone https://github.com/idsec-solutions/signservice-integration-rest.git integration-rest
  git clone https://github.com/SUNET/docker-sigval.git sigval
  # optional - reference only, not built:
  git clone https://github.com/swedenconnect/signservice.git
  git clone https://github.com/swedenconnect/signature-validation.git validator
  ```

## Bring it up

```bash
cp .env.example .env             # then edit SIGNSERVICE_DOMAIN, SIGNAPI_DOMAIN, SIGVAL_DOMAIN, etc.
./scripts/gen-keys.sh            # generates dev keypairs, fetches SWAMID QA trust
./scripts/extract-builtin-ca.sh  # see "sigval trust anchor" below - one-shot extract
docker compose build             # ~5-10 min first run (downloads Maven deps + sigval jar)
docker compose up -d
docker compose logs -f
```

Endpoints:

| Service          | URL                                                             | Notes                                |
|------------------|-----------------------------------------------------------------|--------------------------------------|
| signservice      | `https://localhost:8443/`                                       | SUNET signservice-modules            |
| signservice mgmt | `https://localhost:8081/actuator/health`                        |                                      |
| integration-rest | `https://localhost:8543/signint/v1/`                            | basic-auth, see users below          |
| integration-rest mgmt | `https://localhost:8549/manage/health`                     |                                      |
| sigval           | `http://localhost:8580/sigval/`                                 | plain HTTP; nginx-proxy terminates TLS at the edge |
| redis            | `redis://localhost:6379`                                        |                                      |

All public-facing TLS is handled by `nginx-proxy` (in front of `signservice`, `integration-rest`, `sigval`, `sp`, `edusign-app`). Hostnames come from `VIRTUAL_HOST` env vars in `docker-compose.yml`; certs from `nginx-acme-companion`.

Default integration-rest users (cleartext, dev-only):

| user        | password    | role  | policies |
|-------------|-------------|-------|----------|
| `admin`     | `admin`     | ADMIN | all      |
| `devclient` | `devclient` | USER  | `dev`    |

## Smoke test

The signservice container's TLS uses `snakeoil.jks` bundled inside the SUNET signservice-app jar (alias `localhost`, password `secret`). The integration-rest container uses the IDsec demo's `localhost.jks`. Both are self-signed — pass `-k` to curl, or hit through nginx-proxy with proper hostnames.

```bash
# integration-rest health
curl -sk https://localhost:8549/manage/health

# fetch the dev policy definition
curl -sk -u devclient:devclient https://localhost:8543/signint/v1/policy/get/dev | jq

# signservice health
curl -sk https://localhost:8081/actuator/health

# sigval health
curl -s  http://localhost:8580/sigval/
```

A full sample-flow request (`prepare` → `create` → user POSTs to signservice → `process`) is documented in [`ss-dev-src/integration-rest/docs/sample-flow.md`](ss-dev-src/integration-rest/docs/sample-flow.md). Replace the sample `destinationUrl` and `signRequesterID` with the values from the `dev` policy in `ss-dev-config/integration-rest/policy-configuration-dev.properties`.

## How the trust is wired

| from → to                              | what is verified                          | material                                                                  |
|----------------------------------------|-------------------------------------------|---------------------------------------------------------------------------|
| integration-rest signs SignRequest     | signservice trusts the client's cert      | `secrets/integration-rest-signing.{p12,crt}` generated by `gen-keys.sh`. The `.crt` is mounted into signservice as `signservice.engines[0].client.trusted-certificates`. |
| signservice signs SignResponse         | integration-rest verifies it              | `secrets/sign-service-cert.pem` — extracted from `ss-dev-src/signservice-modules/signservice-app/src/main/resources/config/signservice.crt`. Listed under `sign-service-certificates[]` and `trust-anchors[]` in the dev policy. |
| signservice issues end-user signer cert | sigval validates the document             | BuiltInCa root (alias `test-ca` in `ss-dev-src/signservice-modules/signservice-app/src/main/resources/config/ca/test-ca.jks`) exported and dropped into `ss-dev-src/sigval/resources/eduSign/trust/sig/`. See [sigval trust anchor](#sigval-trust-anchor) below. |
| browser ↔ each container (via nginx-proxy) | TLS                                   | Let's Encrypt via `nginx-acme-companion`. For laptop-only dev, hit `127.0.0.1:8443` etc. directly and accept the self-signed cert. |
| signservice ↔ SWAMID IdPs              | SAML AuthnRequest signing / assertion encryption | `secrets/swamid-saml-sp-{sign,encrypt}.p12` (alias `sign` / `encrypt`, password `changeit`). |

### sigval trust anchor

The sigval validator's `trust/sig/` folder must contain the root of any CA that issues signer certs your stack will produce. For the BuiltInCa bundled in the SUNET signservice-app:

```bash
docker run --rm \
  -v "$(pwd)/ss-dev-src/signservice-modules/signservice-app/src/main/resources/config/ca:/ca:ro" \
  -v "$(pwd)/ss-dev-src/sigval/resources/eduSign/trust/sig:/out" \
  eclipse-temurin:21-jre \
  keytool -exportcert -keystore /ca/test-ca.jks -storepass secret \
          -alias test-ca -rfc -file /out/signservice-test-ca.crt
docker compose restart sigval
```

The `resources/eduSign/` tree is bind-mounted (`docker-compose.yml`), so dropping a new `.cer`/`.crt` in and restarting picks it up — no rebuild needed.

## Configuration entry points

| File                                                                | Purpose                                                                         |
|---------------------------------------------------------------------|---------------------------------------------------------------------------------|
| `.env`                                                              | Hostnames (`SIGNSERVICE_DOMAIN`, `SIGNAPI_DOMAIN`, `SIGVAL_DOMAIN`), SP entityID, org metadata. Template in `.env.example`. |
| `ss-dev-config/integration-rest/application-dev.properties`         | Spring Boot overrides for integration-rest (ports, TLS, cache, log levels).     |
| `ss-dev-config/integration-rest/policy-configuration-dev.properties`| The `dev` signature policy (sign-service URL, certs, attribute → DN mappings).  |
| `ss-dev-config/integration-rest/signservice-users.properties`       | Basic-auth users and per-user policy authorities.                               |
| `ss-dev-config/signservice/application.yml`                         | **Full** signservice config — replaces the classpath `application.yml` so SUNET / SWAMID settings aren't shadowed. |
| `ss-dev-src/sigval/resources/eduSign/application.properties`        | sigval profile (UI, trust folders, SVT issuer disabled, validator enabled).     |
| `ss-dev-src/sigval/resources/eduSign/trust/`                        | Per-purpose trust anchors (`sig/`, `tsa/`, `svt/`).                             |

The integration-rest container runs with `application.config.prefix=file:/etc/signservice/`, so all `${application.config.prefix}…` references in the property files resolve into the mounted config dir. The signservice container loads its config via `SPRING_CONFIG_LOCATION=file:/etc/signservice/application.yml`, fully replacing the bundled classpath defaults.

## SWAMID QA federation integration

The signservice is configured as a SAML SP in the [SWAMID QA federation](https://wiki.sunet.se/display/SWAMID/Metadata+for+SWAMID+QA):

- **Federation metadata:** MDQ at `https://mds.swamid.se/qa/`, signed by `swamid-qa.crt` (SHA256 in `gen-keys.sh`). The script downloads it and verifies the fingerprint.
- **SAML handler:** SUNET's `SwamidSamlAuthenticationHandlerFactory` (`saml-type: swamid`, from `signservice-modules/saml-plugin`). It strips `RequestedAuthnContext` from the outgoing AuthnRequest unless REFEDS MFA is asked for, so plain `PasswordProtectedTransport` (which SWAMID IdPs don't advertise in `assurance-certification`) doesn't trigger the strict intersection check the upstream `default` handler enforces.
- **Entity categories advertised:** REFEDS Research & Scholarship, GÉANT Code of Conduct v2, REFEDS Sirtfi.
- **Requested attributes:** eduPersonPrincipalName + mail (required), displayName, sn, givenName, eduPersonScopedAffiliation, schacHomeOrganization, eduPersonAssurance.
- **Subject DN of the issued signing cert:** built from `eduPersonPrincipalName → serialNumber`, plus optional `givenName`, `sn`, `cn`. Adjust in `ss-dev-config/integration-rest/policy-configuration-dev.properties` if your IdP releases different attributes.

### Registering the SP in SWAMID QA

1. Set the public-facing identity in `.env`:

   ```bash
   SIGNSERVICE_DOMAIN=signservice.dev.example.org
   SIGNSERVICE_BASE_URL=https://signservice.dev.example.org
   SIGNSERVICE_SP_ENTITY_ID=https://signservice.dev.example.org/sp/integration-rest
   SIGNSERVICE_SP_ORG_NAME="My University"
   SIGNSERVICE_SP_CONTACT_EMAIL=signservice-admin@example.org
   ```

   The `entityID` must be a stable URL on a domain you control. For laptop-only dev, point a `/etc/hosts` entry at `127.0.0.1` or tunnel via Cloudflare/ngrok.

2. Bring the stack up and fetch the generated SP metadata:

   ```bash
   docker compose up -d
   ./scripts/fetch-sp-metadata.sh        # writes secrets/sp-metadata.xml
   ```

3. Open the [SWAMID QA self-service tool](https://metadata.qa.swamid.se/), sign in, and submit the XML.

4. Once your SP appears in `https://mds.swamid.se/qa/md/swamid-sp.xml`, the SignService's MDQ provider will resolve IdP metadata on demand.

### Keys and trust managed by `gen-keys.sh`

| File                                          | Used by              | Lifetime |
|-----------------------------------------------|----------------------|----------|
| `secrets/integration-rest-signing.{p12,crt}`  | integration-rest signs SignRequest; signservice trusts the cert | 5 y |
| `secrets/swamid-saml-sp-sign.p12` (alias `sign`)  | signservice SAML SP — signs AuthnRequests | 5 y |
| `secrets/swamid-saml-sp-encrypt.p12` (alias `encrypt`) | signservice SAML SP — decrypts incoming assertions | 5 y |
| `secrets/swamid-saml-sp-{sign,encrypt}.crt`   | published in the SP metadata uploaded to SWAMID | 5 y |
| `secrets/swamid-qa-md-signer.crt`             | signservice validates the signature on SWAMID federation metadata | re-fetched on rotation |
| `secrets/sign-service-cert.pem`               | integration-rest verifies SignResponse signatures | bundled, dev-only |

> **Note:** the bundled `gen-keys.sh` copies `sign-service-cert.pem` from the legacy `ss-dev-src/signservice/demo-apps/app/src/main/resources/signservice.crt`. The active build uses SUNET's signservice-modules, whose response-signing cert lives at `ss-dev-src/signservice-modules/signservice-app/src/main/resources/config/signservice.crt`. Run `cp ss-dev-src/signservice-modules/signservice-app/src/main/resources/config/signservice.crt secrets/sign-service-cert.pem` after `gen-keys.sh` (or update the script).

If SWAMID rotates the metadata signing cert, update the fingerprint constant in `gen-keys.sh` and run `./scripts/gen-keys.sh --force`.

## Limitations of this dev deployment

- **SP entityID must be reachable** by your browser at the URL published in the SP metadata. SWAMID does not retrieve the SP, but the IdP redirects the user back to your assertion-consumer URL.
- **Self-signed TLS** on the in-container `localhost`/`snakeoil` keystores. nginx-proxy serves real certs to the world; inside the docker network, services still use self-signed certs. Replace before any non-laptop deployment.
- **`{noop}` cleartext passwords** in `signservice-users.properties`. Use `htpasswd -nbB <user> <pass>` and `{bcrypt}` for anything real.
- **In-memory replay checker** in signservice. Fine for one container; multi-instance deploys need a Redis-backed implementation (see [Productionalization](https://docs.swedenconnect.se/signservice/application.html)).
- **sigval SVT issuance is disabled.** `resources/eduSign/application.properties` sets `sigval-service.svt.issuer-enabled=false`. Validation only. The container overrides `keySourceType=create` (ephemeral self-signed key) via `SPRING_APPLICATION_JSON` so no SoftHSM bootstrap is needed.

## Rebuilding after upstream changes

```bash
git -C ss-dev-src/signservice-modules pull
git -C ss-dev-src/integration-rest    pull
git -C ss-dev-src/sigval              pull
docker compose build --no-cache
docker compose up -d --force-recreate
```

## Tearing down

```bash
docker compose down -v
rm -rf secrets data
```
