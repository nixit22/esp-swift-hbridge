# SwiftHBridge

Swift driver for a single DC motor driven through a DRV8833-style H-bridge in IN/IN PWM control mode, plus nSLEEP (enable/standby) and nFAULT (fault detect) pins. Built on `esp-swift-mcpwm`'s raw MCPWM primitives — turns the "PWM one leg, force the other low" pattern into a reusable type. Swift module name: **`HBridge`**.

Depends on: `SwiftPlatform`, `SwiftMCPWM`, `SwiftGPIO`, `SwiftSupport`

## Files

| File | Role |
|---|---|
| `src/HBridge.swift` | `HBridge` struct — the public Swift API |

## Public API

```swift
import HBridge

let motor = try HBridge(
    in1Gpio: GPIO_NUM_10,
    in2Gpio: GPIO_NUM_11,
    nSleepGpio: GPIO_NUM_12,
    nFaultGpio: GPIO_NUM_13,   // optional — nil if not wired
    pwmFrequencyHz: 20_000)    // default; override for other motors/ICs

try motor.wake()
try motor.drive(direction: .forward, dutyPercent: 75)
try motor.drive(direction: .reverse, dutyPercent: 50)
try motor.brake()   // both legs high — active braking
try motor.coast()   // both legs low — high-impedance
if motor.isFault() == true {
    // overcurrent / overtemp / UVLO per DRV8833 datasheet
}
try motor.sleep()
// No explicit cleanup — deinit handles it (timer, operator, comparator, generators).
```

## Non-obvious patterns

**Owns its own `McpwmTimer`/`McpwmOperator`** — unlike a sensor driver borrowing a caller-owned bus (see AHT20), `HBridge` is self-contained: each instance creates a private timer sized to its own `pwmFrequencyHz`. Multiple motors mean multiple independent `HBridge` instances (each with its own timer/operator) — there is no shared-timer mode in v1.

**One comparator shared by both generators** — only one leg is ever actively PWMing at a time in IN/IN mode (the other is forced low/high via `setForceLevel`), so `genIn1`/`genIn2` both read duty off the single `cmpr`. `drive()` sets the shared compare value, then forces the inactive leg to `0` and releases the active leg (`setForceLevel(-1)`) to resume PWM.

**`Direction` sign convention** — `.forward` = IN1 PWMs / IN2 held low; `.reverse` = IN2 PWMs / IN1 held low. `dutyPercent` is always unsigned 0...100, clamped; `drive(direction:, dutyPercent: 0)` is equivalent to `coast()` (comparator set to 0 ticks, but both legs are still whatever the last `setForceLevel` state was — call `coast()` explicitly for the high-impedance guarantee).

**`nSLEEP` is required, `nFAULT` is optional** — every DRV8833 wiring needs some way to enable/standby the chip, but `nFAULT` (active-low, open-drain, needs an external pull-up per the datasheet — not configured by this driver) is sometimes left unconnected. `isFault()` returns `Bool?`: `nil` means "not wired," not "no fault."

**Construction leaves the motor coasting and asleep** — `init` forces both legs low and drives `nSLEEP` low before returning. Callers must `wake()` before the first `drive()`/`brake()` has any electrical effect (DRV8833 outputs are Hi-Z while asleep regardless of IN1/IN2).

**No dead-time insertion** — same rationale as `esp-swift-mcpwm`: DRV8833 handles shoot-through protection internally. A driver for a discrete FET bridge would need `mcpwm_generator_set_dead_time()`.