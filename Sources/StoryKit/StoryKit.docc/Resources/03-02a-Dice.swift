import Foundation

public func rollD20() -> Int { Int.random(in: 1...20) }
public func checkUnder(_ threshold: Int, roll: Int = rollD20()) -> Bool { roll <= threshold }

