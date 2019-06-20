// Copyright 2012 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build windows

package winapi

import "syscall"

type SidIdentifierAuthority struct {
	Value [6]byte
}

var (
	SECURITY_NULL_SID_AUTHORITY        = SidIdentifierAuthority{[6]byte{0, 0, 0, 0, 0, 0}}
	SECURITY_WORLD_SID_AUTHORITY       = SidIdentifierAuthority{[6]byte{0, 0, 0, 0, 0, 1}}
	SECURITY_LOCAL_SID_AUTHORITY       = SidIdentifierAuthority{[6]byte{0, 0, 0, 0, 0, 2}}
	SECURITY_CREATOR_SID_AUTHORITY     = SidIdentifierAuthority{[6]byte{0, 0, 0, 0, 0, 3}}
	SECURITY_NON_UNIQUE_AUTHORITY      = SidIdentifierAuthority{[6]byte{0, 0, 0, 0, 0, 4}}
	SECURITY_NT_AUTHORITY              = SidIdentifierAuthority{[6]byte{0, 0, 0, 0, 0, 5}}
	SECURITY_MANDATORY_LABEL_AUTHORITY = SidIdentifierAuthority{[6]byte{0, 0, 0, 0, 0, 16}}
)

const (
	SECURITY_NULL_RID                   = 0
	SECURITY_WORLD_RID                  = 0
	SECURITY_LOCAL_RID                  = 0
	SECURITY_CREATOR_OWNER_RID          = 0
	SECURITY_CREATOR_GROUP_RID          = 1
	SECURITY_DIALUP_RID                 = 1
	SECURITY_NETWORK_RID                = 2
	SECURITY_BATCH_RID                  = 3
	SECURITY_INTERACTIVE_RID            = 4
	SECURITY_LOGON_IDS_RID              = 5
	SECURITY_SERVICE_RID                = 6
	SECURITY_LOCAL_SYSTEM_RID           = 18
	SECURITY_BUILTIN_DOMAIN_RID         = 32
	SECURITY_PRINCIPAL_SELF_RID         = 10
	SECURITY_CREATOR_OWNER_SERVER_RID   = 0x2
	SECURITY_CREATOR_GROUP_SERVER_RID   = 0x3
	SECURITY_LOGON_IDS_RID_COUNT        = 0x3
	SECURITY_ANONYMOUS_LOGON_RID        = 0x7
	SECURITY_PROXY_RID                  = 0x8
	SECURITY_ENTERPRISE_CONTROLLERS_RID = 0x9
	SECURITY_SERVER_LOGON_RID           = SECURITY_ENTERPRISE_CONTROLLERS_RID
	SECURITY_AUTHENTICATED_USER_RID     = 0xb
	SECURITY_RESTRICTED_CODE_RID        = 0xc
	SECURITY_NT_NON_UNIQUE_RID          = 0x15
)

type Tokengroups struct {
	GroupCount uint32
	Groups     [1]syscall.SIDAndAttributes
}

//sys	AllocateAndInitializeSid(identAuth *SidIdentifierAuthority, subAuth byte, subAuth0 uint32, subAuth1 uint32, subAuth2 uint32, subAuth3 uint32, subAuth4 uint32, subAuth5 uint32, subAuth6 uint32, subAuth7 uint32, sid **syscall.SID) (err error) = advapi32.AllocateAndInitializeSid
//sys	FreeSid(sid *syscall.SID) (err error) [failretval!=0] = advapi32.FreeSid
//sys	EqualSid(sid1 *syscall.SID, sid2 *syscall.SID) (isEqual bool) = advapi32.EqualSid
