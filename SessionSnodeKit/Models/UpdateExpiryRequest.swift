// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation

extension SnodeAPI {
    public class UpdateExpiryRequest: SnodeAuthenticatedRequestBody {
        enum CodingKeys: String, CodingKey {
            case messageHashes = "messages"
            case expiryMs = "expiry"
            case shorten
            case extend
        }
        
        /// Array of message hash strings (as provided by the storage server) to update. Messages can be from any namespace(s)
        let messageHashes: [String]
        
        /// The new expiry timestamp (milliseconds since unix epoch).  Must be >= 60s ago.  The new expiry can be anywhere from
        /// current time up to the maximum TTL (30 days) from now; specifying a later timestamp will be truncated to the maximum
        let expiryMs: UInt64
        
        /// If provided and set to true then the expiry is only shortened, but not extended. If the expiry is already at or before the given
        /// `expiry` timestamp then expiry will not be changed
        ///
        /// **Note:** This option is only supported starting at network version 19.3).  This option is not permitted when using
        /// subkey authentication
        let shorten: Bool?
        
        /// If provided and set to true then the expiry is only extended, but not shortened.  If the expiry is already at or beyond
        /// the given `expiry` timestamp then expiry will not be changed
        ///
        /// **Note:** This option is only supported starting at network version 19.3.  This option is mutually exclusive of "shorten"
        let extend: Bool?
        
        // MARK: - Init
        
        public init(
            messageHashes: [String],
            expiryMs: UInt64,
            shorten: Bool? = nil,
            extend: Bool? = nil,
            pubkey: String,
            ed25519PublicKey: [UInt8],
            ed25519SecretKey: [UInt8],
            subkey: String?
        ) {
            self.messageHashes = messageHashes
            self.expiryMs = expiryMs
            self.shorten = shorten
            self.extend = extend
            
            super.init(
                pubkey: pubkey,
                ed25519PublicKey: ed25519PublicKey,
                ed25519SecretKey: ed25519SecretKey,
                subkey: subkey
            )
        }
        
        // MARK: - Coding
        
        override public func encode(to encoder: Encoder) throws {
            var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(messageHashes, forKey: .messageHashes)
            try container.encode(expiryMs, forKey: .expiryMs)
            try container.encodeIfPresent(shorten, forKey: .shorten)
            try container.encodeIfPresent(extend, forKey: .extend)
            
            try super.encode(to: encoder)
        }
        
        // MARK: - Abstract Methods
        
        override func generateSignature() throws -> [UInt8] {
            /// Ed25519 signature of `("expire" || ShortenOrExtend || expiry || messages[0] || ...`
            /// ` || messages[N])` where `expiry` is the expiry timestamp expressed as a string.
            /// `ShortenOrExtend` is string signature must be base64 "shorten" if the shorten option is given (and true),
            /// "extend" if `extend` is true, and empty otherwise. The signature must be base64 encoded (json) or bytes (bt).
            let verificationBytes: [UInt8] = SnodeAPI.Endpoint.expire.rawValue.bytes
                .appending(contentsOf: (shorten == true ? "shorten".bytes : []))
                .appending(contentsOf: (extend == true ? "extend".bytes : []))
                .appending(contentsOf: "\(expiryMs)".data(using: .ascii)?.bytes)
                .appending(contentsOf: messageHashes.joined().bytes)
            
            guard
                let signatureBytes: [UInt8] = sodium.wrappedValue.sign.signature(
                    message: verificationBytes,
                    secretKey: ed25519SecretKey
                )
            else {
                throw SnodeAPIError.signingFailed
            }
            
            return signatureBytes
        }
    }
}
