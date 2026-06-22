# Casio Deck Bluetooth Helper

Experimental Linux helper for Casio Bluetooth watches. V1 implements the Casio
ABL-100WE-1A, module 3565, through a model adapter registry.

This helper is the Bluetooth side of Casio Deck. It follows the
GShockTimeServer/GShockAPI approach: use `bleak` for BLE access, use
`gshock-api` for the Casio protocol, wait for a watch-initiated connection, read
the pressed-button value exposed by `GshockAPI`, and print the Casio Deck line
protocol to stdout.

It is diagnostic-only for now. It does not set the time or write watch settings.

## Run

From the repository root:

```sh
./scripts/run-abl100-helper.sh --model abl100we --loop --debug
```

Scan only:

```sh
./scripts/run-abl100-helper.sh --model abl100we --scan-only --debug
```

Connect once:

```sh
./scripts/run-abl100-helper.sh --model abl100we --once --debug
```

## Watch Test

Keep the phone app/Bluetooth disconnected while testing with the PC.

1. Start `btmon` capture:

   ```sh
   sudo btmon -w "abl100we-$(date +%Y%m%d-%H%M%S).cfa"
   ```

2. Run the helper:

   ```sh
   ./scripts/run-abl100-helper.sh --model abl100we --loop --debug
   ```

3. Try watch actions:

   - Hold `C` for at least three seconds to connect.
   - Press `D` in Timekeeping Mode for TIME&PLACE.
   - Hold `D` for Phone Finder.

Expected stdout lines look like:

```text
ready casio-deck-helper 0.1.0 casio_abl100we_3565
model casio_abl100we_3565 Casio_ABL-100WE-1A module=3565 support=experimental
capabilities casio_abl100we_3565 lower_left,lower_right,timeplace,finder,unknown
connect
watch casio_abl100we_3565 CASIO_ABL-100WE-1A XX:XX:XX:XX:XX:XX
press lower_right
disconnect
```

## Adapter Registry

The helper-side registry lives in:

```text
src/casio_deck_helper/models.py
```

An adapter defines:

- model id
- aliases accepted by `--model`
- display name and module number
- scan filters
- normalized trigger ids
- capabilities and support level

Only `casio_abl100we_3565` is implemented. Future watches should be added as
new adapters instead of adding Bluetooth logic to the Noctalia Luau plugin.
