# SwiftHBridge

Swift driver for a single DC motor driven through a DRV8833-style H-bridge in IN/IN PWM control mode, plus nSLEEP (enable/standby) and nFAULT (fault detect) pins. Built on top of `esp-swift-mcpwm`'s raw MCPWM primitives. Swift module name: **`HBridge`**.

Depends on: `SwiftPlatform`, `SwiftMCPWM`, `SwiftGPIO`, `SwiftSupport`.

## Usage

```swift
import HBridge

let motor = try HBridge(
    in1Gpio: GPIO_NUM_10,
    in2Gpio: GPIO_NUM_11,
    nSleepGpio: GPIO_NUM_12,
    nFaultGpio: GPIO_NUM_13)

try motor.wake()
try motor.drive(direction: .forward, dutyPercent: 75)
try motor.drive(direction: .reverse, dutyPercent: 50)
try motor.brake()
try motor.coast()
if motor.isFault() == true {
    // handle overcurrent/overtemp/UVLO
}
try motor.sleep()
```

See [`CLAUDE.md`](CLAUDE.md) for full API details and non-obvious patterns.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
