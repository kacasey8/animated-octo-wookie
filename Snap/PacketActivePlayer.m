//
//  PacketActivePlayer.m
//  Snap
//
//  Created by Kevin Casey on 8/21/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "PacketActivePlayer.h"
#import "NSData+SnapAdditions.h"

@implementation PacketActivePlayer

@synthesize peerID = _peerID;

+ (id)packetWithPeerID:(NSString *)peerID
{
    return [[[self class] alloc] initWithPeerID:peerID];
}

- (id)initWithPeerID:(NSString *)peerID
{
    self = [super initWithType:PacketTypeActivatePlayer];
    if (self) {
        self.packetNumber = 0; // enable packet numbers for this packet
        self.peerID = peerID;
    }
    return self;
}

+ (id)packetWithData:(NSData *)data
{
    size_t count;
    NSString *peerID = [data rw_stringAtOffset:PACKET_HEADER_SIZE bytesRead:&count];
    return [[self class] packetWithPeerID:peerID];
}

- (void)addPayloadToData:(NSMutableData *)data
{
    [data rw_appendString:self.peerID];
}

@end
