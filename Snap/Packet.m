//
//  Packet.m
//  Snap
//
//  Created by Kevin Casey on 8/19/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "Packet.h"
#import "PacketSignInResponse.h"
#import "PacketServerReady.h"
#import "NSData+SnapAdditions.h"
#import "PacketOtherClientQuit.h"
#import "PacketDealCards.h"
#import "Card.h"
#import "PacketActivePlayer.h"
#import "PacketPlayerShouldSnap.h"
#import "PacketPlayerCalledSnap.h"

const size_t PACKET_HEADER_SIZE = 10;

@implementation Packet

@synthesize packetType = _packetType;
@synthesize packetNumber = _packetNumber;
@synthesize sendReliably = _sendReliably;

+ (id)packetWithType:(PacketType)packetType
{
    return [[[self class] alloc] initWithType:packetType];
}

+ (id)packetWithData:(NSData *)data
{
    if ([data length] < PACKET_HEADER_SIZE) {
        NSLog(@"Error: Packet too small");
        return nil;
    }
    
    if ([data rw_int32AtOffset:0] != 'SNAP') {
        NSLog(@"Error: Packet has invalid header");
        return nil;
    }
    
    int packetNumber = [data rw_int32AtOffset:4];
    PacketType packetType = [data rw_int16AtOffset:8];
    
    Packet *packet;
    
    switch (packetType) {
        case PacketTypeSignInRequest:
        case PacketTypeClientReady:
        case PacketTypeClientDealtCards:
        case PacketTypeClientTurnedCard:
        case PacketTypeServerQuit:
        case PacketTypeClientQuit:
            packet = [Packet packetWithType:packetType];
            break;
            
        case PacketTypeSignInResponse:
            packet = [PacketSignInResponse packetWithData:data];
            break;
            
        case PacketTypeServerReady:
            packet = [PacketServerReady packetWithData:data];
            break;
        
        case PacketTypeOtherClientQuit:
            packet = [PacketOtherClientQuit packetWithData:data];
            break;
            
        case PacketTypeDealCards:
            packet = [PacketDealCards packetWithData:data];
            break;
            
        case PacketTypeActivatePlayer:
            packet = [PacketActivePlayer packetWithData:data];
            break;
            
        case PacketTypePlayerShouldSnap:
            packet = [PacketPlayerShouldSnap packetWithData:data];
            break;
            
        case PacketTypePlayerCalledSnap:
            packet = [PacketPlayerCalledSnap packetWithData:data];
            break;
            
        default:
            NSLog(@"Error: Packet has invalid type");
            break;
    }
    
    packet.packetNumber = packetNumber;
    return packet;
}

- (id)initWithType:(PacketType)packetType
{
    self = [super init];
    if (self) {
        self.packetNumber = -1;
        self.packetType = packetType;
        self.sendReliably = YES;
    }
    return self;
}

- (NSData *)data
{
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:100];
    
    [data rw_appendInt32:'SNAP']; // 0x534E4150
    [data rw_appendInt32:self.packetNumber];
    [data rw_appendInt16:self.packetType];
    
    [self addPayloadToData:data];
    
    return data;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ number %d, type=%d", [super description], self.packetNumber, self.packetType];
}

- (void)addPayloadToData:(NSMutableData *)data
{
    // base class does nothing
}

+ (NSDictionary *)cardsFromData:(NSData *)data atOffset:(size_t)offset
{
    size_t count;
    
    NSMutableDictionary *cards = [NSMutableDictionary dictionaryWithCapacity:4];
    
    while (offset < [data length]) {
        NSString *peerID = [data rw_stringAtOffset:offset bytesRead:&count];
        offset += count;
        
        int numberOfCards = [data rw_int8AtOffset:offset];
        offset += 1;
        
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:numberOfCards];
        
        for (int t = 0; t < numberOfCards; ++t) {
            int suit = [data rw_int8AtOffset:offset];
            offset += 1;
            
            int value = [data rw_int8AtOffset:offset];
            offset += 1;
            
            Card *card = [[Card alloc] initWithSuit:suit value:value];
            [array addObject:card];
        }
        
        [cards setObject:array forKey:peerID];
    }
    
    return cards;
}

- (void)addCards:(NSDictionary *)cards toPayload:(NSMutableData *)data
{
    [cards enumerateKeysAndObjectsUsingBlock:^(id key, NSArray *array, BOOL *stop) {
        [data rw_appendString:key];
        [data rw_appendInt8:[array count]];
        
        for (int t = 0; t < [array count]; ++t) {
            Card *card = [array objectAtIndex:t];
            [data rw_appendInt8:card.suit];
            [data rw_appendInt8:card.value];
        }
    }];
}

@end
