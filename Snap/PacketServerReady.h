//
//  PacketServerReady.h
//  Snap
//
//  Created by Kevin Casey on 8/20/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "Packet.h"

@interface PacketServerReady : Packet

@property (nonatomic, strong) NSMutableDictionary *players;

+ (id)packetWithPlayers:(NSMutableDictionary *)players;

@end
