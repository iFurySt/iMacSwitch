# Reliability

## Handoff guarantees

- The peer is pinged before any selected peripheral is released.
- A local release is considered complete only after a live IOBluetooth query
  observes the disconnect; the timeout is 10 seconds.
- Selected devices move sequentially. On the first failure, untouched devices
  stay connected to the source Mac.
- If the peer disappears after preflight, the source attempts rollback and
  arms a bounded reconnect watcher.
- The watcher asks the peer whether it holds a peripheral before reclaiming it.
- If an asynchronous Bluetooth removal finishes after the 10-second release
  deadline, the source observes that late disconnect for another 10 seconds
  and reclaims it instead of leaving it connected to neither Mac.
- A full-set release timeout recovers every peripheral, including devices that
  already disconnected while another device was still blocking the batch.

## Edge trigger guarantees

- Pointer position is sampled every 100 ms.
- Trigger zone is 3 points; the pointer must leave a 16-point zone before the
  trigger is armed again.
- A batch-in-progress guard prevents duplicate work even if display state or
  settings change during a handoff.
- A disconnected configured display is preserved but cannot trigger.

## Verification

- `make ci` performs project checks and an unsigned Universal build.
- Release CI verifies `codesign`, notarization stapling, and Gatekeeper
  assessment before publishing artifacts.
- Settings → Other → Export Diagnostic Logs saves bounded JSONL containing app
  lifecycle, update, AWDL/Bonjour, handoff, Bluetooth state, power, and
  reconnect events. Screen lock/unlock and actual IOKit sleep/wake are separate
  events. `timestamp_ms`, installation/session IDs, operation IDs,
  and stable peripheral hashes let exports from both Macs be aligned.
- Runtime `print`/`NSLog` output remains visible in Console.app for live
  debugging, but exported diagnostics are the supported incident artifact.

## Incident capture

After a failed switch or wake recovery, export diagnostics on both Macs before
relaunching the apps if possible. Do not edit or combine the files; their UTC
timestamps and matching hashed peripheral IDs are intended for correlation.
The export snapshot records current Bluetooth state, pairing state, active peer
state, reconnect settings, and each managed peripheral's cached state.
