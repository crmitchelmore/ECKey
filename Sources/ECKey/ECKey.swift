//
//  ECKey.swift
//  Crypto Coin Swift
//
//  Created by Sjors Provoost on 26-06-14.

import Foundation

import ECurve
import UInt256

public class ECKey {
    public let privateKey: UInt256
    public let curve: ECurve
    
    public let publicKeyPoint: ECPoint
    
    
    public init(_ privateKey: UInt256, _ curve: ECurve, skipPublicKeyGeneration: Bool = false) {
        self.privateKey = privateKey
        self.curve = curve
        
        if !skipPublicKeyGeneration {
            self.publicKeyPoint = self.privateKey * self.curve.G
        } else {
            self.publicKeyPoint = curve.infinity
        }
    }
    
    
    public init(privateKey: UInt256, publicKeyPoint: ECPoint) {
        self.privateKey = privateKey
        self.publicKeyPoint = publicKeyPoint
        self.curve = publicKeyPoint.curve
    }
    
    public init(publicKeyPoint: ECPoint) {
        self.privateKey = 0
        self.publicKeyPoint = publicKeyPoint
        self.curve = publicKeyPoint.curve
    }
    
    
    public convenience init(_ privateKeyHex: String, _ curve: ECurve, skipPublicKeyGeneration: Bool = false) {
        self.init(UInt256(hexString: privateKeyHex), curve, skipPublicKeyGeneration: skipPublicKeyGeneration)
    }
    
    public var privateKeyHexString: String {
        return privateKey.toHexStringOfLength(64)
    }
    
    public var publicKeyHexString: String {
        switch publicKeyPoint.coordinate {
        case let .Affine(x,y):
            return "04" + x!.value.toHexStringOfLength(64) + y!.value.toHexStringOfLength(64)
        default:
            assert(false, "Not implemented")
            return ""
        }
    }
    
    public class func pointFromHex (hexString: String, _ curve: ECurve) -> ECPoint {
        assert(hexString.characters.count == 130, "Wrong size")
        
      let x: String = (hexString as NSString).substring(with: NSRange(location: 2, length: 64))
      let y: String = (hexString as NSString).substring(with: NSRange(location: 66, length: 64))
        
        return ECPoint(x: FFInt(x, curve.field), y: FFInt(y, curve.field), curve: curve)
    }
    
    public class func createRandom (_ curve: ECurve, skipPublicKeyGeneration: Bool = false) -> ECKey {
        // Private key is a random 256 bit integer smaller than n.
        return ECKey(UInt256.secureRandom(curve.n), curve, skipPublicKeyGeneration: skipPublicKeyGeneration)
    }
    
    public func sign (_ digest: UInt256) -> (UInt256, UInt256) {
        
        let field = FiniteField.PrimeField(p: curve.n)
        let zero = field.int(0)
        let e = field.int(digest)
        
        var s = zero
        var k: UInt256 = 0
        var r = zero

        
        while s == field.int(0) {
            
        
            while r == zero {
                k = UInt256.secureRandom(curve.n - 1) + 1
                
                let R = k * self.curve.G
                
                switch R.coordinate {
                case let .Affine(x,_):
                    r = field.int(x!.value)

                default:
                    assert(false, "Not affine")
                }
                
            }
            
            
            s = (e + privateKey * r ) / field.int(k)

        }
        
        return (r.value,s.value)
        
    }
    
    public class func verifySignature(_ digest: UInt256, r: UInt256, s:UInt256, publicKey: ECPoint) -> Bool {
        
        let curve = publicKey.curve
        let field = FiniteField.PrimeField(p: curve.n)
        let e = field.int(digest)
        
        if r <= 0 || r >= curve.n || s <= 0 || s >= curve.n {
            return false
        }
        
        let w: FFInt = 1 / field.int(s)
        
        let u1 = e * w
        let u2 = field.int(r) * w

        let P = u1.value * curve.G + u2.value * publicKey
                
        switch P.coordinate {
        case let .Affine(x,_):
            let px = field.int(x!.value)
            return px == field.int(r)
        default:
            assert(false, "Not affine")
            return false
        }

    }
    
    public class func der (_ r: UInt256, _ s: UInt256) -> NSData {
        // 0x30, 0x45, 0x02, 0x20
        
        var bytes: [UInt8] = [0x30, 0x45, 0x02, 0x20]
        let signature = NSMutableData(bytes: &bytes, length: bytes.count)
        
      signature.append(r.toData)
        bytes = [0x02, 0x21, 0x00]
      signature.append(&bytes, length: 3)
        
      signature.append(s.toData)
        
        return signature as NSData
    }
    
    public class func importDer (_ data: NSData) -> (UInt256, UInt256) {
        var R: [UInt32] = [0,0,0,0,0,0,0,0]
        var S: [UInt32] = [0,0,0,0,0,0,0,0]
        
        
        data.getBytes(&R, range: NSMakeRange(4, 0x20))
        data.getBytes(&S, range: NSMakeRange(39, 0x20))
        
        let r = UInt256(R[0].bigEndian, R[1].bigEndian, R[2].bigEndian, R[3].bigEndian, R[4].bigEndian, R[5].bigEndian, R[6].bigEndian, R[7].bigEndian)
        let s = UInt256(S[0].bigEndian, S[1].bigEndian, S[2].bigEndian, S[3].bigEndian, S[4].bigEndian, S[5].bigEndian, S[6].bigEndian, S[7].bigEndian)
        
        return (r,s)
    }
}
