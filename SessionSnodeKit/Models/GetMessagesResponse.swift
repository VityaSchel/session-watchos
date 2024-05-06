// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation

public class GetMessagesResponse: SnodeResponse {
    private enum CodingKeys: String, CodingKey {
        case messages
        case more
    }
    
    public class RawMessage: Codable {
        private enum CodingKeys: String, CodingKey {
            case data
            case expiration
            case hash
            case timestamp
        }
        
        public let data: String
        public let expiration: Int64?
        public let hash: String
        public let timestamp: Int64
    }
    
    public let messages: [RawMessage]
    public let more: Bool
    
    // MARK: - Initialization
    
    required init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        
        messages = try container.decode([RawMessage].self, forKey: .messages)
        more = try container.decode(Bool.self, forKey: .more)
        
        try super.init(from: decoder)
    }
}
