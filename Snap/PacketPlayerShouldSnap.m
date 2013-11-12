//
//  PacketPlayerShouldSnap.m
//  Snap
//
//  Created by Kevin Casey on 8/23/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "PacketPlayerShouldSnap.h"
#import "NSData+SnapAdditions.h"

@implementation PacketPlayerShouldSnap

@synthesize peerID = _peerID;

+ (id)packetWithPeerID:(NSString *)peerID
{
    return [[[self class] alloc] initWithPeerID:peerID];
}

- (id) initWithPeerID:(NSString *)peerID
{
    self = [super initWithType:PacketTypePlayerShouldSnap];
    if (self) {
        self.peerID = peerID;
        self.sendReliably = NO;
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
