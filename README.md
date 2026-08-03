# xy-image

The base Docker image every backend service runs on: the Node runtime, `tini`, and
the production `node_modules` installed from this repo's `package.json`.

It deliberately does **not** contain application code. Each service's source is
bind-mounted at run time with `node_modules` shadowed, so **every service's
dependencies resolve to this image**. That is why a dependency change here forces a
rebuild — and why most application releases do not need one.

Tagged `quay.io/xyl/image:vX.Y.Z`, matching this repo's `package.json` version.

> **The image is built locally.** It was once built automatically by quay.io from
> commits and tags; that service is no longer used. **Pushing a git tag does not
> build anything.**

## When to rebuild

- **a runtime dependency changed** — you edited `package.json`, so
  `package-lock.json` must be regenerated
- **the base image or build changed** — `node:22-alpine`, `tini`, or the
  `Dockerfile`

A pure application-code change in `xy` or `dhl-te-kapua` does **not** need a
rebuild — the code is mounted, not baked in.

## Rebuild and release

Branch from **`main-automatex`** (not `main`) using the release branch name for the
target environment — `dhl-uat-release-X.Y.Z` or `dhl-live-release-X.Y.Z`.

**1. Make the change** to `package.json` and/or the `Dockerfile`.

**2. Refresh the lockfile** if dependencies changed:

```sh
npm i
```

**3. Bump the version** — this creates a commit and a local tag:

```sh
npm version minor        # major | minor | patch, to suit the change
```

**4. Build, save and package.** Use the version you just bumped to:

```sh
docker buildx build --platform=linux/amd64 -t quay.io/xyl/image:v1.2.4 .
docker save -o xyl_image_v1_2_4.docker quay.io/xyl/image:v1.2.4
tar czf xyl_image_v1_2_4.docker.tar.gz xyl_image_v1_2_4.docker
```

**5. Commit the packaged tarball.** `xyl_image_*.docker.tar.gz` is **tracked
deliberately** — it is the artefact the deployment rsyncs to the host. (`.gitignore`
covers the intermediate `*.docker`, which is not tracked.) Each tarball is roughly
80 MB, so it is worth being deliberate about how often you commit one.

**6. Push the branch**, and the tag if you want it as a version marker:

```sh
git push
git push origin v1.2.4     # a marker only — this does not trigger a build
```

**7. Update the image references in `dhl-te-kapua-deployment`.** ⚠️ **This step is
mandatory and is outside this repo.** The version tag appears in both the compose
files and the derived-image Dockerfiles:

```sh
cd ../dhl-te-kapua-deployment
grep -rnE 'quay\.io/xyl/image(/arm)?:v' docker-*/compose.yaml docker-*/xyl-image/Dockerfile
```

That reports 32 references at present, 8 per environment:

| Environment | In `compose.yaml` | In `xyl-image/Dockerfile` |
|---|---|---|
| `uat`, `live1`, `live2` | 7 | 1 — the `svt` derived image |
| `local` | 8 | none |

Update every occurrence for the environment you are deploying, then commit and push
that repo on the same release branch.

`docker-local/` is the odd one out twice over. It pins the **`/arm`** variant
(`quay.io/xyl/image/arm:vX.Y.Z`) for Apple silicon, and it runs `svt` straight off
the base image with no derived image — which is why it has 8 compose references and
no `Dockerfile`. It is never deployed, so bumping it is optional; leave it behind and
local dev quietly resolves dependencies against the old image. The `(/arm)?` in the
pattern above is what makes those 8 visible at all — a plain search for `image:v`
silently skips every one of them.

**8. Deploy.** Run the deploy script for the target environment and answer `y` to
**both** `xy-image` **and** `dhl-te-kapua-deployment`, then run the `docker load`
step on the server. Full procedure:
`dhl-te-kapua-deployment/DEPLOYMENT-FEATURES.md`.

## Why steps 7 and 8 matter

Deploying `xy-image` alone copies the tarball to `~/xy-image/` on the host and
nothing else. The version reference that compose actually uses lives in
`dhl-te-kapua-deployment`.

**So if you skip step 7, you will load the new image onto the host and carry on
running the old one.** Nothing errors — it simply has no effect.

The deployment repo also runs a dependency-coverage gate before every deploy
(`scripts/check-image-dependencies.mjs`). It **aborts the deployment** if the
version referenced by the compose files disagrees with this repo's
`package.json`, or if a service declares a dependency this image does not carry.
That gate is what catches a half-finished bump.

## Contents

| File | Purpose |
|---|---|
| `Dockerfile` | `node:22-alpine` + `tini`, `npm ci --omit=dev`, entrypoint via `tini` |
| `package.json` | the dependency set baked into the image; its `version` is the image tag |
| `package-lock.json` | must be regenerated with `npm i` whenever `package.json` changes |
| `index.js` | a keep-alive loop, so a container started with no override does not exit |
