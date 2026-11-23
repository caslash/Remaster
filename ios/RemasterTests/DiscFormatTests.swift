//
//  DiscFormatTests.swift
//  RemasterTests
//
//  DiscFormat's ordering (RMSTR-18): the Comparable conformance the upgrade
//  check will build on, and sortList, which every saved copy's ownedFormats goes
//  through. ownedFormats holds raw strings, so sortList has to keep values the
//  app doesn't recognise (an older or misspelled format) rather than drop or
//  crash on them.
//

import Testing
@testable import Remaster

@Suite("DiscFormat ordering")
struct DiscFormatTests {

    // MARK: - Comparable

    @Test("DVD < Blu-ray < 4K UHD")
    func upgradeOrder() {
        #expect(DiscFormat.dvd < .bluray)
        #expect(DiscFormat.bluray < .uhd)
        #expect(DiscFormat.dvd < .uhd)
    }

    @Test("A format is never less than itself")
    func irreflexive() {
        for format in DiscFormat.allCases {
            #expect(!(format < format), "\(format) < itself")
        }
    }

    @Test("Sorting the cases ascending gives the upgrade path")
    func allCasesSorted() {
        #expect(DiscFormat.allCases.shuffled().sorted() == [.dvd, .bluray, .uhd])
    }

    // MARK: - sortList

    @Test("Known formats come back highest first, whatever order they went in", arguments: [
        ["DVD", "Blu-ray", "4K UHD"],
        ["4K UHD", "DVD", "Blu-ray"],
        ["Blu-ray", "4K UHD", "DVD"],
    ])
    func knownHighestFirst(_ input: [String]) {
        #expect(DiscFormat.sortList(input) == ["4K UHD", "Blu-ray", "DVD"])
    }

    @Test("An unknown format is kept and goes after every known one")
    func unknownGoesLast() {
        #expect(DiscFormat.sortList(["BluRay", "DVD", "4K UHD"]) == ["4K UHD", "DVD", "BluRay"])
    }

    @Test("Unknown formats keep the order they were saved in")
    func unknownsKeepSavedOrder() {
        #expect(DiscFormat.sortList(["Foo", "DVD", "BluRay", "Bar"]) == ["DVD", "Foo", "BluRay", "Bar"])
    }

    @Test("A list of only unknown formats comes back unchanged")
    func onlyUnknowns() {
        #expect(DiscFormat.sortList(["UHD4K", "BLURAY", "laserdisc"]) == ["UHD4K", "BLURAY", "laserdisc"])
    }

    @Test("Duplicates are left for the caller to remove")
    func keepsDuplicates() {
        #expect(DiscFormat.sortList(["DVD", "4K UHD", "DVD"]) == ["4K UHD", "DVD", "DVD"])
    }

    @Test("An empty list stays empty")
    func emptyList() {
        #expect(DiscFormat.sortList([]).isEmpty)
    }
}
