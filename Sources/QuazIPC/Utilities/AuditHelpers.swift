////  File.swift
//  
//
//  Created by Eric Rabil on 10/2/21.
//  
//

import Foundation

public extension audit_token_t {
    var auid: uid_t { audit_token_to_auid(self) }
    var euid: uid_t { audit_token_to_euid(self) }
    var egid: gid_t { audit_token_to_egid(self) }
    var ruid: uid_t { audit_token_to_ruid(self) }
    var rgid: gid_t { audit_token_to_rgid(self) }
    var pid: pid_t { audit_token_to_pid(self) }
    var asid: au_asid_t { audit_token_to_asid(self) }
    var pidversion: Int32 { audit_token_to_pidversion(self) }
}
