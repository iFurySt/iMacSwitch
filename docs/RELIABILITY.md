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
- Runtime `print`/`NSLog` output is visible in Console.app by filtering for the
  `iMacSwitch` process. Useful markers include AWDL scoped addresses, edge
  trigger, batch handoff progress, and reconnect watcher decisions.
