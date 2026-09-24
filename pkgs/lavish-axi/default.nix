{ lib, buildNpmPackage, fetchurl }:

# lavish-axi, packaged from the pinned npm tarball (plan decision: version
# pinned, updates are deliberate bumps). The tarball ships a prebuilt dist/
# but neither a lockfile nor its build scripts, so:
#   - package.json and package-lock.json here are vendored: the tarball's
#     package.json with devDependencies removed (dist/ is prebuilt; the dev
#     tree - esbuild, mermaid, excalidraw - is dead weight) and the lock
#     `npm install --package-lock-only --ignore-scripts` generates from it.
#     Plain copies, no tooling in postPatch: the npm-deps fetcher runs
#     postPatch too but without this derivation's build inputs. To bump the
#     version: update `version` and refetch the tarball hash. In a scratch
#     directory, place the new tarball's package.json with devDependencies
#     removed alongside a copy of the current vendored package-lock.json.
#     There, run `npm install --package-lock-only --ignore-scripts` to retain
#     compatible resolutions, then copy both generated files back here.
#     Reset npmDepsHash and build to discover and verify the new hash.
#   - the build script is skipped (dontNpmBuild) and lifecycle scripts are
#     ignored: prepare/prepack call scripts/ that the tarball does not
#     contain, and every runtime dep is pure JS with nothing to compile.
# The node runtime rides in the closure: the CLI's `#!/usr/bin/env node`
# shebang is patched to the store's node by the standard build hooks.
buildNpmPackage rec {
  pname = "lavish-axi";
  version = "0.1.78";

  src = fetchurl {
    url = "https://registry.npmjs.org/lavish-axi/-/lavish-axi-${version}.tgz";
    hash = "sha256-DBDZNSpjqMi2vpCNHCnKsvG2hXWRDPMuXLbYF4umK4I=";
  };

  # Align the unpacked package.json with the dev-stripped vendored lock,
  # or npm ci refuses the pair as out of sync.
  postPatch = ''
    cp ${./package.json} package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-mtiAIniE6Uh3ZhqvgKCXK70FCDuptBeL4PaXQ06rRe8=";

  dontNpmBuild = true;
  npmFlags = [ "--ignore-scripts" ];

  meta = {
    description = "Local-first CLI and browser editor for HTML artifacts";
    homepage = "https://github.com/kunchenguid/lavish-axi";
    license = lib.licenses.mit;
    mainProgram = "lavish-axi";
  };
}
