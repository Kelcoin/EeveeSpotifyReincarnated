# Configurable Action IPA Identity

## Goal

Allow users who manually run an IPA GitHub Actions workflow to choose the
installed app name and bundle identifier. The defaults must be
`EeveeSpotify` and `in.kelco.spotify.client`.

## Scope

Update only these GitHub Actions workflows:

- `.github/workflows/build-and-release-yourself.yml`
- `.github/workflows/buildnopatch.yml`
- `.github/workflows/buildpatched.yml`

Do not change `build-ipa-local.sh`, package metadata, or the generated IPA
filename.

## Design

Each workflow will expose two required `workflow_dispatch` string inputs:

- `app_name`, defaulting to `EeveeSpotify`
- `bundle_id`, defaulting to `in.kelco.spotify.client`

The inputs will be assigned to workflow environment variables rather than
interpolated directly into a shell script. This prevents user-provided text
from becoming shell syntax. Each `cyan` invocation will pass the quoted
environment variables through `-n "$APP_NAME"` and `-b "$BUNDLE_ID"`.

`cyan` owns the identity rewrite. Its name option updates `CFBundleName`,
`CFBundleDisplayName`, and localized display-name entries. Its bundle option
updates the main bundle identifier and identifiers derived from it in app
extensions.

## Validation

Repository checks will assert that all three workflows:

- define both inputs with the required defaults;
- map the inputs to `APP_NAME` and `BUNDLE_ID`;
- pass both quoted variables to `cyan`;
- contain no direct input interpolation inside the shell command.

The workflow YAML will also receive available syntax checks. A full IPA build
is not available on Windows because the pipeline requires macOS and Xcode.
