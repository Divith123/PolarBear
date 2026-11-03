# Security policy

## Reporting a vulnerability

Please **do not** open a public issue for a security problem. Use GitHub's private vulnerability reporting
(*Security → Report a vulnerability* on the repository page), and include:

* what you found and where (file, setting, or workflow),
* how to reproduce it, and
* what you think the impact is.

You will get a first answer within a week. Please give us a reasonable time to fix the problem before you share it.

## Supported versions

PolarBear is young: only the latest commit on `main` and the latest release receive fixes.

## What is in scope

PolarBear opens documents, archives and agent output from places you may not fully trust, so these are the areas
we care most about:

* **Importing archives** (`.zip`, `.tar.gz`): path traversal or links that write outside the project.
* **Compiling untrusted LaTeX**: shell escape is off by default; anything that runs a program or reads outside the
  project without the user turning it on is a bug.
* **Rendering untrusted Markdown**: scripts, or network requests made by the page. (The renderer runs with scripts
  disabled; web images are fetched separately over `https`, without cookies, and can be turned off.)
* **AI agents**: an agent writing to the real project without the user keeping a change, or secrets
  (`.env`, keys, tokens) being copied into the agent's working copy.
* **Launching programs**: any place where document text can reach a shell or change which program is run.

## Things you should know

* PolarBear runs **without the App Sandbox** (the hardened runtime is on), because a sandboxed app cannot start
  your TeX or agent command-line tools. Treat the app as having the same access to your files as other programs you run.
* The app sends no analytics. Its only network requests of its own are: the optional download of `https` images used
  by a Markdown document, and the **install buttons** for Tectonic and OpenCode, which run only when you click them.
  An install asks the GitHub API for the program's newest release, downloads the file from GitHub, and installs it only
  if its SHA-256 matches the digest GitHub published for it (a mismatch deletes the file). Cookies are never sent. The
  program goes to `~/Library/Application Support/PolarBear/Tools` and nothing else on the Mac is changed. Anything your
  TeX engine (for example Tectonic fetching packages on its first compile) or your chosen AI agent does is that
  program's own traffic.
* Releases are signed with a development certificate and are **not notarised**, so a browser-downloaded copy triggers
  the "unidentified developer" prompt. `Scripts/get-polarbear.sh` installs a release from Terminal after checking its
  SHA-256; read it before you pipe it into a shell.
