

Upgrade from 1.5.X to 1.6.2
---------------------------

This upgrade makes it possible to run several `edusign-sp` and `edusign-app`
instances behind one hostname (see "Running several instances" in README.rst).
A single-instance deployment is affected by the first two points only.

1. The SP key and certificate, and the HTTPS certificate, live under `KEYDIR`,
   whose default moved from `/etc/ssl` to `/opt/spkeys`. A deployment that
   copies these files into the container must copy them to the new path, or
   set `KEYDIR=/etc/ssl` to keep the old layout. Missing files are still
   generated at start. Mount the directory as a volume, so that the files
   survive the container.

2. The Shibboleth session cookie now carries the session data, encrypted with
   the key in `KEYDIR/private/sealer.keys`, so that any `edusign-sp` instance
   can serve it (Shibboleth session recovery; `relayState` is a cookie too).
   The key is generated on first start when missing. Guard it like the SP
   private key. A session recovered this way has no idle timeout, only the
   fixed lifetime of 8 hours.

3. nginx in `edusign-sp` resolves `BACKEND_HOST` on each request, through the
   DNS server in `RESOLVER` (default `127.0.0.11`, Docker's embedded DNS, which
   exists only on user-defined networks). On the default bridge network, set
   `BACKEND_HOST` to the backend's IP address.

4. New `edusign-sp` variables: `PROXY_NETWORK` (addresses of the proxies / load
   balancers in front of nginx; the client address is then taken from
   `X-Forwarded-For`, which Shibboleth's address check needs), `KEYDIR_REQUIRE`
   (refuse to start when a key file is missing, for several hosts), `RESOLVER`.
   New `edusign-app` variable: `LOG_INSTANCE` (instance part of the gunicorn
   log file names, for a shared logs volume). All default to the previous
   behaviour.

5. Log levels are variables, all defaulting to the previous behaviour. For
   `edusign-sp`: `NGINX_LOG_LEVEL` (`crit`), `SHIB_NATIVE_LOG_LEVEL` (`WARN`,
   the shibauthorizer and shibresponder log) and `SHIBD_LOG_LEVEL` (`INFO`).
   For `edusign-app`: `GUNICORN_LOG_LEVEL` (`info`) and `LOG_LEVEL` (`INFO`,
   the webapp's own messages). An unknown level stops the container at start.
   Two changes for users of `docker-compose.yml`: `DEBUG` now defaults to
   `false` there, matching the image and the README, and
   `MAIL_DEBUG` is its own variable (default `false`) instead of following
   `DEBUG`; set it explicitly to keep SMTP debugging.


Upgrade from 1.4.X to 1.5.2
---------------------------

This upgrade adds the possibility to sign with BankID and Freja+. Both methods
integrate the webapp with the Sweden Connect federation and share most of the
configuration. To enable them:

1. Integrate the webapp as an SP in the Sweden Connect federation. To use the
   sandbox, register here: `https://eid.svelegtest.se/mdreg/home`. The
   AttributeConsumingService should require the personalIdentityNumber
   (urn:oid:1.2.752.29.4.13) attribute.

2. Enable signing with BankID and Freja+. The `edusign-app` container variable
   `ALLOW_BANKID` controls the widget that lets inviters request BankID / Freja+
   signatures, and governs both methods. As of 1.5.2 it defaults to `True`
   (previously `False`); set it explicitly to `False` to hide the widget.

3. Configure dedicated REST API profiles that can construct sign requests to be
   signed with BankID and Freja+. The `edusign-app` container has to be provided
   with these new config variables (one set per method):

   * EDUSIGN_API_PROFILE_BANKID / EDUSIGN_API_PROFILE_FREJA: Name of the profile
   * EDUSIGN_API_USERNAME_BANKID / EDUSIGN_API_USERNAME_FREJA: Basic Auth username for the profile
   * EDUSIGN_API_PASSWORD_BANKID / EDUSIGN_API_PASSWORD_FREJA: Basic Auth password of the profile

4. Configure the `edusign-app` container with the entityIDs of the BankID and
   Freja+ IdPs in Sweden Connect:

   * BANKID_IDP. For the sandbox: `https://sandbox.swedenconnect.se/bankid/idp`
   * FREJA_IDP. For the sandbox: `https://idp-sweden-connect-valfr-2017-sandbox.test.frejaeid.com`

5. Configure the `edusign-sp` container with the same entityIDs, so the
   `/Login/BankID` and `/Login/Freja` SessionInitiators are configured:

   * BANKID_ENTITY_ID
   * FREJA_ENTITY_ID

6. Provide the `edusign-sp` container with the Sweden Connect (eID) metadata. This
   cannot be obtained from an MDQ feed, (shibboleth does not like 2 MDQ feeds), so
   we have to use the published metadata file:

   * MD_FILE_URL: URL of the metadata file
   * MD_SIGNER_CERT: path, within the container, to the md signing certificate
   * MD_SIGNER_CERT_URL: URL to download the feed signing certificate

   For the SWAMID QA feed these point at `https://qa.md.swedenconnect.se/role/idp.xml`.

7. Optionally adjust the attributes used for BankID / Freja+ signatures. The
   defaults match the Swedish SSN / displayName, and can be overridden in the
   `edusign-app` container with (one variable per method):

   * SIGNER_ATTRIBUTES_BANKID / SIGNER_ATTRIBUTES_FREJA: attributes shown in the signature image (default `urn:oid:2.16.840.1.113730.3.1.241,displayName`)
   * AUTHN_ATTRIBUTES_BANKID / AUTHN_ATTRIBUTES_FREJA: attributes used to match the signing and authenticating identities (default `urn:oid:1.2.752.29.4.13,personalIdentityNumber`)
   * BANKID_SSN_ATTR / FREJA_SSN_ATTR: SAML2 attribute carrying the Swedish SSN (default `urn:oid:1.2.752.29.4.13`)

8. The scopes allowed to request BankID / Freja+ signatures are controlled by the
   `EID_WHITELIST` variable on the `edusign-app` container (shared by both
   methods). Default: `sunet.se,eduid.se`. An entry is either
   `<customer id>:<agreement number>:<scope>`, for an institution billed for its
   eID use, or a bare `<scope>`, for one whitelisted without billing. Billing is
   configured with three more variables, the same for every billed institution:

   * EID_QUOTA: authentications (logins and signatures, all eID methods together)
     included in the monthly base price (default `100`)
   * EID_BASE_PRICE: the monthly base price in SEK (default `0`)
   * EXTRA_EID_COST: the price in SEK of each authentication over the quota
     (default `0`)

   The admin dashboard downloads a monthly eID usage report with one line per
   billed institution. The variable was previously named `BANKID_WHITELIST`; the
   old name is still read as a fallback when `EID_WHITELIST` is not set.

9. The admin views at `/admin` are now reachable through the front `edusign-sp`
   (secured by Shibboleth) instead of being blocked by nginx. The `edusign-app`
   container serves them only to the eppn's listed in the new `ADMIN_WHITELIST`
   variable (comma-separated, exact eppn's). Its default is empty, meaning no
   one is allowed, so existing deployments keep `/admin` closed until you set
   it. In-network callers that reach the backend directly (e.g. a cleanup cron
   job) must now send an `Edupersonprincipalname-20` header with a whitelisted
   eppn.

10. Users on networks that present a different client address on successive
    requests are sent back to login on every request, since the Shibboleth SP
    binds a session to the client address. The new `edusign-sp` variable
    `BROKEN_NETWORKS` lists such networks, as a whitespace-separated list of
    CIDR masks (Shibboleth `SessionCache/@unreliableNetworks`). A session is
    kept when the address recorded in it and the current one both lie in one
    listed network. Default: empty, no change in behaviour.

Note for deployments already running a release whose `EID_WHITELIST` entries
carry quotas: the quota forms, `<scope>:<quota>` and
`<scope>:<quota bankid>:<quota freja>`, are no longer accepted. The quota is now
one for all eID methods together and the same for every institution, set with
`EID_QUOTA`. An entry in an old form stops the `edusign-app` container at startup
with an error naming the entry. Rewrite each such entry as
`<customer id>:<agreement number>:<scope>`, or as a bare `<scope>` if the
institution is not billed.
