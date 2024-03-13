// Copyright © 2023 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import Combine

public protocol NetworkType {
    func send<T>(_ request: Network.RequestType<T>) -> AnyPublisher<(ResponseInfoType, T), Error>
}

public class Network: NetworkType {
    public struct RequestType<T> {
        public let id: String
        public let url: String?
        public let method: String?
        public let headers: [String: String]?
        public let body: Data?
        public let args: [Any?]
        public let generatePublisher: () -> AnyPublisher<(ResponseInfoType, T), Error>
        
        public init(
            id: String,
            url: String? = nil,
            method: String? = nil,
            headers: [String: String]? = nil,
            body: Data? = nil,
            args: [Any?] = [],
            generatePublisher: @escaping () -> AnyPublisher<(ResponseInfoType, T), Error>
        ) {
            self.id = id
            self.url = url
            self.method = method
            self.headers = headers
            self.body = body
            self.args = args
            self.generatePublisher = generatePublisher
        }
    }
    
    public func send<T>(_ request: RequestType<T>) -> AnyPublisher<(ResponseInfoType, T), Error> {
        return request.generatePublisher()
    }
}
