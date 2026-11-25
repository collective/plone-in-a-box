"""Hold the given packages at their installed versions in /app/constraints.txt.

Setup installs Backend add-ons against /app/constraints.txt, so without this,
installing an add-on would put the older versions of these packages back.

Usage: python hold-versions.py "plone.volto>=6.2.1,<7" ...
"""
import re
import sys
from importlib.metadata import version

PATH = "/app/constraints.txt"


def key(requirement):
    """The normalized package name of a requirement or constraint line."""
    return re.sub(r"[-_.]+", "-", re.split(r"[<>=!~\[;\s]", requirement.strip())[0]).lower()


lines = open(PATH).read().splitlines()
for requirement in " ".join(sys.argv[1:]).split():
    name = re.split(r"[<>=!~\[;]", requirement)[0]
    lines = [line for line in lines if key(line) != key(name)]
    lines.append(f"{name}=={version(name)}")
    print(lines[-1])
open(PATH, "w").write("\n".join(lines) + "\n")
