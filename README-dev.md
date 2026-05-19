# SignService dev stack

A docker-compose deployment for local development of:

- **[swedenconnect/signservice](https://github.com/swedenconnect/signservice)** — the Sign Service backend (built from the `demo-apps/app` compound-deployment sample).
- **[idsec-solutions/signservice-integration-rest](https://github.com/idsec-solutions/signservice-integration-rest)** — the IDsec REST integration API used by relying-party applications to build SignRequest / parse SignResponse messages.
- **redis** — backs the integration-rest cache so state survives restarts.

The signservice is wired into the **SWAMID QA federation** (https://mds.swamid.se/qa/). See [SWAMID QA federation integration](#swamid-qa-federation-integration) below for the registration workflow.

Reference docs: <https://docs.swedenconnect.se/signservice/> and <https://wiki.sunet.se/display/SWAMID/Metadata+for+SWAMID+QA>.

```
                  HTTPS:8543/signint           HTTPS:8443/sign/integration-rest/signreq
relying-party  ─────────────────────►  integration-rest  ──────  user browser  ──────►  signservice
   app                  REST                (signs                                       (verifies sig,
                                          SignRequest)                                   authenticates user via SAML,
                                                                                          issues cert, signs document)
                                              │
                                              ▼
                                            redis
```

## Layout

```
.
├── docker-compose.yml          # the stack
├── docker/                     # Dockerfiles (multi-stage maven builds)
├── config/
│   ├── integration-rest/       # mounted at /etc/signservice in the container
│   └── signservice/            # mounted at /etc/signservice in the container
├── scripts/gen-keys.sh         # generates dev keys, extracts signservice cert
├── secrets/                    # generated; gitignored
├── data/signservice/           # SIGNSERVICE_HOME (audit logs, CRL); gitignored
├── integration-rest/           # cloned source; gitignored
└── signservice/                # cloned source; gitignored
```

## Prerequisites

- Docker + Compose v2
- `openssl`
- The two upstream repos cloned at the project root:

  ```bash
  git clone https://github.com/idsec-solutions/signservice-integration-rest.git integration-rest
  git clone https://github.com/swedenconnect/signservice.git signservice
  git clone https://github.com/SUNET/signservice-modules signservice-modules
  ```

## Bring it up

```bash
cp .env.example .env         # then edit SIGNSERVICE_SP_ENTITY_ID, SIGNSERVICE_BASE_URL, etc.
./scripts/gen-keys.sh        # generates RP signing keypair, SAML SP keystore, fetches SWAMID QA trust
docker compose build         # ~3-5 min first run (downloads Maven deps)
docker compose up -d
docker compose logs -f
```

Endpoints (bound to 127.0.0.1):

| Service          | URL                                                     | Notes                                |
|------------------|---------------------------------------------------------|--------------------------------------|
| signservice      | https://localhost:8443/                                 | self-signed `localhost` TLS cert     |
| signservice mgmt | https://localhost:8081/actuator/health                  |                                      |
| integration-rest | https://localhost:8543/signint/v1/                      | basic-auth, see users below          |
| integration-rest | https://localhost:8549/manage/health                    | management port                      |
| redis            | redis://localhost:6379                                  |                                      |

Default integration-rest users (cleartext, dev-only):

| user        | password    | role  | policies |
|-------------|-------------|-------|----------|
| `admin`     | `admin`     | ADMIN | all      |
| `devclient` | `devclient` | USER  | `dev`    |

## Smoke test

Both apps use a self-signed `localhost` cert (alias `localhost`, password `secret` in the bundled `localhost.jks`). Pass `-k` to curl in dev.

```bash
# integration-rest health
curl -sk https://localhost:8549/manage/health

# fetch the dev policy definition
curl -sk -u devclient:devclient https://localhost:8543/signint/v1/policy/get/dev | jq

# signservice health
curl -sk https://localhost:8081/actuator/health
```

A full sample-flow request (`prepare` → `create` → user POSTs to signservice → `process`) is documented in [`integration-rest/docs/sample-flow.md`](integration-rest/docs/sample-flow.md). Replace the sample `destinationUrl` and `signRequesterID` with the values for the `dev` policy.

## How the trust is wired

| from → to                              | what is verified                          | material                                                                  |
|----------------------------------------|-------------------------------------------|---------------------------------------------------------------------------|
| integration-rest signs SignRequest     | signservice trusts the client's cert      | `secrets/integration-rest-signing.{p12,crt}` generated by `gen-keys.sh`. The `.crt` is mounted into signservice as `signservice.engines[0].client.trusted-certificates`. |
| signservice signs SignResponse         | integration-rest verifies it              | `secrets/sign-service-cert.pem`, copied from `signservice/demo-apps/app/src/main/resources/signservice.crt`. Listed under both `sign-service-certificates[]` and `trust-anchors[]` in the dev policy. |
| browser ↔ signservice/integration-rest | TLS                                       | classpath `localhost.jks` from each repo. Self-signed; trust manually in your browser. |

## Configuration entry points

| File                                                             | Purpose                                                                         |
|------------------------------------------------------------------|---------------------------------------------------------------------------------|
| `.env`                                                           | Hostnames, SP entityID, organization metadata (template in `.env.example`).     |
| `config/integration-rest/application-dev.properties`             | Spring Boot overrides for integration-rest (ports, TLS, cache, log levels).     |
| `config/integration-rest/policy-configuration-dev.properties`    | The `dev` signature policy (sign-service URL, certs, attribute mappings to subject DN). |
| `config/integration-rest/signservice-users.properties`           | Basic-auth users.                                                               |
| `config/signservice/application.yml`                             | **Full** signservice config — replaces the demo-app's classpath `application.yml` so SWAMID settings aren't shadowed by Sweden Connect defaults. |

The integration-rest container runs with `application.config.prefix=file:/etc/signservice/`, so all `${application.config.prefix}…` references in the property files resolve into the mounted config dir.

## SWAMID QA federation integration

The signservice is configured as a SAML SP in the [SWAMID QA federation](https://wiki.sunet.se/display/SWAMID/Metadata+for+SWAMID+QA):

- **Federation metadata:** MDQ at `https://mds.swamid.se/qa/`, signed by `swamid-qa.crt` (SHA256 `1E:BC:…D2`). `gen-keys.sh` downloads the cert and verifies the fingerprint.
- **SAML handler:** `default` (generic SAML2 WebSSO). The Sweden Connect handler with SignMessage/SAD extensions is **not** used — SWAMID IdPs don't support those.
- **Entity categories advertised:** REFEDS Research & Scholarship, GÉANT Code of Conduct v2, REFEDS Sirtfi.
- **Requested attributes:** eduPersonPrincipalName + mail (required), displayName, sn, givenName, eduPersonScopedAffiliation, schacHomeOrganization, eduPersonAssurance.
- **Subject DN of the issued signing cert:** built from `eduPersonPrincipalName → serialNumber`, plus optional `givenName`, `sn`, `cn`. Adjust in `config/integration-rest/policy-configuration-dev.properties` if your IdP releases different attributes.

### Registering the SP in SWAMID QA

1. Set the public-facing identity in `.env`:

   ```bash
   SIGNSERVICE_DOMAIN=signservice.dev.example.org
   SIGNSERVICE_BASE_URL=https://signservice.dev.example.org:8443
   SIGNSERVICE_SP_ENTITY_ID=https://signservice.dev.example.org/sp/integration-rest
   SIGNSERVICE_SP_ORG_NAME="My University"
   SIGNSERVICE_SP_CONTACT_EMAIL=signservice-admin@example.org
   ```

   The `entityID` must be a stable URL on a domain you control. SWAMID will not approve `localhost` URLs in production but is generally permissive in QA — for pure-laptop dev, point a `/etc/hosts` entry at 127.0.0.1, or use a tunnel (Cloudflare Tunnel, ngrok) and put the public URL into `.env`.

2. Bring the stack up and fetch the generated SP metadata:

   ```bash
   docker compose up -d
   ./scripts/fetch-sp-metadata.sh        # writes ./secrets/sp-metadata.xml
   ```

3. Open the [SWAMID QA self-service tool](https://metadata.qa.swamid.se/), sign in, and submit the XML. SWAMID staff publish QA entities after a manual review (usually same-day).

4. Once your SP appears in `https://mds.swamid.se/qa/md/swamid-sp.xml`, the SignService can authenticate users via SWAMID QA IdPs. The signservice's MDQ provider will fetch IdP metadata on demand from `https://mds.swamid.se/qa/entities/{sha1-hash}`.

### Keys and trust managed by `gen-keys.sh`

| File                                        | Used by              | Lifetime |
|---------------------------------------------|----------------------|----------|
| `secrets/integration-rest-signing.{p12,crt}` | integration-rest signs SignRequest; signservice trusts the cert | 5 y |
| `secrets/swamid-saml-sp-sign.p12` (alias `sign`) | signservice SAML SP — signs AuthnRequests | 5 y |
| `secrets/swamid-saml-sp-encrypt.p12` (alias `encrypt`) | signservice SAML SP — decrypts incoming assertions | 5 y |
| `secrets/swamid-saml-sp-{sign,encrypt}.crt` | published in the SP metadata uploaded to SWAMID | 5 y |
| `secrets/swamid-qa-md-signer.crt`           | signservice validates the signature on SWAMID federation metadata | re-fetched on rotation |
| `secrets/sign-service-cert.pem`             | integration-rest verifies SignResponse signatures from signservice | bundled, dev-only |

If SWAMID rotates the metadata signing cert, run `./scripts/gen-keys.sh --force` (or just delete `secrets/swamid-qa-md-signer.crt`) and the script will re-download with fingerprint verification — update the fingerprint constant in the script first.

## Limitations of this dev deployment

- **SP entityID must be reachable** by your browser at the URL published in the SP metadata. SWAMID does not retrieve the SP, but the IdP needs to redirect the user back to a URL the user's browser can reach. Localhost works for laptop-only dev as long as your browser is on the same machine.
- **Self-signed TLS** for `localhost.jks`. SWAMID IdPs only redirect the *user's browser* to your assertion-consumer URL, so they don't validate your TLS — but your own browser will warn unless you trust the cert. Replace `localhost.jks` (and update `server.ssl.*` in both apps) before any non-laptop deployment.
- **`{noop}` cleartext passwords** in `signservice-users.properties`. Use `htpasswd -nbB <user> <pass>` and the `{bcrypt}` prefix for anything real.
- **In-memory replay checker.** The compound demo uses an in-memory `MessageReplayChecker`. Fine for one container; for multi-instance deploys you need a Redis-backed implementation (see [Productionalization](https://docs.swedenconnect.se/signservice/application.html) in the upstream docs).

## Rebuilding after upstream changes

```bash
git -C integration-rest pull
git -C signservice pull
docker compose build --no-cache
docker compose up -d --force-recreate
```

## Tearing down

```bash
docker compose down -v
rm -rf secrets data
```
