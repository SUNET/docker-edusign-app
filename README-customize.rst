
CUSTOMIZATION
=============

Customization of the app relies on providing a directory with assets, here called custom directory,
and setting a number of environment variables.

When providing a custon directory, there is a make command `make customize <path to custom directory>`
to be executed before building the docker images to be deployed.

STYLES
------

It is possible to provide a CSS stylesheet to override any of the basic styles of the site.
Just call the CSS file `custom.css` and add it to the custom directory.

Selectors in CSS rules can be prepended with `.custom-root#root` for higher specificity.

IMAGES
------

Three images can be overriden: The logo for the app `app-logo.png`,
the logo for the company `company-logo.png`, and the favicon `favicon.png`.
The custom images are simply put in the custom directory.

MARKDOWN FILES
--------------

Custom versions for the markdown files found here can be provided,
simply adding them to the custom directory.

ENVIRONMENT VARIABLES
---------------------

COMPANY_LINK:
  the URL for the company web site.

