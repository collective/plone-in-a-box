# syntax=docker/dockerfile:1
# A ready-made Plone in a Box frontend image: the official plone/plone-frontend
# build, plus Volto add-ons and an optional theme. Built by
# .github/workflows/frontend-images.yml, which sets these build arguments:
#
#   PACKAGES        npm packages to install, with exact versions
#   ADDONS          Volto add-ons to load, in order (a theme add-on goes last)
#   THEME           the theme add-on, if any
#   BACKEND_ADDONS  Python packages the backend needs for these add-ons, with
#                   exact versions; setup adds them to ADDONS and activates them
#   SITE_BEHAVIORS  behaviors setup enables on the Plone Site type
#
# The last two only become labels, which setup reads after pulling the image.
ARG VOLTO_VERSION=19
FROM plone/frontend-builder:${VOLTO_VERSION} AS builder
ARG PACKAGES
ARG ADDONS
ARG THEME=""

COPY --chown=node:node pnpm-workspace.yaml /app/
RUN --mount=type=cache,id=pnpm,target=/app/.pnpm-store,uid=1000 <<EOT
    set -e
    ADDONS="${ADDONS}" THEME="${THEME}" node -e '
      const addons = process.env.ADDONS.split(/\s+/).filter(Boolean);
      const theme = process.env.THEME;
      require("fs").writeFileSync("volto.config.js",
        `module.exports = ${JSON.stringify({ addons, theme }, null, 2)};\n`);
    '
    cat volto.config.js
    pnpm add -w ${PACKAGES}
    pnpm build
    rm -rf node_modules
    pnpm install --prod
EOT

FROM plone/frontend-prod-config:${VOLTO_VERSION}
ARG BACKEND_ADDONS=""
ARG SITE_BEHAVIORS=""
LABEL org.plone-in-a-box.backend-addons="${BACKEND_ADDONS}" \
      org.plone-in-a-box.site-behaviors="${SITE_BEHAVIORS}"
COPY --from=builder /app/ /app/
RUN corepack install
