#!/usr/bin/env python3
"""Delete old builds of the ready-made frontend and backend images.

Run by .github/workflows/frontend-images.yml and backend-images.yml after the
builds. Every build is one package version in ghcr.io/<owner>/<PACKAGE>
(plone-in-a-box-frontend or plone-in-a-box-backend), tagged <image>,
<image>-<date> and <image>-<commit> (for example 19-vlt, 19-vlt-2026-11-22,
19-vlt-a1b2c3d; a build replaced later the same day keeps only its commit tag), plus untagged child versions (the image for each platform,
and their provenance attestations) that the tagged one points to.

What it deletes:
  - builds of an image in addons.yml, beyond the newest KEEP_BUILDS
    (default 26, about six months of weekly builds); the newest build, the one
    with the plain <image> tag, is always kept;
  - builds of a test image (a name containing "test", not in the list) older
    than TEST_DAYS days (default 7);
  - the untagged children of the builds it deletes, unless a kept build
    points to them too.

It never deletes untagged versions on their own, nor builds of images that
are no longer in the list but aren't test images: servers may still use them.

The images in addons.yml are, for the frontend package, the entries with
packages (built from it), and for the backend package, the backend_image tags
of entries that name ghcr.io/<anyone>/plone-in-a-box-backend.

Environment: GITHUB_TOKEN (packages: write), OWNER, PACKAGE (default
plone-in-a-box-frontend), CATALOG (addons.yml, the list of images), DRY_RUN=1 to only report, and optionally
KEEP_BUILDS and TEST_DAYS. With VERSIONS_FILE (a JSON list of versions as the
API returns them), it only reports what it would delete, for testing.
"""
import datetime
import json
import os
import re
import sys
import urllib.error
import urllib.request

PACKAGE = os.environ.get("PACKAGE") or "plone-in-a-box-frontend"
API = "https://api.github.com"
DATED = re.compile(r"^(?P<image>.+)-(?P<date>\d{4}-\d{2}-\d{2})$")
# A build that another one replaced on the same day keeps only its commit tag.
COMMIT = re.compile(r"^(?P<image>.+)-[0-9a-f]{7}$")
INDEX_TYPES = ", ".join([
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
    "application/vnd.oci.image.manifest.v1+json",
    "application/vnd.docker.distribution.manifest.v2+json",
])


def say(message):
    print(message, flush=True)


def request(url, token=None, method="GET", accept="application/vnd.github+json"):
    headers = {"Accept": accept, "User-Agent": "plone-in-a-box-image-cleanup"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=30) as response:
        body = response.read()
        return json.loads(body) if body else None


def images_in_catalog(path, package=PACKAGE):
    """The tags of this package's images that addons.yml uses."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import catalog
    entries = catalog.read(path)
    if package == "plone-in-a-box-frontend":
        return [f"{e['volto']}-{e['id']}" for e in entries if catalog.has_image(e)]
    found = []
    for e in entries:
        m = re.fullmatch(rf"ghcr\.io/[^/]+/{re.escape(package)}:(.+)", e["backend_image"])
        if m:
            found.append(m.group(1))
    return found


def owner_path(owner, token):
    kind = request(f"{API}/users/{owner}", token)["type"]
    return f"{API}/{'orgs' if kind == 'Organization' else 'users'}/{owner}/packages/container/{PACKAGE}"


def list_versions(base, token):
    versions, page = [], 1
    while True:
        batch = request(f"{base}/versions?per_page=100&page={page}", token)
        versions += batch
        if len(batch) < 100:
            return versions
        page += 1


def children(owner, digest, cache={}):
    """The digests a version's manifest points to (none for a plain image)."""
    if digest not in cache:
        if "registry" not in cache:
            url = f"https://ghcr.io/token?scope=repository:{owner}/{PACKAGE}:pull"
            cache["registry"] = request(url, accept="application/json")["token"]
        try:
            manifest = request(f"https://ghcr.io/v2/{owner}/{PACKAGE}/manifests/{digest}",
                               cache["registry"], accept=INDEX_TYPES)
            cache[digest] = {m["digest"] for m in manifest.get("manifests", [])}
        except urllib.error.HTTPError:
            cache[digest] = None  # unknown: don't delete anything it might point to
    return cache[digest]


def plan(versions, images, keep_builds, test_days, now):
    """(builds to delete, builds kept), as lists of versions."""
    builds = {}
    for version in versions:
        tags = version.get("metadata", {}).get("container", {}).get("tags", [])
        match = next((m for m in map(DATED.match, tags) if m), None) \
            or next((m for m in map(COMMIT.match, tags) if m), None)
        if match:
            builds.setdefault(match["image"], []).append(version)
    delete, keep = [], []
    for image, found in builds.items():
        found.sort(key=lambda v: v["created_at"], reverse=True)
        for n, version in enumerate(found):
            tags = version["metadata"]["container"]["tags"]
            created = datetime.datetime.fromisoformat(version["created_at"].replace("Z", "+00:00"))
            if image in images:
                old = n >= keep_builds and image not in tags
            elif "test" in image:
                old = now - created > datetime.timedelta(days=test_days)
            else:
                old = False
            (delete if old else keep).append(version)
    return delete, keep


def main():
    owner = os.environ["OWNER"]
    images = images_in_catalog(os.environ.get("CATALOG", "addons.yml"))
    keep_builds = int(os.environ.get("KEEP_BUILDS") or 26)
    test_days = int(os.environ.get("TEST_DAYS") or 7)
    now = datetime.datetime.now(datetime.timezone.utc)
    say(f"{PACKAGE} images in addons.yml: {', '.join(images) or 'none'}; keeping {keep_builds} builds of each, "
        f"test images for {test_days} days")

    if os.environ.get("VERSIONS_FILE"):
        versions = json.load(open(os.environ["VERSIONS_FILE"], encoding="utf-8"))
        delete, keep = plan(versions, images, keep_builds, test_days, now)
        for version in delete:
            say(f"would delete {', '.join(version['metadata']['container']['tags'])}")
        return 0

    token = os.environ["GITHUB_TOKEN"]
    dry = os.environ.get("DRY_RUN") in ("1", "true")
    try:
        base = owner_path(owner, token)
        versions = list_versions(base, token)
    except urllib.error.HTTPError as e:
        say(f"::warning::Couldn't list the image versions ({e.code}); nothing was deleted")
        return 0
    delete, keep = plan(versions, images, keep_builds, test_days, now)
    by_digest = {v["name"]: v for v in versions}
    kept_children = set()
    for version in keep:
        kept_children |= children(owner, version["name"]) or set()

    deleted = 0
    for version in delete:
        tags = ", ".join(version["metadata"]["container"]["tags"])
        kids = children(owner, version["name"])
        if kids is None:
            say(f"skipped {tags}: its manifest couldn't be read")
            continue
        targets = [version] + [by_digest[d] for d in sorted(kids)
                               if d in by_digest and d not in kept_children
                               and not by_digest[d]["metadata"]["container"]["tags"]]
        if dry:
            say(f"would delete {tags} ({len(targets)} versions)")
            continue
        try:
            for target in targets:
                request(f"{base}/versions/{target['id']}", token, method="DELETE")
            deleted += 1
            say(f"deleted {tags} ({len(targets)} versions)")
        except urllib.error.HTTPError as e:
            say(f"::warning::Couldn't delete {tags} ({e.code}); stopping")
            break
    say(f"{'Would delete' if dry else 'Deleted'} {len(delete) if dry else deleted} of "
        f"{len(delete) + len(keep)} builds")
    return 0


if __name__ == "__main__":
    sys.exit(main())
