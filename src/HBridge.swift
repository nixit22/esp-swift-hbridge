// Copyright (c) 2026 Nicolas Christe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import MCPWM
import GPIO
import Platform

/// Single DC-motor channel driven through a DRV8833-style H-bridge in IN/IN PWM mode.
///
/// Owns a private `McpwmTimer` + `McpwmOperator` sized for this one motor — not shared
/// across multiple `HBridge` instances.
public struct HBridge: ~Copyable {
    public enum Direction: Equatable {
        case forward   // IN1 = PWM, IN2 = 0
        case reverse   // IN1 = 0,   IN2 = PWM
    }

    private let timer: McpwmTimer
    private let oper: McpwmOperator
    private let cmpr: McpwmComparator
    private let genIn1: McpwmGenerator
    private let genIn2: McpwmGenerator
    private let periodTicks: UInt32
    private let nSleep: Gpio
    private let nFault: Gpio?

    /// - Parameters:
    ///   - in1Gpio: DRV8833 IN1 PWM input.
    ///   - in2Gpio: DRV8833 IN2 PWM input.
    ///   - nSleepGpio: DRV8833 nSLEEP — driven high to wake, low to standby (motor coasts).
    ///   - nFaultGpio: DRV8833 nFAULT — active-low, open-drain; needs an external pull-up
    ///     per the datasheet (not configured here). `nil` if not wired.
    ///   - pwmFrequencyHz: PWM switching frequency. Default 20 kHz — above the audible
    ///     range and safe for DRV8833's internal shoot-through protection (no dead-time
    ///     insertion needed; see esp-swift-mcpwm's CLAUDE.md).
    ///
    /// Leaves the bridge coasting and asleep (nSLEEP low) after construction.
    public init(
        in1Gpio: gpio_num_t,
        in2Gpio: gpio_num_t,
        nSleepGpio: gpio_num_t,
        nFaultGpio: gpio_num_t? = nil,
        pwmFrequencyHz: UInt32 = 20_000
    ) throws(Error) {
        let periodTicks = 1_000_000 / pwmFrequencyHz
        let timer = McpwmTimer(resolutionHz: 1_000_000, periodTicks: periodTicks)
        let oper = try timer.newOperator()
        let cmpr = try oper.newComparator()
        let genIn1 = try oper.newGenerator(gpioNum: in1Gpio)
        let genIn2 = try oper.newGenerator(gpioNum: in2Gpio)

        // Only one leg is ever actively PWMing at a time (the other is forced low/high),
        // so both generators can share a single comparator for duty.
        try genIn1.setActionOnTimerEvent(direction: MCPWM_TIMER_DIRECTION_UP, event: MCPWM_TIMER_EVENT_EMPTY, action: MCPWM_GEN_ACTION_HIGH)
        try genIn1.setActionOnCompareEvent(direction: MCPWM_TIMER_DIRECTION_UP, comparator: cmpr, action: MCPWM_GEN_ACTION_LOW)
        try genIn2.setActionOnTimerEvent(direction: MCPWM_TIMER_DIRECTION_UP, event: MCPWM_TIMER_EVENT_EMPTY, action: MCPWM_GEN_ACTION_HIGH)
        try genIn2.setActionOnCompareEvent(direction: MCPWM_TIMER_DIRECTION_UP, comparator: cmpr, action: MCPWM_GEN_ACTION_LOW)

        // Coast before the timer starts.
        try genIn1.setForceLevel(0)
        try genIn2.setForceLevel(0)

        try timer.enable()
        try timer.startStop(MCPWM_TIMER_START_NO_STOP)

        let nSleep = Gpio(gpioNum: nSleepGpio)
        try nSleep.setOutput()
        try nSleep.set(level: false)  // asleep until wake()

        var nFault: Gpio? = nil
        if let nFaultGpio {
            let gpio = Gpio(gpioNum: nFaultGpio)
            try gpio.setInput()
            nFault = gpio
        }

        self.timer = timer
        self.oper = oper
        self.cmpr = cmpr
        self.genIn1 = genIn1
        self.genIn2 = genIn2
        self.periodTicks = periodTicks
        self.nSleep = nSleep
        self.nFault = nFault
    }

    /// Drive the motor. `dutyPercent` is clamped to 0...100; 0 behaves like `coast()`.
    public func drive(direction: Direction, dutyPercent: Float) throws(Error) {
        let clamped = min(max(dutyPercent, 0), 100)
        let ticks = UInt32(clamped / 100 * Float(periodTicks))
        try cmpr.setCompareValue(ticks)

        if direction == .forward {
            try genIn2.setForceLevel(0)
            try genIn1.setForceLevel(-1)
        } else {
            try genIn1.setForceLevel(0)
            try genIn2.setForceLevel(-1)
        }
    }

    /// Both legs high — shorts motor terminals (active braking).
    public func brake() throws(Error) {
        try genIn1.setForceLevel(1)
        try genIn2.setForceLevel(1)
    }

    /// Both legs low — high-impedance, motor coasts to a stop.
    public func coast() throws(Error) {
        try genIn1.setForceLevel(0)
        try genIn2.setForceLevel(0)
    }

    /// Drive nSLEEP high (wake from standby).
    public func wake() throws(Error) {
        try nSleep.set(level: true)
    }

    /// Drive nSLEEP low (standby — motor coasts, low power).
    public func sleep() throws(Error) {
        try nSleep.set(level: false)
    }

    /// `nil` if nFAULT wasn't wired; else `true` if the active-low pin currently reads
    /// low (fault latched — overcurrent/overtemp/UVLO per DRV8833 datasheet).
    public func isFault() -> Bool? {
        guard let nFault else { return nil }
        return !nFault.getLevel()
    }
}
