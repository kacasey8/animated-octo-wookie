//
//  PacketOtherClientQuit.m
//  Snap
//
//  Created by Kevin Casey on 8/21/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "PacketOtherClientQuit.h"
#import "NSData+SnapAdditions.h"

@implementation PacketOtherClientQuit

@synthesize peerID = _peerID;
@synthesize cards = _cards;

+ (id)packetWithPeerID:(NSString *)peerID cards:(NSDictionary *)cards
{
    return [[[self class] alloc] initWithPeerID:peerID cards:cards];
}

+ (id)packetWithData:(NSData *)data
{
    size_t offset = PACKET_HEADER_SIZE;
    size_t count;
    
    NSString *peerID = [data rw_stringAtOffset:offset bytesRead:&count];
    offset += count;
    
    NSDictionary *cards = [[self class] cardsFromData:data atOffset:offset];
    
    return [[self class] packetWithPeerID:peerID cards:cards];
}
  
- (id)initWithPeerID:(NSString *)peerID cards:(NSDictionary *)cards
{
    self = [super initWithType:PacketTypeOtherClientQuit];
    if (self) {
        self.peerID = peerID;
        self.cards = cards;
    }
    return self;
}

- (void)addPayloadToData:(NSMutableData *)data
{
    [data rw_appendString:self.peerID];
    [self addCards:self.cards toPayload:data];
}

@end
