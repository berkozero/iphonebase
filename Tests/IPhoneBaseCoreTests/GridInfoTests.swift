import Testing
@testable import IPhoneBaseCore

@Suite("GridInfo.cellLabel")
struct GridInfoCellLabelTests {

    @Test("First cell is A1")
    func firstCell() {
        #expect(GridInfo.cellLabel(row: 0, col: 0) == "A1")
    }

    @Test("Column increments through alphabet")
    func columnIncrement() {
        #expect(GridInfo.cellLabel(row: 0, col: 0) == "A1")
        #expect(GridInfo.cellLabel(row: 0, col: 1) == "B1")
        #expect(GridInfo.cellLabel(row: 0, col: 25) == "Z1")
    }

    @Test("Row increments are 1-indexed")
    func rowIncrement() {
        #expect(GridInfo.cellLabel(row: 0, col: 0) == "A1")
        #expect(GridInfo.cellLabel(row: 1, col: 0) == "A2")
        #expect(GridInfo.cellLabel(row: 9, col: 0) == "A10")
    }

    @Test("Double-letter columns after Z")
    func doubleLetterColumns() {
        #expect(GridInfo.cellLabel(row: 0, col: 26) == "AA1")
        #expect(GridInfo.cellLabel(row: 0, col: 27) == "AB1")
    }

    @Test("Middle of grid")
    func middleOfGrid() {
        #expect(GridInfo.cellLabel(row: 2, col: 1) == "B3")
        #expect(GridInfo.cellLabel(row: 4, col: 3) == "D5")
    }
}

@Suite("GridInfo.parseCell")
struct GridInfoParseCellTests {

    @Test("Parses simple cell labels")
    func simpleLabels() {
        let a1 = GridInfo.parseCell("A1")
        #expect(a1?.row == 0)
        #expect(a1?.col == 0)

        let b3 = GridInfo.parseCell("B3")
        #expect(b3?.row == 2)
        #expect(b3?.col == 1)

        let z1 = GridInfo.parseCell("Z1")
        #expect(z1?.row == 0)
        #expect(z1?.col == 25)
    }

    @Test("Case insensitive parsing")
    func caseInsensitive() {
        let lower = GridInfo.parseCell("b3")
        let upper = GridInfo.parseCell("B3")
        #expect(lower?.row == upper?.row)
        #expect(lower?.col == upper?.col)
    }

    @Test("Double-letter columns")
    func doubleLetterColumns() {
        let aa1 = GridInfo.parseCell("AA1")
        #expect(aa1?.row == 0)
        #expect(aa1?.col == 26)

        let ab1 = GridInfo.parseCell("AB1")
        #expect(ab1?.row == 0)
        #expect(ab1?.col == 27)
    }

    @Test("Invalid inputs return nil")
    func invalidInputs() {
        #expect(GridInfo.parseCell("") == nil)
        #expect(GridInfo.parseCell("123") == nil)
        #expect(GridInfo.parseCell("ABC") == nil)
        #expect(GridInfo.parseCell("A0") == nil)  // row 0 is invalid (1-indexed)
        #expect(GridInfo.parseCell("!@#") == nil)
    }

    @Test("Round-trip: cellLabel -> parseCell")
    func roundTrip() {
        for row in 0..<10 {
            for col in 0..<30 {
                let label = GridInfo.cellLabel(row: row, col: col)
                let parsed = GridInfo.parseCell(label)
                #expect(parsed?.row == row, "Round-trip failed for row=\(row), col=\(col), label=\(label)")
                #expect(parsed?.col == col, "Round-trip failed for row=\(row), col=\(col), label=\(label)")
            }
        }
    }
}

@Suite("GridInfo.centerForCell")
struct GridInfoCenterForCellTests {

    @Test("Returns center for known cell")
    func knownCell() {
        let cells: [String: GridCell] = [
            "A1": GridCell(x: 0, y: 0, width: 100, height: 100, centerX: 50, centerY: 50),
            "B1": GridCell(x: 100, y: 0, width: 100, height: 100, centerX: 150, centerY: 50),
        ]
        let grid = GridInfo(rows: 1, cols: 2, cells: cells)

        let a1 = grid.centerForCell("A1")
        #expect(a1?.x == 50)
        #expect(a1?.y == 50)

        let b1 = grid.centerForCell("B1")
        #expect(b1?.x == 150)
        #expect(b1?.y == 50)
    }

    @Test("Returns nil for unknown cell")
    func unknownCell() {
        let grid = GridInfo(rows: 1, cols: 1, cells: [
            "A1": GridCell(x: 0, y: 0, width: 100, height: 100, centerX: 50, centerY: 50),
        ])
        #expect(grid.centerForCell("Z99") == nil)
    }

    @Test("Case insensitive lookup")
    func caseInsensitive() {
        let grid = GridInfo(rows: 1, cols: 1, cells: [
            "A1": GridCell(x: 0, y: 0, width: 100, height: 100, centerX: 50, centerY: 50),
        ])
        #expect(grid.centerForCell("a1") != nil)
    }
}
