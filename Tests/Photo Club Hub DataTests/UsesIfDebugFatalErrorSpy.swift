//
//  UsesIfDebugFatalErrorSpy.swift
//  Photo Club Hub DataTests
//
//  Created by Claude Code (guided by Peter van den Hamer) on 02/11/2026.
//

import Testing // for TestTrait and TestScoping

/// Makes the tests that install the `ifDebugFatalError` spy run one at a time, also across suites (Data#1).
///
/// The spy is process-global. When two such tests overlap, one can remove or replace the spy while the other still
/// relies on it. The other test's diagnostic then lands in the wrong spy, so its check fails, or reaches `fatalError`
/// and aborts the entire test run. Tests without this trait still run in parallel with everything.
///
/// What this doesn't cover: while a spy test runs, a diagnostic from an unrelated test running in parallel is recorded
/// in the spy instead of stopping that test. So check for the expected message rather than for a message count.
struct UsesIfDebugFatalErrorSpy: TestTrait, TestScoping {

    func provideScope(for test: Test,
                      testCase: Test.Case?,
                      performing function: @Sendable () async throws -> Void) async throws {
        await SpyTestGate.shared.enter()
        do {
            try await function()
        } catch {
            await SpyTestGate.shared.leave()
            throw error
        }
        await SpyTestGate.shared.leave()
    }

}

extension Trait where Self == UsesIfDebugFatalErrorSpy {
    static var usesIfDebugFatalErrorSpy: Self { Self() }
}

/// Lets one test through at a time. The others wait, in order of arrival.
private actor SpyTestGate {

    static let shared = SpyTestGate()

    private var isOccupied: Bool = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func enter() async {
        guard isOccupied else {
            isOccupied = true
            return
        }
        await withCheckedContinuation { continuation in
            waiting.append(continuation) // resumed by leave(), which hands the gate over without opening it
        }
    }

    func leave() {
        if waiting.isEmpty {
            isOccupied = false
        } else {
            waiting.removeFirst().resume()
        }
    }

}
