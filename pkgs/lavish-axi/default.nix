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
#     version: update `version`, refetch the tarball hash, regenerate both
#     vendored files from the new tarball the same way, reset npmDepsHash.
#   - the build script is skipped (dontNpmBuild) and lifecycle scripts are
#     ignored: prepare/prepack call scripts/ that the tarball does not
#     contain, and every runtime dep is pure JS with nothing to compile.
# The node runtime rides in the closure: the CLI's `#!/usr/bin/env node`
# shebang is patched to the store's node by the standard build hooks.
buildNpmPackage rec {
  pname = "lavish-axi";
  version = "0.1.73";

  src = fetchurl {
    url = "https://registry.npmjs.org/lavish-axi/-/lavish-axi-${version}.tgz";
    hash = "sha256-YswQVVO7ZFGtTz01kQqHde3PC3VtyKqSZm5wCDZyIz8=";
  };

  # Align the unpacked package.json with the dev-stripped vendored lock,
  # or npm ci refuses the pair as out of sync.
  postPatch = ''
    cp ${./package.json} package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-gosoP5ypRev0fAyG5/hQhi72ayro1LuxExpkwv4zLPc=";

  dontNpmBuild = true;
  npmFlags = [ "--ignore-scripts" ];

  meta = {
    description = "Local-first CLI and browser editor for HTML artifacts";
    homepage = "https://github.com/kunchenguid/lavish-axi";
    license = lib.licenses.mit;
    mainProgram = "lavish-axi";
  };
}
