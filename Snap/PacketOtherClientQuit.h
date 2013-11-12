//
//  PacketOtherClientQuit.h
//  Snap
//
//  Created by Kevin Casey on 8/21/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "Packet.h"

@interface PacketOtherClientQuit : Packet

@property (nonatomic, copy) NSString *peerID;
@property (nonatomic, strong) NSDictionary *cards;

+ (id)packetWithPeerID:(NSString *)peerID cards:(NSDictionary *)cards;

@end
