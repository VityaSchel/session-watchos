//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation

public extension Ed25519 {
    class func publicKey(from curve25519PublicKey: Data) throws -> Data {
        return try __throws_publicKey(fromCurve25519PublicKey: curve25519PublicKey)
    }

    class func verifySignature(_ signature: Data, publicKey: Data, data: Data) throws -> Bool {
        var didVerify: ObjCBool = false
        try __verifySignature(signature, publicKey: publicKey, data: data, didVerify: &didVerify)

        return didVerify.boolValue
    }
}
