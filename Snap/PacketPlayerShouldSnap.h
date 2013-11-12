//
//  PacketPlayerShouldSnap.h
//  Snap
//
//  Created by Kevin Casey on 8/23/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "Packet.h"

@interface PacketPlayerShouldSnap : Packet

@property (nonatomic, copy) NSString *peerID;

+ (id)packetWithPeerID:(NSString *)peerID;

@end
