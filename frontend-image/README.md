# Frontend images

Volto add-ons and themes are built into the frontend image; the official `plone/plone-frontend` image can't load
them at runtime. This folder builds frontend images: the official build with Volto add-ons added.
[`.github/workflows/frontend-images.yml`](../.github/workflows/frontend-images.yml) builds one image per entry in
its matrix and publishes it to `ghcr.io/<owner>/plone-in-a-box-frontend`: the ready-made images from
`collective/plone-in-a-box`, and your own images from your fork. Pull requests only build. The images are rebuilt
every Monday, to pick up Volto patch releases.

## Ready-made images

| Image | Frontend | Backend half |
| --- | --- | --- |
| `ghcr.io/collective/plone-in-a-box-frontend:19-vlt` | Volto 19 with Volto Light Theme 8.1.4 | `kitconcept.voltolighttheme==8.1.4`, and the behaviors `voltolighttheme.header`, `.theme` and `.footer` on the site |
| `ghcr.io/collective/plone-in-a-box-frontend:19-juizi-dashboard` | Volto 19 with `volto-juizi-dashboard` 1.0.0-beta.2 | `juizi.dashboard==1.0.0b2` |

Each image has three tags: `:19-vlt` (the latest build), `:19-vlt-<date>` and `:19-vlt-<commit>`
(fixed builds).

To use one, put its name in the **Frontend image** setting when you create the server; see
[Themes and frontend images](../docs/setup-guide.md#themes-and-frontend-images) in the setup guide. Setup reads the
image's labels and sets up the backend half for you.

## Building your own

You need a GitHub account; the build runs on GitHub, so nothing needs installing on your computer.

1. **Fork** [`collective/plone-in-a-box`](https://github.com/collective/plone-in-a-box) on GitHub.
2. In your fork, open the **Actions** tab and click **I understand my workflows, go ahead and enable them**. Forks
   start with workflows turned off.
3. Edit [`.github/workflows/frontend-images.yml`](../.github/workflows/frontend-images.yml) in your fork, and add an
   entry under `matrix: include:`, or replace the `vlt` one. For example, the form block:

   ```yaml
             - variant: formblock
               volto: "19"
               description: the form block
               packages: "volto-form-block@3.20.0"
               addons: "volto-form-block"
               theme: ""
               backend_addons: "collective.volto.formsupport==3.3.3"
               site_behaviors: ""
   ```

   * `variant`: a short name, which becomes the tag (`:19-formblock`)
   * `volto`: the Volto major version, which must match the site's Plone version: Volto 19 for Plone 6.2,
     Volto 18 for Plone 6.1
   * `packages`: npm packages to install, with exact versions (`name@1.2.3`), separated by spaces
   * `addons`: the Volto add-ons to load, in order; a theme add-on goes last
   * `theme`: the theme add-on, if any
   * `backend_addons`: the Python packages the backend needs for these add-ons, at versions matching the frontend's;
     setup installs and activates them
   * `site_behaviors`: behaviors to enable on the Plone Site type, if the add-on's instructions ask for any

   An add-on's README says which npm package, Python package and behaviors it needs.
4. **Commit** to `main`. The workflow builds the image (about 5 minutes) and publishes it as
   `ghcr.io/<your GitHub name>/plone-in-a-box-frontend:19-<variant>`. Watch it in the Actions tab; to build again
   without a change, open **Frontend images** there and click **Run workflow**.
5. **Check that the image is public**, so the server can download it: on your GitHub profile, open **Packages →
   plone-in-a-box-frontend**. If it says **Private**, open **Package settings**, and under **Danger Zone** click
   **Change visibility → Public**. This is needed only once; later builds keep the setting.
6. Put `ghcr.io/<your GitHub name>/plone-in-a-box-frontend:19-<variant>` in the **Frontend image** setting when
   you create a server.

If the build fails, the Actions log shows why; often a package name or version is wrong. A failed build publishes
nothing, so the previous image stays. GitHub turns off the weekly rebuild in a fork after 60 days without commits;
**Run workflow** turns it back on.

### Building on your own computer

With Docker installed, you can build without GitHub Actions and publish the image to any public registry. Build for
`linux/amd64`, the servers' architecture, even on an Apple silicon Mac (use `linux/arm64` for Hetzner's Arm
servers). Building Volto needs about 4 GB of memory for Docker.

```
docker login ghcr.io    # or your registry
docker buildx build --platform linux/amd64 --push \
  --build-arg VOLTO_VERSION=19 \
  --build-arg PACKAGES="volto-form-block@3.20.0" \
  --build-arg ADDONS="volto-form-block" \
  --build-arg BACKEND_ADDONS="collective.volto.formsupport==3.3.3" \
  -t ghcr.io/<you>/my-frontend:19-formblock \
  frontend-image
```

The build arguments are the matrix fields above, in capitals; `THEME` and `SITE_BEHAVIORS` work the same way.

## How setup uses an image

The last two fields become the image labels `org.plone-in-a-box.backend-addons` and
`org.plone-in-a-box.site-behaviors`. After pulling the image, setup reads them, adds the backend add-ons to the
**Backend add-ons** setting, and once the site exists activates them and enables the behaviors. An image without
these labels, for example one built some other way, works too; then install and activate its backend half yourself
(see [Add-ons](../docs/setup-guide.md#add-ons)).

To change the frontend image of an existing server, see
[Themes and frontend images](../docs/setup-guide.md#themes-and-frontend-images).
