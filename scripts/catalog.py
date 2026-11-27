#!/usr/bin/env python3
"""The add-on catalog (addons.yml): checks it, and makes what's built from it.

  python3 scripts/catalog.py check    check the entries, and that docs/try/ is
                                      up to date (CI runs this)
  python3 scripts/catalog.py pages    write the Try It pages in docs/try/
  python3 scripts/catalog.py matrix   print the frontend image builds, as a
                                      GitHub Actions matrix (JSON)
  python3 scripts/catalog.py images   check that the ready-made images can be
                                      pulled without logging in, and are built
                                      for the right platforms (CI runs this)

No dependencies: addons.yml is a list of flat entries, which this reads
itself (see the comments at the top of addons.yml).
"""
import html
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from urllib.parse import quote

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "addons.yml")
PAGES = os.path.join(ROOT, "docs", "try")

KEYS = ("id name description url volto packages addons theme backend_addons site_behaviors demo_roles "
        "frontend_image backend_image arm try_it try_hint linode_stackscript").split()
IMAGE_OWNER = "collective"
SITE = "https://collective.github.io/plone-in-a-box"
REPO = "https://github.com/tkimnguyen/plone-in-a-box"
DISCORD = "https://discord.gg/jRrsnYkNvS"
DISCORD_CHANNEL = "https://discord.com/channels/786421998426521600/903993234248835082"  # opens only for people already in the Plone Discord
LINODE_STACKSCRIPT = "931893"
TEMPLATE_URL = "https://plone-in-a-box-templates.s3.us-east-1.amazonaws.com/latest/cloudformation.yaml"
NOT_FOR_DEMO = {"Manager", "Owner", "Authenticated", "Anonymous"}


class CatalogError(Exception):
    pass


def unquote(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    if value.startswith(("\"", "'")):
        raise CatalogError(f"unbalanced quote: {value}")
    return value


def read(path=CATALOG):
    """The entries, as dicts of strings, in order."""
    entries = []
    for number, line in enumerate(open(path, encoding="utf-8"), 1):
        text = line.rstrip("\n")
        if not text.strip() or text.lstrip().startswith("#"):
            continue
        m = re.match(r"^(- |  )([a-z_]+):(?: (.*))?$", text)
        if not m:
            raise CatalogError(f"addons.yml line {number}: expected '- id: ...' or '  key: value'")
        start, key, value = m.group(1), m.group(2), unquote(m.group(3) or "")
        if start == "- ":
            if key != "id":
                raise CatalogError(f"addons.yml line {number}: an entry starts with '- id:'")
            entries.append({})
        elif not entries:
            raise CatalogError(f"addons.yml line {number}: before the first entry")
        if key not in KEYS:
            raise CatalogError(f"addons.yml line {number}: unknown key {key}")
        if key in entries[-1]:
            raise CatalogError(f"addons.yml line {number}: {key} given twice")
        entries[-1][key] = value
    for entry in entries:
        for key in KEYS:
            entry.setdefault(key, "")
    return entries


def roles(entry):
    return [r.strip() for r in entry["demo_roles"].split(",") if r.strip()]


def has_image(entry):
    return bool(entry["packages"])


def image(entry):
    return f"ghcr.io/{IMAGE_OWNER}/plone-in-a-box-frontend:{entry['volto']}-{entry['id']}"


def ready_made(entry):
    """Images someone else publishes, such as a Plone distribution's."""
    return bool(entry["frontend_image"] or entry["backend_image"])


def settings(entry):
    """What the server needs, in order: (launcher variable, Launch Stack parameter, Linode field, value)."""
    out = []
    if has_image(entry):
        return [("FRONTEND_IMAGE", "FrontendImage", "Frontend image", image(entry))]
    if entry["frontend_image"]:
        out.append(("FRONTEND_IMAGE", "FrontendImage", "Frontend image", entry["frontend_image"]))
    if entry["backend_image"]:
        out.append(("BACKEND_IMAGE", "BackendImage", "Backend image", entry["backend_image"]))
    if entry["backend_addons"]:
        out.append(("ADDONS", "Addons", "Backend add-ons", entry["backend_addons"]))
    if roles(entry):
        out.append(("DEMO_ROLES", "DemoRoles", "Roles of the demo login", ", ".join(roles(entry))))
    return out


def problems(entries):
    """What's wrong with the entries, as messages."""
    found, seen = [], set()
    for entry in entries:
        i = entry["id"]
        say = lambda msg: found.append(f"{i or '?'}: {msg}")  # noqa: E731
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]{1,39}", i):
            say("id: lowercase letters, digits and hyphens, 2 to 40 characters")
        if i in seen:
            say("id is used twice")
        seen.add(i)
        for key in ("name", "description"):
            if not entry[key]:
                say(f"{key} is missing")
            elif re.search(r"[<>\"`]", entry[key]):
                say(f"{key}: no < > \" or `")
        if not re.fullmatch(r"https://[A-Za-z0-9./_~%+-]+", entry["url"]):
            say("url: an https:// address")
        if has_image(entry):
            if entry["volto"] not in ("18", "19"):
                say("volto: 18 or 19")
            for pkg in entry["packages"].split():
                if not re.fullmatch(r"(@[a-z0-9._-]+/)?[a-z0-9._-]+@\d+\.\d+\.\d+[0-9A-Za-z.+-]*", pkg):
                    say(f"packages: {pkg} isn't name@exact.version")
            if not entry["addons"]:
                say("addons: the Volto add-ons to load")
            if ready_made(entry):
                say("frontend_image and backend_image are for images made elsewhere, without packages")
        elif any(entry[k] for k in ("volto", "addons", "theme", "site_behaviors")):
            say("volto, addons, theme and site_behaviors need packages")
        for key in ("frontend_image", "backend_image"):
            if entry[key] and not re.fullmatch(r"[a-z0-9.-]+(:[0-9]+)?(/[a-z0-9._-]+)+:[A-Za-z0-9._-]+", entry[key]):
                say(f"{key}: an image name with its registry and a tag, such as ghcr.io/owner/name:1.2")
        for pkg in entry["backend_addons"].split():
            if not re.fullmatch(r"[A-Za-z0-9._-]+(\[[A-Za-z0-9,._-]+\])?==[0-9][0-9A-Za-z.+!-]*", pkg):
                say(f"backend_addons: {pkg} isn't name==exact.version")
        for key in ("addons", "theme", "site_behaviors"):
            if not re.fullmatch(r"[A-Za-z0-9@/ ._-]*", entry[key]):
                say(f"{key}: names separated by spaces")
        for role in roles(entry):
            if role in NOT_FOR_DEMO:
                say(f"demo_roles: {role} isn't allowed")
            elif not re.fullmatch(r"[A-Za-z0-9 ._-]+", role):
                say(f"demo_roles: {role} isn't a role name")
        if entry["arm"] not in ("", "yes", "no"):
            say("arm: yes or no")
        elif entry["arm"] == "yes" and not ready_made(entry):
            say("arm is for ready-made images (frontend_image, backend_image)")
        if entry["try_it"] not in ("", "yes", "no"):
            say("try_it: yes or no")
        if entry["try_it"] == "yes":
            if not (has_image(entry) or ready_made(entry) or entry["backend_addons"]):
                say("try_it needs packages, backend_addons, frontend_image or backend_image")
            if not entry["try_hint"]:
                say("try_hint: what to do after logging in as demo")
            elif re.search(r"[<>`]", entry["try_hint"]):
                say("try_hint: no < > or `")
        if entry["linode_stackscript"] and not entry["linode_stackscript"].isdigit():
            say("linode_stackscript: a number")
    return found


def matrix(entries):
    include = []
    for e in entries:
        if has_image(e):
            include.append({
                "variant": e["id"], "volto": e["volto"], "description": e["description"],
                "packages": e["packages"], "addons": e["addons"], "theme": e["theme"],
                "backend_addons": e["backend_addons"], "site_behaviors": e["site_behaviors"],
                "demo_roles": ", ".join(roles(e)),
            })
    return {"include": include}


def release():
    text = open(os.path.join(ROOT, "src", "user-data.sh"), encoding="utf-8").read()
    m = re.search(r"^PIAB_RELEASE='([^']+)'$", text, re.M)
    if not m:
        raise CatalogError("no PIAB_RELEASE in src/user-data.sh")
    return m.group(1)


# --- The ready-made images ---------------------------------------------------------

MANIFESTS = ", ".join([
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
    "application/vnd.oci.image.manifest.v1+json",
    "application/vnd.docker.distribution.manifest.v2+json",
])
# What setup expects of an image, from the official ones.
EXPECTED = {
    "backend_image": {"port": "8080/tcp", "entrypoint": ["/app/docker-entrypoint.sh"]},
    "frontend_image": {"port": "3000/tcp", "entrypoint": None},
}


class Registry:
    """Reads manifests and image configs from a registry, without logging in."""

    def __init__(self, ref):
        name, self.tag = ref.rsplit(":", 1)
        first, _, rest = name.partition("/")
        if "." in first or ":" in first:
            self.host, self.repo = first, rest
        else:  # Docker Hub
            self.host, self.repo = "registry-1.docker.io", name if "/" in name else f"library/{name}"
        self.token = None

    def get(self, path, accept=MANIFESTS):
        url = f"https://{self.host}/v2/{self.repo}/{path}"
        for attempt in range(3):
            headers = {"Accept": accept, "User-Agent": "plone-in-a-box-catalog"}
            if self.token:
                headers["Authorization"] = f"Bearer {self.token}"
            try:
                with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as r:
                    return json.loads(r.read())
            except urllib.error.HTTPError as e:
                if e.code == 401 and not self.token:
                    # An anonymous token, as docker pull gets one.
                    challenge = dict(re.findall(r'(\w+)="([^"]*)"', e.headers.get("WWW-Authenticate", "")))
                    if "realm" not in challenge:
                        raise
                    token_url = (f"{challenge['realm']}?service={quote(challenge.get('service', ''))}"
                                 f"&scope=repository:{self.repo}:pull")
                    with urllib.request.urlopen(token_url, timeout=30) as r:
                        answer = json.loads(r.read())
                    self.token = answer.get("token") or answer.get("access_token")
                    continue
                if e.code >= 500 and attempt < 2:
                    time.sleep(5)
                    continue
                raise
            except urllib.error.URLError:
                if attempt < 2:
                    time.sleep(5)
                    continue
                raise
        raise urllib.error.URLError(f"no answer from {self.host}")

    def platforms(self):
        """{"linux/amd64": the image's config, ...}."""
        manifest = self.get(f"manifests/{self.tag}")
        if "manifests" in manifest:
            found = {}
            for m in manifest["manifests"]:
                p = m.get("platform") or {}
                if p.get("os") == "linux":
                    found[f"linux/{p['architecture']}"] = m["digest"]
            return {p: self.config(self.get(f"manifests/{d}")) for p, d in found.items()}
        config = self.config(manifest)
        return {f"{config.get('os', 'linux')}/{config.get('architecture', '?')}": config}

    def config(self, manifest):
        return self.get(f"blobs/{manifest['config']['digest']}", accept="*/*")


def image_problems(entries, registry=Registry):
    """(problems, warnings) with the ready-made images, as messages."""
    found, warned = [], []
    for entry in entries:
        wanted = ["linux/amd64"] + (["linux/arm64"] if entry["arm"] == "yes" else [])
        all_arm = True
        for key in ("frontend_image", "backend_image"):
            ref = entry[key]
            if not ref:
                continue
            say = lambda msg: found.append(f"{entry['id']}: {key} {ref}: {msg}")  # noqa: E731
            warn = lambda msg: warned.append(f"{entry['id']}: {key} {ref}: {msg}")  # noqa: E731
            try:
                platforms = registry(ref).platforms()
            except urllib.error.HTTPError as e:
                if e.code in (401, 403, 404):
                    say("can't be pulled without logging in: it must be public, and the tag must exist")
                else:
                    say(f"the registry answered {e.code}")
                continue
            except (urllib.error.URLError, OSError, ValueError, KeyError) as e:
                say(f"couldn't read it ({e})")
                continue
            missing = [p for p in wanted if p not in platforms]
            if missing:
                say(f"isn't built for {', '.join(missing)} (it has {', '.join(sorted(platforms)) or 'none'})")
            all_arm = all_arm and "linux/arm64" in platforms
            config = (platforms.get("linux/amd64") or {}).get("config") or {}
            expect = EXPECTED[key]
            if expect["port"] not in (config.get("ExposedPorts") or {}):
                warn(f"doesn't expose {expect['port']}, as the official image does")
            if expect["entrypoint"] and config.get("Entrypoint") != expect["entrypoint"]:
                warn(f"starts with {config.get('Entrypoint')}, not {expect['entrypoint']} as the official one does")
        if ready_made(entry) and entry["arm"] != "yes" and all_arm and not any(m.startswith(f"{entry['id']}: ") for m in found):
            warned.append(f"{entry['id']}: its images are built for linux/arm64 too: add arm: yes")
    return found, warned


# --- The pages --------------------------------------------------------------------

STYLE = """
:root {
  --bg: #ffffff; --fg: #1d2329; --muted: #5a6570; --line: #d9dee3; --panel: #f4f6f8;
  --link: #0068a8; --accent: #0083be; --code: #eef1f4;
  color-scheme: light;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #14181c; --fg: #e6eaee; --muted: #a3adb7; --line: #2e363e; --panel: #1c2228;
    --link: #6cc4f0; --accent: #3aa9dc; --code: #222a31;
    color-scheme: dark;
  }
}
:root[data-theme="dark"] {
  --bg: #14181c; --fg: #e6eaee; --muted: #a3adb7; --line: #2e363e; --panel: #1c2228;
  --link: #6cc4f0; --accent: #3aa9dc; --code: #222a31;
  color-scheme: dark;
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--fg);
  font: 16px/1.55 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
main { max-width: 46rem; margin: 0 auto; padding: 2rem 16px 4rem; }
h1 { font-size: 1.9rem; line-height: 1.2; margin: 0 0 .5rem; }
h2 { font-size: 1.25rem; margin: 2.2rem 0 .6rem; padding-top: 1rem; border-top: 1px solid var(--line); }
a { color: var(--link); }
p, ol, ul { margin: .6rem 0; }
li { margin: .3rem 0; }
.lead { font-size: 1.1rem; color: var(--muted); }
.buttons { display: flex; flex-wrap: wrap; gap: .75rem; margin: 1.4rem 0; }
.button { display: inline-block; padding: .65rem 1.1rem; border-radius: 6px; background: var(--accent);
  color: #fff; font-weight: 600; text-decoration: none; }
.button:hover { filter: brightness(1.1); }
.steps { background: var(--panel); border: 1px solid var(--line); border-radius: 8px; padding: .6rem 1.2rem .6rem 2.4rem; }
code, pre { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: .9em; }
code { background: var(--code); padding: .1em .35em; border-radius: 4px; overflow-wrap: anywhere; }
pre { background: var(--code); padding: .8rem 5rem .8rem 1rem; border-radius: 6px; overflow-x: auto; margin: 0; }
pre code { background: none; padding: 0; overflow-wrap: normal; }
.copy { position: relative; margin: .6rem 0; }
.copy button { position: absolute; top: .4rem; right: .4rem; font: inherit; font-size: .8rem; padding: .2rem .6rem;
  border: 1px solid var(--line); border-radius: 4px; background: var(--bg); color: var(--fg); cursor: pointer; }
table { border-collapse: collapse; width: 100%; margin: .6rem 0; }
th, td { text-align: left; vertical-align: top; padding: .45rem .5rem; border-bottom: 1px solid var(--line); }
th { font-weight: 600; width: 40%; }
.note { color: var(--muted); font-size: .95rem; }
footer { margin-top: 3rem; color: var(--muted); font-size: .9rem; }
"""

SCRIPT = """
document.querySelectorAll('.copy').forEach(function (box) {
  var button = document.createElement('button');
  button.type = 'button';
  button.textContent = 'Copy';
  button.addEventListener('click', function () {
    var text = box.querySelector('code').textContent;
    var done = function () { button.textContent = 'Copied'; setTimeout(function () { button.textContent = 'Copy'; }, 1500); };
    if (navigator.clipboard) { navigator.clipboard.writeText(text).then(done, function () {}); }
  });
  box.appendChild(button);
});
"""

GENERATED = "<!-- Written by scripts/catalog.py from addons.yml; don't edit by hand. -->"


def new_tab(text):
    """Make links that leave the page (http and https) open in a new tab, so
    people following the steps keep their place; links within the site stay."""
    return re.sub(r'<a ([^>]*?)href="(https?://[^"]*)"', r'<a \1href="\2" target="_blank" rel="noopener"', text)


def page(title, description, body):
    return new_tab(f"""<!doctype html>
{GENERATED}
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<meta name="description" content="{html.escape(description)}">
<style>{STYLE}</style>
</head>
<body>
<main>
{body}
<footer>Set up by <a href="{REPO}">Plone in a Box</a>, which installs Plone 6 on a cloud server of your own.
Questions? Ask in <a href="{DISCORD_CHANNEL}" style="white-space: nowrap"><strong>#plone-in-a-box</strong></a> on <a href="{DISCORD}">the Plone Discord</a>.
Plone and the Plone logo are trademarks of the Plone Foundation.</footer>
</main>
<script>{SCRIPT}</script>
</body>
</html>
""")


def copyable(text):
    return f'<div class="copy"><pre><code>{html.escape(text)}</code></pre></div>'


def aws_link(entry):
    params = {"DemoUser": "demo"}
    params.update((param, value) for _var, param, _field, value in settings(entry))
    query = "".join(f"&param_{k}={quote(v, safe='')}" for k, v in params.items())
    return ("https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review"
            f"?templateURL={quote(TEMPLATE_URL, safe='')}&stackName={entry['id']}-demo{query}")


def try_page(entry, version):
    e = {k: html.escape(v) for k, v in entry.items()}
    name = e["name"]
    role_text = ", ".join(roles(entry)) or "Site Administrator"
    linode_ss = entry["linode_stackscript"] or LINODE_STACKSCRIPT
    linode_url = f"https://cloud.linode.com/stackscripts/{linode_ss}"

    fields = [("Plone admin password", "a password of at least 12 characters, for you")]
    if not entry["linode_stackscript"]:
        fields.append(("Demo login", "<code>demo</code>"))
        fields += [(field, f"<code>{html.escape(value)}</code>") for _var, _param, field, value in settings(entry)]
    fields.append(("Demo login password", "at least 12 characters, for the people you let try it"))
    rows = "\n".join(f"<tr><th>{k}</th><td>{v}</td></tr>" for k, v in fields)
    if entry["linode_stackscript"]:
        linode_steps = f"""<p>The <a href="{linode_url}">{name} StackScript</a> has {name} and the demo login filled in.</p>
<ol>
<li>Log in to <a href="https://cloud.linode.com">Cloud Manager</a>, open the <a href="{linode_url}">StackScript</a>,
and click <strong>Deploy New Linode</strong>.</li>
<li>Fill in the passwords:
<table>{rows}</table></li>
<li>Choose <strong>Ubuntu 26.04 LTS</strong>, a region, a 1 GB <strong>Nanode</strong> and <strong>No firewall</strong>,
set a root password, and click <strong>Create Linode</strong>.</li>
</ol>"""
    else:
        linode_steps = f"""<p>Linode can't fill in the form from a link, so you paste a few values into it.</p>
<ol>
<li>Log in to <a href="https://cloud.linode.com">Cloud Manager</a>, open the
<a href="{linode_url}">Plone in a Box StackScript</a>, and click <strong>Deploy New Linode</strong>.</li>
<li>Fill in these fields, and leave the others as they are:
<table>{rows}</table></li>
<li>Choose <strong>Ubuntu 26.04 LTS</strong>, a region, a 1 GB <strong>Nanode</strong> and <strong>No firewall</strong>,
set a root password, and click <strong>Create Linode</strong>.</li>
</ol>"""

    lines = ["#!/bin/bash", "export ADMIN_PASSWORD='CHANGE-ME'"]
    lines += [f"export {var}='{value}'" for var, _param, _field, value in settings(entry)]
    lines += ["export DEMO_USER='demo'", "export DEMO_PASSWORD='CHANGE-ME-TOO'",
              "curl -fsSL --retry 10 --retry-all-errors -o /root/plone-in-a-box.sh "
              f"https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/{version}/src/StackScript"
              " && bash /root/plone-in-a-box.sh"]

    arm_note = ("" if not ready_made(entry) or entry["arm"] == "yes" else f"""
<p class="note">On Hetzner, choose an <strong>x86</strong> server type (Intel or AMD), not Arm: {name}'s images
are made for x86.</p>""")

    page_url = f"{SITE}/try/{entry['id']}/"
    badge = (f"[![Try It in Plone in a Box](https://img.shields.io/badge/Try%20It-Plone%20in%20a%20Box-0083be)]"
             f"({page_url})")

    # The description, unless it only repeats the name.
    about = "" if entry["description"].lower() == entry["name"].lower() else f", {e['description']},"
    role_word = "role" if len(roles(entry)) <= 1 else "roles"
    body = f"""<h1>Try {name}</h1>
<p class="lead">Your own Plone 6 site with <a href="{e['url']}">{name}</a>{about} in about
10 minutes.</p>
<p>It runs on a cloud server in your own account, set up by Plone in a Box. A small server costs a few cents an
hour, paid to the cloud provider; delete it when you're done, which deletes the site too.</p>

<div class="buttons">
<a class="button" href="{html.escape(aws_link(entry))}">Launch on AWS</a>
<a class="button" href="#linode">Deploy on Linode</a>
<a class="button" href="#digitalocean-and-hetzner">DigitalOcean or Hetzner</a>
</div>

<ol class="steps">
<li>Choose a provider below and create the server. You fill in two passwords: one for <code>admin</code>, and one
for the <code>demo</code> login you'll share.</li>
<li>Open the server's address in a browser. Setup takes about 10 minutes, and the page shows how far it got.</li>
<li>Log in as <code>demo</code> with the demo password, then {e['try_hint']}.</li>
</ol>

<p>The <code>demo</code> login has the {role_word} <strong>{html.escape(role_text)}</strong>: it can do what {"that role allows" if role_word == "role" else "those roles allow"}
on the site, and nothing more. Share it with whoever you want to try {name}.</p>
<p class="note">The site has no domain name, so it gets an HTTPS certificate for the server's IP address and is at
<code>https://</code> followed by that address; if it opens on <code>http://</code> during setup, it moves to
<code>https://</code> when it's ready.</p>

<h2 id="aws">Amazon AWS</h2>
<ol>
<li>Sign in to the <a href="https://console.aws.amazon.com/">AWS console</a>, then click
<a href="{html.escape(aws_link(entry))}">Launch on AWS</a>: a form with {name} and the demo login filled in.</li>
<li>Fill in <strong>AdminPassword</strong> and <strong>DemoPassword</strong> (at least 12 characters each), and click
<strong>Create stack</strong>.</li>
<li>When the stack says <strong>CREATE_COMPLETE</strong>, open the <strong>SiteURL</strong> on its
<strong>Outputs</strong> tab.</li>
</ol>
<p class="note">The default <code>t3.small</code> server costs more than the other providers' 1 GB ones. To delete it,
delete the stack.</p>

<h2 id="linode">Linode (Akamai)</h2>
{linode_steps}
<p class="note">Then open the Linode's IP address in a browser. To delete it: <strong>⋯ → Delete</strong>.</p>

<h2 id="digitalocean-and-hetzner">DigitalOcean and Hetzner</h2>
<p>Create an Ubuntu 26.04 server with 1 GB of memory or more, and paste these lines into <strong>Additional Options →
Startup scripts</strong> (DigitalOcean) or <strong>Cloud config</strong> (Hetzner). Replace
<code>CHANGE-ME</code> with an admin password and <code>CHANGE-ME-TOO</code> with a demo password, each at least 12
characters:</p>
{copyable(chr(10).join(lines))}{arm_note}
<p class="note">Then open the server's IP address in a browser. More detail:
<a href="{REPO}/blob/main/docs/setup-guide.md#option-c-digitalocean">DigitalOcean</a>,
<a href="{REPO}/blob/main/docs/setup-guide.md#option-d-hetzner">Hetzner</a>.</p>

<h2 id="password">Forgot the demo password?</h2>
<p>Log in as <code>admin</code>, open <strong>Site Setup → Users</strong>, click <code>demo</code> and set a new one.
If you left it empty, setup made one up: open your provider's browser console (Linode's <strong>Launch LISH
Console</strong>, DigitalOcean's <strong>Access → Launch Droplet Console</strong>, AWS's <strong>Connect → EC2 Instance
Connect</strong>, Hetzner's <strong>&gt;_ Console</strong>) and run:</p>
{copyable("sudo cat /root/plone-credentials.txt")}

<h2 id="button">For {name}'s README</h2>
<p>A button that links here:</p>
{copyable(badge)}
"""
    return page(f"Try {entry['name']}",
                f"Your own Plone 6 site with {entry['name']} in about 10 minutes, on your own cloud server.", body)


def index_page(entries):
    items = "\n".join(
        f'<li><a href="{html.escape(e["id"])}/">{html.escape(e["name"])}</a>: {html.escape(e["description"])}</li>'
        for e in entries if e["try_it"] == "yes")
    body = f"""<h1>Try a Plone add-on</h1>
<p class="lead">Your own Plone 6 site with one of these add-ons, and a demo login to share, in about 10 minutes, on
a cloud server of your own.</p>
<ul>
{items}
</ul>
<p>Add-on authors: add yours with a pull request; see
<a href="{REPO}/blob/main/docs/try-it-buttons.md">Try It buttons</a>.</p>
"""
    return page("Try a Plone add-on", "Try Plone add-ons on a Plone 6 site of your own, set up by Plone in a Box.", body)


def pages(entries):
    """{relative path: content} for everything in docs/try/."""
    version = release()
    out = {"index.html": index_page(entries)}
    for entry in entries:
        if entry["try_it"] == "yes":
            out[f"{entry['id']}/index.html"] = try_page(entry, version)
    return out


def existing_pages():
    found = {}
    for folder, _dirs, files in os.walk(PAGES):
        for f in files:
            path = os.path.join(folder, f)
            found[os.path.relpath(path, PAGES)] = open(path, encoding="utf-8").read()
    return found


def main(argv):
    command = argv[1] if len(argv) > 1 else ""
    try:
        entries = read()
        if command == "matrix":
            print(json.dumps(matrix(entries)))
            return 0
        found = problems(entries)
        if found:
            print("addons.yml:\n  " + "\n  ".join(found), file=sys.stderr)
            return 1
        if command == "images":
            found, warned = image_problems(entries)
            for message in warned:
                print(f"::warning::{message}" if os.environ.get("GITHUB_ACTIONS") else f"warning: {message}")
            if found:
                print("Ready-made images in addons.yml:\n  " + "\n  ".join(found), file=sys.stderr)
                return 1
            print(f"Ready-made images: {sum(bool(e[k]) for e in entries for k in EXPECTED)} checked")
            return 0
        wanted = pages(entries)
        if command == "pages":
            have = existing_pages()
            for rel in have:
                if rel not in wanted:
                    os.remove(os.path.join(PAGES, rel))
            for rel, text in wanted.items():
                path = os.path.join(PAGES, rel)
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, "w", encoding="utf-8") as f:
                    f.write(text)
            print(f"Wrote {len(wanted)} pages in docs/try/")
            return 0
        if command == "check":
            have = existing_pages()
            stale = sorted(set(wanted) ^ set(have) | {r for r in wanted if have.get(r) != wanted[r]})
            if stale:
                print("docs/try/ isn't up to date with addons.yml and the release: run "
                      "python3 scripts/catalog.py pages, and commit. Different: " + ", ".join(stale), file=sys.stderr)
                return 1
            print(f"addons.yml: {len(entries)} entries, docs/try/ up to date")
            return 0
    except CatalogError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
