#!/usr/bin/env swift

import Foundation

private struct Catalog: Decodable {
    let schemaVersion: Int
    let updatedAt: String
    let strategies: [Strategy]
}

private struct Strategy: Decodable {
    let id: String
    let name: String
    let nameRu: String?
    let summary: String
    let summaryRu: String?
    let services: [String]
    let stability: String
    let stabilityRu: String?
    let sourceName: String
    let sourceURL: String
    let commandArgs: [String]
}

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 2 else {
    fail("usage: validate_strategy_catalog.swift <catalog.json>")
}

let fileURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let data = try? Data(contentsOf: fileURL), data.count <= 512 * 1024 else {
    fail("catalog is missing or larger than 512 KiB")
}

guard let catalog = try? JSONDecoder().decode(Catalog.self, from: data) else {
    fail("catalog does not match schema version 1")
}

guard catalog.schemaVersion == 1 else {
    fail("unsupported schemaVersion: \(catalog.schemaVersion)")
}
guard !catalog.updatedAt.isEmpty else {
    fail("updatedAt is empty")
}
guard !catalog.strategies.isEmpty && catalog.strategies.count <= 100 else {
    fail("strategy count must be between 1 and 100")
}

var identifiers = Set<String>()
for strategy in catalog.strategies {
    guard identifiers.insert(strategy.id).inserted else {
        fail("duplicate strategy id: \(strategy.id)")
    }
    guard !strategy.id.isEmpty,
          !strategy.name.isEmpty,
          !strategy.summary.isEmpty,
          !strategy.services.isEmpty,
          !strategy.stability.isEmpty,
          !strategy.sourceName.isEmpty else {
        fail("strategy \(strategy.id) has an empty required field")
    }
    guard let sourceURL = URL(string: strategy.sourceURL), sourceURL.scheme == "https" else {
        fail("strategy \(strategy.id) has a non-HTTPS sourceURL")
    }
    guard !strategy.commandArgs.isEmpty && strategy.commandArgs.count <= 160 else {
        fail("strategy \(strategy.id) has an invalid commandArgs count")
    }
    guard strategy.commandArgs.allSatisfy({
        $0.count <= 4096 && !$0.contains("\n") && !$0.contains("\r") && !$0.contains("\0")
    }) else {
        fail("strategy \(strategy.id) contains an invalid command argument")
    }
}

print("Validated \(catalog.strategies.count) online strategies")
