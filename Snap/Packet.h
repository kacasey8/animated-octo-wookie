//
//  Packet.h
//  Snap
//
//  Created by Kevin Casey on 8/19/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

const size_t PACKET_HEADER_SIZE;

typedef enum
{
    PacketTypeSignInRequest = 0x64,     // server to client
    PacketTypeSignInResponse,           // client to server
    
    PacketTypeServerReady,              // server to client
    PacketTypeClientReady,              // client to server
    
    PacketTypeDealCards,                // server to client
    PacketTypeClientDealtCards,         // client to server
    
    PacketTypeActivatePlayer,           // server to client
    PacketTypeClientTurnedCard,         // client to server
    
    PacketTypePlayerShouldSnap,         // client to server
    PacketTypePlayerCalledSnap,         // server to client
    
    PacketTypeOtherClientQuit,          // server to client
    PacketTypeServerQuit,               // server to client
    PacketTypeClientQuit,               // client to server
}
PacketType;
@interface Packet : NSObject

@property (nonatomic, assign) PacketType packetType;
@property (nonatomic, assign) int packetNumber;
@property (nonatomic, assign) BOOL sendReliably;

+ (id)packetWithType:(PacketType)packetType;
+ (id)packetWithData:(NSData *)data;
- (id)initWithType:(PacketType)packetType;

- (NSData *)data;

- (void)addPayloadToData:(NSMutableData *)data;
+ (NSDictionary *)cardsFromData:(NSData *)data atOffset:(size_t)offset;
- (void)addCards:(NSDictionary *)cards toPayload:(NSMutableData *)data;

@end
