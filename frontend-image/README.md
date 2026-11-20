# Ready-made frontend images

The official `plone/plone-frontend` build with Volto add-ons added.
[`.github/workflows/frontend-images.yml`](../.github/workflows/frontend-images.yml) builds one image per
entry in its matrix and publishes it to `ghcr.io/<owner>/plone-in-a-box-frontend`: the real images from
`collective/plone-in-a-box`, test images from forks. Pull requests only build. The images are rebuilt
every Monday, to pick up Volto patch releases.

| Image | Frontend | Backend half |
| --- | --- | --- |
| `:19-vlt` | Volto 19 with Volto Light Theme 8.1.4 | `kitconcept.voltolighttheme==8.1.4`, and the behaviors `voltolighttheme.header`, `.theme` and `.footer` on the site |

Each image has three tags: `:19-vlt` (the latest build), `:19-vlt-<date>` and `:19-vlt-<commit>`
(fixed builds).

## Adding an image

Add a matrix entry with exact versions:

* `packages`: npm packages to install
* `addons`: Volto add-ons to load, in order; a theme add-on goes last
* `theme`: the theme add-on, if any
* `backend_addons`: Python packages the backend needs, at versions matching the frontend's
* `site_behaviors`: behaviors to enable on the Plone Site type

The last two become the image labels `org.plone-in-a-box.backend-addons` and
`org.plone-in-a-box.site-behaviors`, which setup will read to install the backend half.

## Trying an image on a box

Until setup has a setting for it, change the frontend's `image:` line in `/opt/plone/docker-compose.yml`,
then run `docker compose --project-directory /opt/plone up -d frontend`. Install the backend half with the
`ADDONS` setting, activate it in Site Setup → Add-ons, and enable the behaviors under Site Setup → Content
Types → Plone Site.
