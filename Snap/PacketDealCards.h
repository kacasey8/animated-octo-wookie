//
//  PacketDealCards.h
//  Snap
//
//  Created by Kevin Casey on 8/21/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "Packet.h"

@class Player;

@interface PacketDealCards : Packet

@property (nonatomic, strong) NSDictionary *cards;
@property (nonatomic, strong) NSString *startingPeerID;

+ (id)packetWithCards:(NSDictionary *)cards startingWithPlayerPeerID:(NSString *)startingPeerID;

@end
