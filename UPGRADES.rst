

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
   methods). Default: `sunet.se,eduid.se`. Entries can carry the number of paid
   signatures per method, shown as quotas in the admin dashboard:
   `<scope>:<quota bankid>:<quota freja>`, or `<scope>:<quota>` for a common quota.
   The variable was previously named `BANKID_WHITELIST`; the old name is still
   read as a fallback when `EID_WHITELIST` is not set.

9. The admin views at `/admin` are now reachable through the front `edusign-sp`
   (secured by Shibboleth) instead of being blocked by nginx. The `edusign-app`
   container serves them only to the eppn's listed in the new `ADMIN_WHITELIST`
   variable (comma-separated, exact eppn's). Its default is empty, meaning no
   one is allowed, so existing deployments keep `/admin` closed until you set
   it. In-network callers that reach the backend directly (e.g. a cleanup cron
   job) must now send an `Edupersonprincipalname-20` header with a whitelisted
   eppn.
