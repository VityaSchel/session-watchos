// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation

public extension UnicodeScalar {
    class EmojiRange {
        // rangeStart and rangeEnd are inclusive.
        let rangeStart: UInt32
        let rangeEnd: UInt32

        // MARK: - Initializers

        init(rangeStart: UInt32, rangeEnd: UInt32) {
            self.rangeStart = rangeStart
            self.rangeEnd = rangeEnd
        }
    }

    // From:
    // https://www.unicode.org/Public/emoji/
    // Current Version:
    // https://www.unicode.org/Public/emoji/6.0/emoji-data.txt
    //
    // These ranges can be code-generated using:
    //
    // * Scripts/emoji-data.txt
    // * Scripts/emoji_ranges.py
    static let kEmojiRanges = [
        // NOTE: Don't treat Pound Sign # as Jumbomoji.
        //        EmojiRange(rangeStart:0x23, rangeEnd:0x23),
        // NOTE: Don't treat Asterisk * as Jumbomoji.
        //        EmojiRange(rangeStart:0x2A, rangeEnd:0x2A),
        // NOTE: Don't treat Digits 0..9 as Jumbomoji.
        //        EmojiRange(rangeStart:0x30, rangeEnd:0x39),
        // NOTE: Don't treat Copyright Symbol © as Jumbomoji.
        //        EmojiRange(rangeStart:0xA9, rangeEnd:0xA9),
        // NOTE: Don't treat Trademark Sign ® as Jumbomoji.
        //        EmojiRange(rangeStart:0xAE, rangeEnd:0xAE),
        EmojiRange(rangeStart: 0x200D, rangeEnd: 0x200D),
        EmojiRange(rangeStart: 0x203C, rangeEnd: 0x203C),
        EmojiRange(rangeStart: 0x2049, rangeEnd: 0x2049),
        EmojiRange(rangeStart: 0x20D0, rangeEnd: 0x20FF),
        EmojiRange(rangeStart: 0x2122, rangeEnd: 0x2122),
        EmojiRange(rangeStart: 0x2139, rangeEnd: 0x2139),
        EmojiRange(rangeStart: 0x2194, rangeEnd: 0x2199),
        EmojiRange(rangeStart: 0x21A9, rangeEnd: 0x21AA),
        EmojiRange(rangeStart: 0x231A, rangeEnd: 0x231B),
        EmojiRange(rangeStart: 0x2328, rangeEnd: 0x2328),
        EmojiRange(rangeStart: 0x2388, rangeEnd: 0x2388),
        EmojiRange(rangeStart: 0x23CF, rangeEnd: 0x23CF),
        EmojiRange(rangeStart: 0x23E9, rangeEnd: 0x23F3),
        EmojiRange(rangeStart: 0x23F8, rangeEnd: 0x23FA),
        EmojiRange(rangeStart: 0x24C2, rangeEnd: 0x24C2),
        EmojiRange(rangeStart: 0x25AA, rangeEnd: 0x25AB),
        EmojiRange(rangeStart: 0x25B6, rangeEnd: 0x25B6),
        EmojiRange(rangeStart: 0x25C0, rangeEnd: 0x25C0),
        EmojiRange(rangeStart: 0x25FB, rangeEnd: 0x25FE),
        EmojiRange(rangeStart: 0x2600, rangeEnd: 0x27BF),
        EmojiRange(rangeStart: 0x2934, rangeEnd: 0x2935),
        EmojiRange(rangeStart: 0x2B05, rangeEnd: 0x2B07),
        EmojiRange(rangeStart: 0x2B1B, rangeEnd: 0x2B1C),
        EmojiRange(rangeStart: 0x2B50, rangeEnd: 0x2B50),
        EmojiRange(rangeStart: 0x2B55, rangeEnd: 0x2B55),
        EmojiRange(rangeStart: 0x3030, rangeEnd: 0x3030),
        EmojiRange(rangeStart: 0x303D, rangeEnd: 0x303D),
        EmojiRange(rangeStart: 0x3297, rangeEnd: 0x3297),
        EmojiRange(rangeStart: 0x3299, rangeEnd: 0x3299),
        EmojiRange(rangeStart: 0xFE00, rangeEnd: 0xFE0F),
        EmojiRange(rangeStart: 0x1F000, rangeEnd: 0x1F0FF),
        EmojiRange(rangeStart: 0x1F10D, rangeEnd: 0x1F10F),
        EmojiRange(rangeStart: 0x1F12F, rangeEnd: 0x1F12F),
        EmojiRange(rangeStart: 0x1F16C, rangeEnd: 0x1F171),
        EmojiRange(rangeStart: 0x1F17E, rangeEnd: 0x1F17F),
        EmojiRange(rangeStart: 0x1F18E, rangeEnd: 0x1F18E),
        EmojiRange(rangeStart: 0x1F191, rangeEnd: 0x1F19A),
        EmojiRange(rangeStart: 0x1F1AD, rangeEnd: 0x1F1FF),
        EmojiRange(rangeStart: 0x1F201, rangeEnd: 0x1F20F),
        EmojiRange(rangeStart: 0x1F21A, rangeEnd: 0x1F21A),
        EmojiRange(rangeStart: 0x1F22F, rangeEnd: 0x1F22F),
        EmojiRange(rangeStart: 0x1F232, rangeEnd: 0x1F23A),
        EmojiRange(rangeStart: 0x1F23C, rangeEnd: 0x1F23F),
        EmojiRange(rangeStart: 0x1F249, rangeEnd: 0x1F64F),
        EmojiRange(rangeStart: 0x1F680, rangeEnd: 0x1F6FF),
        EmojiRange(rangeStart: 0x1F774, rangeEnd: 0x1F77F),
        EmojiRange(rangeStart: 0x1F7D5, rangeEnd: 0x1F7FF),
        EmojiRange(rangeStart: 0x1F80C, rangeEnd: 0x1F80F),
        EmojiRange(rangeStart: 0x1F848, rangeEnd: 0x1F84F),
        EmojiRange(rangeStart: 0x1F85A, rangeEnd: 0x1F85F),
        EmojiRange(rangeStart: 0x1F888, rangeEnd: 0x1F88F),
        EmojiRange(rangeStart: 0x1F8AE, rangeEnd: 0x1FFFD),
        EmojiRange(rangeStart: 0xE0020, rangeEnd: 0xE007F)
    ]

    var isEmoji: Bool {
        // Binary search
        var left: Int = 0
        var right = Int(UnicodeScalar.kEmojiRanges.count - 1)
        
        while true {
            let mid = (left + right) / 2
            let midRange = UnicodeScalar.kEmojiRanges[mid]
            if value < midRange.rangeStart {
                if mid == left {
                    return false
                }
                right = mid - 1
            } else if value > midRange.rangeEnd {
                if mid == right {
                    return false
                }
                left = mid + 1
            } else {
                return true
            }
        }
    }

    var isZeroWidthJoiner: Bool {
        return value == 8205
    }
}
