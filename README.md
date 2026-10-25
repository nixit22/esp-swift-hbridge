# SwiftHBridge

Swift driver for a single DC motor driven through a DRV8833-style H-bridge in IN/IN PWM control mode, plus nSLEEP (enable/standby) and nFAULT (fault detect) pins. Built on top of `esp-swift-mcpwm`'s raw MCPWM primitives. Swift module name: **`HBridge`**.

Depends on: `SwiftPlatform`, `SwiftMCPWM`, `SwiftGPIO`, `SwiftSupport`.

## Adding it to a project

This is a [SwiftPM](https://www.swift.org/package-manager/) package, built for ESP-IDF by
`swift_package()` from [esp-swift-support](https://github.com/nixit22/esp-swift-support). In your
app's `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nixit22/esp-swift-hbridge.git", from: "0.1.0"),
],
targets: [
    .target(name: "App", dependencies: [.product(name: "HBridge", package: "esp-swift-hbridge")]),
]
```

See esp-swift-support's README for the project setup (top-level `CMakeLists.txt`, `main`
component, Swift toolchain).

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
