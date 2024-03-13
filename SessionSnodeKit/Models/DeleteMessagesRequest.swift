// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation

extension SnodeAPI {
    public class DeleteMessagesRequest: SnodeAuthenticatedRequestBody {
        enum CodingKeys: String, CodingKey {
            case messageHashes = "messages"
            case requireSuccessfulDeletion = "required"
        }
        
        let messageHashes: [String]
        let requireSuccessfulDeletion: Bool
        
        // MARK: - Init
        
        public init(
            messageHashes: [String],
            requireSuccessfulDeletion: Bool,
            pubkey: String,
            ed25519PublicKey: [UInt8],
            ed25519SecretKey: [UInt8]
        ) {
            self.messageHashes = messageHashes
            self.requireSuccessfulDeletion = requireSuccessfulDeletion
            
            super.init(
                pubkey: pubkey,
                ed25519PublicKey: ed25519PublicKey,
                ed25519SecretKey: ed25519SecretKey
            )
        }
        
        // MARK: - Coding
        
        override public func encode(to encoder: Encoder) throws {
            var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(messageHashes, forKey: .messageHashes)
            
            // Omitting the value is the same as false so omit to save data
            if requireSuccessfulDeletion {
                try container.encode(requireSuccessfulDeletion, forKey: .requireSuccessfulDeletion)
            }
            
            try super.encode(to: encoder)
        }
        
        // MARK: - Abstract Methods
        
        override func generateSignature() throws -> [UInt8] {
            /// Ed25519 signature of `("delete" || messages...)`; this signs the value constructed
            /// by concatenating "delete" and all `messages` values, using `pubkey` to sign.  Must be base64
            /// encoded for json requests; binary for OMQ requests.
            let verificationBytes: [UInt8] = SnodeAPI.Endpoint.deleteMessages.rawValue.bytes
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
