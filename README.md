# xy-image

Available as `quay.io/xyl/image:v1.0.0`. Built by the quay.io service automatically from commits to main (as `:latest`) and tags (e.g. `v1.2.1`). It's a free service so builds can take up to 5 minutes. Changes to dependencies of `package.json` need a local run of `npm i` so the `package-lock.json` file is updated.

## Deploy an update

1. Make changes to dependencies and Dockerfiles as required.
2. Run `npm i` if dependencies have changed to update `package-lock.json`
3. Commit changes
4. Run `npm version minor` to bump the version. Use major, minor or patch depending on change.
5. Push commit and changes.
6. Manually push the new git tag with `git push origin v1.2.3`
