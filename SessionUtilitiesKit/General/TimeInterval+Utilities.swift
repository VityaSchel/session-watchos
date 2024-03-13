// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation

public extension TimeInterval {
    enum DurationFormat {
        case short
        case long
        case hoursMinutesSeconds
        case videoDuration
        case twoUnits
    }
    
    func formatted(format: DurationFormat) -> String {
        return String.formattedDuration(self, format: format)
    }
}
