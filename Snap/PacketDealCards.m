//
//  PacketDealCards.m
//  Snap
//
//  Created by Kevin Casey on 8/21/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "PacketDealCards.h"
#import "NSData+SnapAdditions.h"

@implementation PacketDealCards

@synthesize cards = _cards;
@synthesize startingPeerID = _startingPeerID;

+ (id)packetWithCards:(NSDictionary *)cards startingWithPlayerPeerID:(NSString *)startingPeerID
{
    return [[[self class] alloc] initWithCards:cards startingWithPlayerPeerID:startingPeerID];
}

+ (id)packetWithData:(NSData *)data
{
    size_t offset = PACKET_HEADER_SIZE;
    size_t count;
    
    NSString *startingPeerID = [data rw_stringAtOffset:offset bytesRead:&count];
    offset += count;
    
    NSDictionary *cards = [[self class] cardsFromData:data atOffset:offset];
    
    return [[self class] packetWithCards:cards startingWithPlayerPeerID:startingPeerID];
}

- (id)initWithCards:(NSDictionary *)cards startingWithPlayerPeerID:(NSString *)startingPeerID
{
    self = [super initWithType:PacketTypeDealCards];
    if (self) {
        self.cards = cards;
        self.startingPeerID = startingPeerID;
    }
    return self;
}

- (void)addPayloadToData:(NSMutableData *)data
{
    [data rw_appendString:self.startingPeerID];
    [self addCards:self.cards toPayload:data];
}

@end
