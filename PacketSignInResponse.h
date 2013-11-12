//
//  PacketSignInResponse.h
//  Snap
//
//  Created by Kevin Casey on 8/20/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "Packet.h"

@interface PacketSignInResponse : Packet

@property (nonatomic, copy) NSString* playerName;

+(id)packetWithPlayerName:(NSString *)playerName;

@end
