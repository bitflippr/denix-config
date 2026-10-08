# Personal T3 Code release channel

Builder checks upstream T3 Code `main` and the pull requests listed in `overlays.json` every three hours. It fetches each source by commit, merges upstream main followed by each overlay into the personal branch in `skulldorged/t3code`, dispatches `personal-release.yml` from fork `main`, and waits for the builds to pass. The nightly release tag remains a version label for personal semver compatibility; it is not the source of code updates. Personal changes cover Android background connections, notifications, Catppuccin Mocha, and release infrastructure. Pi and subscription-limit patches are not included. Dispatching from one stable ref lets GitHub reuse Gradle and compiler caches between Android builds. The workflow builds:

- the Linux AppImage;
- the unsigned Windows NSIS installer and updater metadata;
- the preview Android APK;
- the server package.

After all checks and builds pass, Builder verifies the release checksums, deploys Polaris and Canis, updates the Navis Nix pin in `denix-config`, and switches Builder last. The Linux switches use the T3 service launcher's trial-and-rollback protocol. The Canis launchd switch keeps a plist backup and a copy of the database and restores them if the new server does not become healthy. Once it is healthy, the switch keeps the active and previous installs and that switch's database copy, and removes older ones along with the downloaded package.

Fleet deployment checks each machine's local activity database immediately before switching its service. If active turns are present, that machine is left on its current version while other machines continue. The release remains pending, health stays updating with a waiting-for-active-turns message, and the next timer run retries the same release without rebuilding it, unless the fork's `main` has moved since: then it builds that newer source instead, which is how a fix for a target that can't install the pending release reaches it. An unavailable or unrecognized activity database fails closed.

Each overlay in `overlays.json` names a reviewed `commit`, and only that commit is built: anyone can push to a pull request, so newer commits are logged and wait until the pin is updated after review. An overlay without a pin stops the run. Upstream main and every overlay commit are recorded by immutable SHA in `state.json` and `health.json`. An unchanged source does not rebuild. A rewritten overlay head that is not a fast-forward of the previously published head stops the run for manual integration; the updater never accumulates stale commits from a rebased overlay. A merge conflict or dirty checkout stops the run without changing the running fleet. Git rerere records reviewed resolutions. The health probe groups unresolved merge conflicts into one stable incident, and Personal Agent suppresses further actionable alerts while an earlier approval is pending.

## Builder

Keep the T3 fork's documentation identical to tracked upstream main, including app READMEs.
Personal setup and maintenance notes belong here instead of in the T3 repository. Android background
connections, notification channels, promoted live updates, and bundled Catppuccin Mocha remain personal
code changes; removing their fork documentation does not remove those features.

Home Manager installs these scripts and the `t3code-channel-update` user service and timer on argo (`home.t3codeChannel` in `modules/home/t3code-channel.nix`). They run outside the agent sandbox with Mars's GitHub login and the deploy key, so the installed copies are read-only Nix store files: change them here, commit, and activate with `fleet switch`, which Mars approves. That includes `overlays.json`, so pinning a pull request's commit is a reviewed change too. The sandbox also keeps the updater's checkout and state (`~/.local/state/t3code-channel`) and its `denix-config` clone (`~/denix-config`) read-only, since the updater runs git there.

When upstream main conflicts with the personal changes, resolve it in a separate clone of `skulldorged/t3code` (for example under `/scratch/tmp`): merge `pingdotgg/t3code` main, resolve, push to the fork's `main`, and remove the clone. The next run fast-forwards to it. For a pull-request overlay, review the new commits and update its pin in `overlays.json`.

Run an update immediately:

```sh
systemctl --user start t3code-channel-update.service
journalctl --user -fu t3code-channel-update.service
```

The durable state and downloaded releases live in `~/.local/state/t3code-channel`. Failed builds do
not advance `state.json`. A successful build records its version before fleet deployment.
Rebuilds of the same nightly label use the next personal revision after the highest existing release tag.
If deployment is interrupted, state remains pending and the same release is retried when the source
has not changed. A new nightly label starts again at `.personal.1`. The switch from the old
independent patch counter lowers the base version; clients that reject downgrades may need a one-time
manual installation. Subsequent versions follow upstream ordering.

When a run ends blocked or failed, `alert.mjs` posts the incident to a T3 webhook task ("T3 release channel stuck"), which posts it to the "T3 release channel" thread. That thread hands each alert to a fresh full-access Sonnet 5.5 child task, so earlier fixes don't ride along as context, and relays the child's report to Mars. The webhook URL and its HMAC signing secret are in `~/.config/t3code-channel/alert.json` (mode 600, hidden from the agent sandbox); the task refuses unsigned requests. After an alert it stays quiet until a run succeeds or six hours pass, so the agent fixing one failure isn't joined by another when its fix exposes the next; the open alert is `alerted.json` in the state directory.

`health.json` records the updater's current stage, source commits, workflow URL, and either a healthy,
blocked, or failed condition. `health-check.mjs` converts that file into Personal Agent's
transition-aware `status_check` protocol. It also reports a problem if the three-hour updater has not
refreshed the file in seven hours (allowing for the three-hour polling interval and build time).

## Clients

Windows and writable AppImage installs use the release feed embedded at build time: `skulldorged/t3code`. The installer is unsigned, so Windows may show SmartScreen on first install.

For Android, add this URL to Obtainium once:

```text
https://github.com/skulldorged/t3code
```

Select the APK ending in `-preview.apk`. Each workflow run uses a larger Android version code, so updates install over the previous preview build. Personal preview APKs target `arm64-v8a`, which covers the Pixel fleet while avoiding unused x86 and 32-bit native builds.

Navis remains Nix-managed. Each successful fleet release pushes a small `modules/home/t3code-release.json` update to `denix-config`; Navis only needs to pull and rebuild. A separate auto-rebuild policy can be added later if every `denix-config` main commit is safe to apply unattended.
