//
//  Player.h
//  Snap
//
//  Created by Kevin Casey on 8/19/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

@class Card;
@class Stack;

typedef enum
{
    PlayerPositionBottom, // the user
    PlayerPositionLeft,
    PlayerPositionTop,
    PlayerPositionRight
}
PlayerPosition;

@interface Player : NSObject

@property (nonatomic, assign) PlayerPosition position;
@property (nonatomic, copy) NSString* name;
@property (nonatomic, copy) NSString* peerID;
@property (nonatomic, assign) BOOL receivedResponse;
@property (nonatomic, assign) int gamesWon;

@property (nonatomic, strong, readonly) Stack *closedCards;
@property (nonatomic, strong, readonly) Stack *openCards;

@property (nonatomic, assign) int lastPacketNumberReceived;

- (Card *)turnOverTopCard;
- (BOOL)shouldRecycle;

- (NSArray *)recycleCards;
- (int)totalCardCount;
- (Card *)giveTopmostClosedCardToPlayer:(Player *)otherPlayer;
- (NSArray *)giveAllOpenCardsToPlayer:(Player *)otherPlayer;

@end
