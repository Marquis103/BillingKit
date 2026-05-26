//
//  MockReceiptVerifier.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Foundation
@testable import BillingKit

/// Test-only `ReceiptVerifier` that records calls and either returns
/// a stubbed `VerifiedReceipt` or throws a configured error. Lives
/// in the test target so consumers can't accidentally ship it.
final class MockReceiptVerifier: ReceiptVerifier, @unchecked Sendable {

    enum Mode: Sendable {
        case succeed
        case fail(Error)
    }

    enum Failure: Error, Equatable {
        case rejected
    }

    private let lock = NSLock()
    private var _mode: Mode
    private var _calls: [String] = []

    init(mode: Mode = .succeed) {
        self._mode = mode
    }

    func setMode(_ mode: Mode) {
        lock.lock()
        defer { lock.unlock() }
        self._mode = mode
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _calls.count
    }

    var receivedTransactions: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _calls
    }

    func verify(_ signedTransaction: String) async throws -> VerifiedReceipt {
        let mode: Mode = {
            lock.lock()
            defer { lock.unlock() }
            _calls.append(signedTransaction)
            return _mode
        }()

        switch mode {
        case .succeed:
            return VerifiedReceipt(
                productID: "com.thatSwiftGuy.ayes.pro.monthly",
                originalTransactionID: "stub-original-1",
                purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
                expiresDate: Date(timeIntervalSince1970: 1_702_592_000),
                revocationDate: nil
            )
        case .fail(let error):
            throw error
        }
    }
}
