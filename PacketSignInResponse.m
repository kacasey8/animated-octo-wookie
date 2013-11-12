//
//  PacketSignInResponse.m
//  Snap
//
//  Created by Kevin Casey on 8/20/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "PacketSignInResponse.h"
#import "NSData+SnapAdditions.h"

@implementation PacketSignInResponse

@synthesize playerName = _playerName;

+ (id)packetWithPlayerName:(NSString *)playerName
{
    return [[[self class] alloc] initWithPlayerName:playerName];
}

+ (id)packetWithData:(NSData *)data
{
    size_t count;
    NSString *playerName = [data rw_stringAtOffset:PACKET_HEADER_SIZE bytesRead:&count];
    return [[self class] packetWithPlayerName:playerName];
}

- (id)initWithPlayerName:(NSString *)playerName
{
    self = [super initWithType:PacketTypeSignInResponse];
    if (self) {
        self.playerName = playerName;
    }
    return self;
}

- (void)addPayloadToData:(NSMutableData *)data
{
    [data rw_appendString:self.playerName];
}


@end
