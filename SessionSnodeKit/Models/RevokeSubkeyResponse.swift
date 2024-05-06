// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import Sodium
import SessionUtilitiesKit

public class RevokeSubkeyResponse: SnodeRecursiveResponse<SnodeSwarmItem> {}

// MARK: - ValidatableResponse

extension RevokeSubkeyResponse: ValidatableResponse {
    typealias ValidationData = String
    typealias ValidationResponse = Bool
    
    /// All responses in the swarm must be valid
    internal static var requiredSuccessfulResponses: Int { -1 }
    
    internal func validResultMap(
        sodium: Sodium,
        userX25519PublicKey: String,
        validationData: String
    ) throws -> [String: Bool] {
        let validationMap: [String: Bool] = try swarm.reduce(into: [:]) { result, next in
            guard
                !next.value.failed,
                let signatureBase64: String = next.value.signatureBase64,
                let encodedSignature: Data = Data(base64Encoded: signatureBase64)
            else {
                if let reason: String = next.value.reason, let statusCode: Int = next.value.code {
                    SNLog("Couldn't revoke subkey from: \(next.key) due to error: \(reason) (\(statusCode)).")
                }
                else {
                    SNLog("Couldn't revoke subkey from: \(next.key).")
                }
                return
            }
            
            /// Signature of `( PUBKEY_HEX || SUBKEY_TAG_BYTES )` where `SUBKEY_TAG_BYTES` is the
            /// requested subkey tag for revocation
            let verificationBytes: [UInt8] = userX25519PublicKey.bytes
                .appending(contentsOf: validationData.bytes)
            let isValid: Bool = sodium.sign.verify(
                message: verificationBytes,
                publicKey: Data(hex: next.key).bytes,
                signature: encodedSignature.bytes
            )
            
            // If the update signature is invalid then we want to fail here
            guard isValid else { throw SnodeAPIError.signatureVerificationFailed }
            
            result[next.key] = isValid
        }
        
        return try Self.validated(map: validationMap)
    }
}
