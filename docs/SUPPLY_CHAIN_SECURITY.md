# Supply-chain security

iMacSwitch has no third-party runtime or package-manager dependencies. The
release surface consists of Xcode, the macOS SDK, and pinned GitHub Actions.

- Action references use immutable commit SHAs.
- Local and CI builds share `make ci` and the same Xcode project.
- Release artifacts are Developer ID signed, notarized, stapled, and checked
  with `codesign`, `stapler`, and Gatekeeper before publication.
- Signing and notarization keys are repository secrets and are decoded only in
  the hosted runner's temporary directory.
- Generated `.app`, `.dmg`, archives, keys, and keychains are ignored by Git.

Possible future hardening includes build provenance attestations and an SBOM
describing the SDK/toolchain inputs. Those should be added only with a concrete
consumer and verification path.
