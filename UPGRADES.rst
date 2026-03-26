

Upgrade from 1.4.X to 1.5.X
---------------------------

We need to configure signatures with BankID.
For this we need to:

1. Integrate the webapp as an SP in the Sweden Connect federation. To use the sandbox, register here: `https://eid.svelegtest.se/mdreg/home`.

2. Enable signing with BankID. Provide the `edusign-app` container of the webapp with environment variable: `USE_BANKID = True`.

3. Configure and use a dedicated REST API profile that can construct sign requests to be signed with BankID. The `edusign-app` container of the webapp has to be provided with 3 new config variables:

* EDUSIGN_API_PROFILE_BANKID: Name of the profile
* EDUSIGN_API_USERNAME_BANKID: Basic Auth username for the profile
* EDUSIGN_API_PASSWORD_BANKID: Basic Auth password of the profile

4. Configure the `edusign-app` container of the webapp with a variable `BANKID_IDP` with value the entityID of the BankID IdP in Sweden Connect. For the sandbox: `https://sandbox.swedenconnect.se/bankid/idp`;
4. Configure the `edusign-sp` container of the webapp with a variable `BANKID_ENTITY_ID` with value the entityID of the BankID IdP in Sweden Connect. For the sandbox: `https://sandbox.swedenconnect.se/bankid/idp`;

5. Provide the `edusign-sp` container of the webapp with the Sweden Connect metadata. For now we are providing it as an XML local file, and configuring the `edusign-sp` container with an environment variable `BANKID_MD_PATH` with the path to the XML file within the container. For the sandbox, we can cURL the feed from http://eid.svelegtest.se/metadata/mdx/role/idp.xml
