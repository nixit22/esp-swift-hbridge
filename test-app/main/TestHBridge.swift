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

import GPIO
import HBridge
import MCPWM
import Platform

func testHBridge(logger: Logger) {
    do {
        let motor = try HBridge(
            in1Gpio: GPIO_NUM_10,
            in2Gpio: GPIO_NUM_11,
            nSleepGpio: GPIO_NUM_12,
            nFaultGpio: GPIO_NUM_13)

        try motor.wake()
        logger.i("HBridge: awake")

        try motor.drive(direction: .forward, dutyPercent: 75)
        logger.i("HBridge: forward 75%")

        try motor.drive(direction: .reverse, dutyPercent: 50)
        logger.i("HBridge: reverse 50%")

        try motor.brake()
        logger.i("HBridge: brake")

        try motor.coast()
        logger.i("HBridge: coast")

        switch motor.isFault() {
        case .some(true): logger.i("HBridge: fault = true")
        case .some(false): logger.i("HBridge: fault = false")
        case .none: logger.i("HBridge: fault = not wired")
        }

        try motor.sleep()
        logger.i("HBridge: asleep")

        logger.i("HBridge: APIs compiled and linked successfully")
        // motor freed by deinit (generators, comparator, operator, timer, in that order)
    } catch {
        logger.e("HBridge: failed: \(error.name)")
    }
}
