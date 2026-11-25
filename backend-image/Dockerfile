# A ready-made Plone in a Box backend image: the official plone/plone-backend,
# with newer versions of some packages, and profiles that a new site gets.
# Built by .github/workflows/backend-images.yml, which sets these build
# arguments:
#
#   PLONE_VERSION  the plone/plone-backend tag to start from, such as 6.2
#   PACKAGES       Python requirements to install, separated by spaces, with
#                  version ranges that stay within this Plone release, such as
#                  "plone.volto>=6.2.1,<7"
#   PROFILES       GenericSetup profiles that create-site applies to a new
#                  site, separated by commas
ARG PLONE_VERSION=6.2
FROM plone/plone-backend:${PLONE_VERSION}
ARG PACKAGES
ARG PROFILES=""

# As the image's own user, so Plone can write to these files later.
USER 500:500
COPY hold-versions.py /tmp/hold-versions.py
RUN /app/bin/pip install --no-cache-dir ${PACKAGES} \
 && /app/bin/python /tmp/hold-versions.py ${PACKAGES}
USER root
# The official create-site script applies these after creating the site.
ENV PROFILES=${PROFILES}
