//  IPCPipe+Codable.swift
//
//  First-class codable support
//
//  Created by Eric Rabil on 10/2/21.
//

import Foundation
import CodableXPC

struct EncodingProxy: Encodable {
    private var encodeFunction: (Encoder) throws -> ()
    
    init(_ encodable: Encodable) {
        encodeFunction = encodable.encode(to:)
    }
    
    func encode(to encoder: Encoder) throws {
        try encodeFunction(encoder)
    }
}

public extension IPCPipe {
    typealias TypedReplyBlock<P> = (P, audit_token_t, IPCPipe?) -> ()
    
    func write(_ encodable: Encodable, replyID: UUID? = nil) throws {
        try write(message: XPCEncoder.encode(EncodingProxy(encodable)), replyID: replyID)
    }
    
    func write<Output: Decodable>(_ encodable: Encodable, replyBlock: @escaping TypedReplyBlock<Output>) throws {
        try write(message: XPCEncoder.encode(EncodingProxy(encodable))) { response, token, pipe in
            do {
                try replyBlock(XPCDecoder.decode(Output.self, message: response), token, pipe)
            } catch {
                
            }
        }
    }
    
    func readwrite<Output: Decodable>(_ encodable: Encodable) throws -> (output: Output, token: audit_token_t, replyPipe: IPCPipe?) {
        let (response, token, pipe) = try readwrite(message: XPCEncoder.encode(EncodingProxy(encodable)))
        
        return (try XPCDecoder.decode(Output.self, message: response), token, pipe)
    }
    
    func readwrite<Output: Decodable>(_ encodable: Encodable) throws -> Output {
        try readwrite(encodable).output
    }
}
