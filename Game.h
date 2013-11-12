//
//  Game.h
//  Snap
//
//  Created by Kevin Casey on 8/19/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "Player.h"

@class Game;

@protocol GameDelegate <NSObject>

- (void)game:(Game *)game didQuitWithReason:(QuitReason)reason;
- (void)gameWaitingForServerReady:(Game *)game;
- (void)gameWaitingForClientsReady:(Game *)game;
- (void)gameDidBegin:(Game *)game;
- (void)game:(Game *)game playerDidDisconnect:(Player *)disconnectedPlayer redistributedCards:(NSDictionary *)redistributedCards;
- (void)gameShouldDealCards:(Game *)game startingWithPlayer:(Player *)startingPlayer;
- (void)game:(Game *)game didActivatePlayer:(Player *)player;
- (void)game:(Game *)game player:(Player *)player turnedOverCard:(Card *)card;
- (void)game:(Game *)game didRecycleCards:(NSArray *)recycledCards forPlayer:(Player *)player;
- (void)game:(Game *)game playerCalledSnapWithNoMatch:(Player *)player;
- (void)game:(Game *)game playerCalledSnapTooLate:(Player *)player;
- (void)game:(Game *)game player:(Player *)fromPlayer paysCard:(Card *)card toPlayer:(Player *)toPlayer;
- (void)game:(Game *)game player:(Player *)player calledSnapWithMatchingPlayers:(NSSet *)matchingPlayers;
- (void)game:(Game *)game roundDidEndWithWinner:(Player *)player;
- (void)gameDidBeginNewRound:(Game *)game;

@end

@interface Game : NSObject <GKSessionDelegate>

@property (nonatomic, weak) id <GameDelegate> delegate;
@property (nonatomic, assign) BOOL isServer;
@property (nonatomic, assign) CFTimeInterval ping;

- (void)startClientGameWithSession:(GKSession *)session playerName:(NSString *)name server:(NSString *)peerID;
- (void)quitGameWithReason:(QuitReason)reason;
- (void)startServerGameWithSession:(GKSession *)session playerName:(NSString *)name clients:(NSArray *)clients;

- (Player *)playerAtPosition:(PlayerPosition)position;

- (void)beginRound;

- (Player *)activePlayer;
- (void)turnCardForPlayerAtBottom;
- (void)resumeAfterRecyclingCardsForPlayer:(Player *)player;
- (void)playerCalledSnap:(Player *)player;
- (void)playerMustPayCards:(Player *)player;
- (BOOL)resumeAfterMovingCardsForPlayer:(Player *)player;
- (void)nextRound;
- (void)startSinglePlayerGame;

@end
