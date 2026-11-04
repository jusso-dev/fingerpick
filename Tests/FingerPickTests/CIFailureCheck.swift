import Testing

// Temporary: proves a failing test fails CI (#2 test plan). Never merge.
@Test func deliberatelyFails() {
    #expect(1 == 2)
}
