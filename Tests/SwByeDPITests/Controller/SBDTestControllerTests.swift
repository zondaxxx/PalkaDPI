//
//  SBDTestControllerTests.swift
//  SwByeDPI
//
//  Created by developer on 21.02.2026.
//

import XCTest
@testable import SwByeDPI

final class SBDTestControllerTests: XCTestCase {
    
    let testController = SBDTestController()
    nonisolated(unsafe) static var domainLists: [SBDDomainList] = []
    nonisolated(unsafe) static var domainsCount = 0
    nonisolated(unsafe) static var strategyLists: [SBDStrategyList] = []
    nonisolated(unsafe) static var testConfig = SBDTestConfig(domainRequestsCount: 1, parallelRequestsCount: 1, domainAnswerTimeoutInS: 1, delayBetweenRequestsInS: 0, fakeSNI: "", domainListIDs: Set(), strategyListIDs: Set())
    
    override class func setUp() {
        super.setUp()
        domainLists = [
            GoogleVideoTestDomains.domainsList,
            YouTubeTestDomains.domainsList
        ]
        domainsCount = GoogleVideoTestDomains.domainsList.items.count + YouTubeTestDomains.domainsList.items.count
        strategyLists = [
            TestConstants.strategies
        ]
        testConfig = SBDTestConfig(domainRequestsCount: 2, parallelRequestsCount: 10, domainAnswerTimeoutInS: 3, delayBetweenRequestsInS: 1, fakeSNI: "google.com", domainListIDs: Set(domainLists.map { list in
            return list.id
        }), strategyListIDs: Set(strategyLists.map({ list in
            return list.id
        })))
    }
    
    func testStrategies() async {
        let exp = self.expectation(description: "Test time-out expectation")
        testController.test(config: SBDTestControllerTests.testConfig, domainLists: SBDTestControllerTests.domainLists, strategyLists: SBDTestControllerTests.strategyLists) { result in
            do {
                let testRes = try result.get()
                XCTAssertEqual(testRes.count, TestConstants.strategies.items.count, "Invalid scan process - strategies for scan count != strategies test results count")
                for strategyTestRes in testRes {
                    XCTAssertEqual(strategyTestRes.domainsTestsResult.count, SBDTestControllerTests.domainsCount, "Invalid scan process - strategy '" + strategyTestRes.strategy.cmdArgsLine + "' tested domains count != domains for scan count")
                }
            } catch {
                print(error)
                XCTAssertTrue(false, "Test errror: " + error.localizedDescription)
            }
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 600)
        testController.cancelTest()
        _ = ByeDPI.stop()
    }
    
    func testStrategiesAsync() async {
        let exp = self.expectation(description: "Test time-out expectation")
        let tested = await testController.test(config: SBDTestControllerTests.testConfig, domainLists: SBDTestControllerTests.domainLists, strategyLists: SBDTestControllerTests.strategyLists)
        do {
            let testRes = try tested.get()
            XCTAssertEqual(testRes.count, TestConstants.strategies.items.count, "Invalid scan process - strategies for scan count != strategies test results count")
            for strategyTestRes in testRes {
                XCTAssertEqual(strategyTestRes.domainsTestsResult.count, SBDTestControllerTests.domainsCount, "Invalid scan process - strategy '" + strategyTestRes.strategy.cmdArgsLine + "' tested domains count != domains for scan count")
            }
        } catch {
            print(error)
            XCTAssertTrue(false, "Test errror: " + error.localizedDescription)
        }
        exp.fulfill()
        await fulfillment(of: [exp], timeout: 600)
        testController.cancelTest()
        _ = ByeDPI.stop()
    }

    func testCancellation() async {
        let exp = self.expectation(description: "Test time-out expectation")
        let nowTs = Date().timeIntervalSince1970
        testController.test(config: SBDTestControllerTests.testConfig, domainLists: SBDTestControllerTests.domainLists, strategyLists: SBDTestControllerTests.strategyLists) { result in
            let finishTestTs = Date().timeIntervalSince1970
            do {
                let testRes = try result.get()
                XCTAssertEqual(testRes.count, TestConstants.strategies.items.count, "Invalid scan cancel process - strategies for scan count != strategies test results count")
            } catch {
                print(error)
                XCTAssertTrue(false, "Test errror: " + error.localizedDescription)
            }
            let deltaTs = finishTestTs - nowTs
            XCTAssertGreaterThanOrEqual(deltaTs, 10, "Test finished earlier than cancel fire")
            XCTAssertLessThan(deltaTs, 20, "Testing was continued after cancel fire too long")
            XCTAssertFalse(self.testController.testingInProgress, "Controller must release its lifecycle state before completion")
            exp.fulfill()
        }
        sleep(10)
        print("Cancel iniated")
        testController.cancelTest()
        await fulfillment(of: [exp], timeout: 600)
        _ = ByeDPI.stop()
    }
    
    func testCancellationAsync() async {
        let exp = self.expectation(description: "Test time-out expectation")
        nonisolated(unsafe) let unsafeController = testController
        let nowTs = Date().timeIntervalSince1970
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            print("Cancel iniated")
            unsafeController.cancelTest()
        }
        let tested = await testController.test(config: SBDTestControllerTests.testConfig, domainLists: SBDTestControllerTests.domainLists, strategyLists: SBDTestControllerTests.strategyLists)
        let finishTestTs = Date().timeIntervalSince1970
        do {
            let testRes = try tested.get()
            XCTAssertEqual(testRes.count, TestConstants.strategies.items.count, "Invalid scan cancel process - strategies for scan count != strategies test results count")
        } catch {
            print(error)
            XCTAssertTrue(false, "Test errror: " + error.localizedDescription)
        }
        let deltaTs = finishTestTs - nowTs
        XCTAssertGreaterThanOrEqual(deltaTs, 10, "Test finished earlier than cancel fire")
        XCTAssertLessThan(deltaTs, 20, "Testing was continued after cancel fire too long")
        exp.fulfill()
        await fulfillment(of: [exp], timeout: 600)
        _ = ByeDPI.stop()
    }
    
}
