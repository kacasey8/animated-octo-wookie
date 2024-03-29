//
//  Game.m
//  Snap
//
//  Created by Kevin Casey on 8/19/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "Game.h"
#import "Packet.h"
#import "PacketSignInResponse.h"
#import "PacketServerReady.h"
#import "PacketOtherClientQuit.h"
#import "PacketDealCards.h"
#import "PacketActivePlayer.h"
#import "PacketPlayerShouldSnap.h"
#import "PacketPlayerCalledSnap.h"

#import "Card.h"
#import "Deck.h"

#import "Player.h"
#import "Stack.h"

#import <QuartzCore/QuartzCore.h>

typedef enum
{
    GameStateWaitingForSignIn,
    GameStateWaitingForReady,
    GameStateDealing,
    GameStatePlaying,
    GameStateGameOver,
    GameStateQuitting,
}
GameState;


@implementation Game
{
    GameState _state;
    
    GKSession *_session;
    NSString *_serverPeerID;
    NSString *_localPlayerName;
    NSMutableDictionary *_players;
    
    PlayerPosition _startingPlayerPosition;
    PlayerPosition _activePlayerPosition;
    BOOL _firstTime;
    BOOL _busyDealing;
    BOOL _hasTurnedCard;
    int _sendPacketNumber;
    BOOL _haveSnap;
    BOOL _mustPayCards;
    NSMutableSet *_matchingPlayers;
    CFTimeInterval start;
}

@synthesize delegate = _delegate;
@synthesize isServer = _isServer;
@synthesize ping = _ping;

- (id)init
{
    self = [super init];
    if (self) {
        _players = [NSMutableDictionary dictionaryWithCapacity:4];
        _matchingPlayers = [NSMutableSet setWithCapacity:4];
    }
    return self;
}

- (void)dealloc
{
    #ifdef DEBUG
    NSLog(@"dealloc %@", self);
    #endif
}

#pragma mark - GameLogic

- (void)startClientGameWithSession:(GKSession *)session playerName:(NSString *)name server:(NSString *)peerID
{
    self.isServer = NO;
    
    _session = session;
    _session.available = NO;
    _session.delegate = self;
    [_session setDataReceiveHandler:self withContext:nil];
    
    _serverPeerID = peerID;
    _localPlayerName = name;
    
    _state = GameStateWaitingForSignIn;
    
    [self.delegate gameWaitingForServerReady:self];
}

- (void)startServerGameWithSession:(GKSession *)session playerName:(NSString *)name clients:(NSArray *)clients
{
    self.isServer = YES;
    
    _session = session;
    _session.available = NO;
    _session.delegate = self;
    [_session setDataReceiveHandler:self withContext:nil];
    
    _state = GameStateWaitingForSignIn;
    
    [self.delegate gameWaitingForClientsReady:self];
    
    // Create the Player object for the server.
    Player *player = [[Player alloc] init];
    player.name = name;
    player.peerID = _session.peerID;
    player.position = PlayerPositionBottom;
    [_players setObject:player forKey:player.peerID];
    
    // Add a Player object for each client.
    int index = 0;
    for (NSString *peerID in clients)
    {
        Player *player = [[Player alloc] init];
        player.peerID = peerID;
        [_players setObject:player forKey:player.peerID];
        
        if (index == 0) 
            player.position = ([clients count] == 1 ? PlayerPositionTop : PlayerPositionLeft);
        else if (index == 1)
            player.position = PlayerPositionTop;
        else
            player.position = PlayerPositionRight;
        
        index++;
    }
    
    Packet *packet = [Packet packetWithType:PacketTypeSignInRequest];
    [self sendPacketToAllClients:packet];
}

- (void)beginRound
{
    if ([self isSinglePlayerGame])
        _state = GameStatePlaying;
    
    [_matchingPlayers removeAllObjects];
    _mustPayCards = NO;
    _haveSnap = NO;
    _busyDealing = NO;
    _hasTurnedCard = NO;
    [self activatePlayerAtPosition:_activePlayerPosition];
}

- (void)activatePlayerAtPosition:(PlayerPosition)playerPosition
{
    _hasTurnedCard = NO;
    
    if ([self isSinglePlayerGame]) {
        if (_activePlayerPosition != PlayerPositionBottom)
            [self scheduleTurningCardForComputerPlayer];
    } else if (self.isServer) {
        NSString *peerID = [self activePlayer].peerID;
        Packet *packet = [PacketActivePlayer packetWithPeerID:peerID];
        [self sendPacketToAllClients:packet];
    }
    
    [self.delegate game:self didActivatePlayer:[self activePlayer]];
}

- (void)scheduleTurningCardForComputerPlayer
{
    NSTimeInterval delay = 0.5f + RANDOM_FLOAT() * 2.0f;
    [self performSelector:@selector(turnCardForActivePlayer) withObject:nil afterDelay:delay];
}

- (void)quitGameWithReason:(QuitReason)reason
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    _state = GameStateQuitting;
    
    if (reason == QuitReasonUserQuit && ![self isSinglePlayerGame]) {
        if (self.isServer) {
            Packet *packet = [Packet packetWithType:PacketTypeServerQuit];
            [self sendPacketToAllClients:packet];
        } else {
            Packet *packet = [Packet packetWithType:PacketTypeClientQuit];
            [self sendPacketToAllClients:packet];
        }
    }
    
    [_session disconnectFromAllPeers];
    _session.delegate = nil;
    _session = nil;
    
    [self.delegate game:self didQuitWithReason:reason];
}

- (void)turnCardForPlayerAtBottom
{
    if (_state == GameStatePlaying
                && _activePlayerPosition == PlayerPositionBottom
                && [[self activePlayer].closedCards cardCount] > 0
                && !_busyDealing
                && !_hasTurnedCard)
    {
        [self turnCardForActivePlayer];
        
        if (!self.isServer) {
            Packet *packet = [Packet packetWithType:PacketTypeClientTurnedCard];
            [self sendPacketToServer:packet];
        }
    }
}

- (void)turnCardForPlayer:(Player *)player
{
    _haveSnap = NO;
    NSAssert([player.closedCards cardCount] > 0, @"Player has no more cards");
    
    _hasTurnedCard = YES;
    
    Card *card = [player turnOverTopCard];
    [self.delegate game:self player:player turnedOverCard:card];
    
    [self checkMatch];
}

- (void)turnCardForActivePlayer
{
    if ([self isSinglePlayerGame]) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(playerCalledSnap:) object:[self playerAtPosition:PlayerPositionLeft]];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(playerCalledSnap:) object:[self playerAtPosition:PlayerPositionTop]];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(playerCalledSnap:) object:[self playerAtPosition:PlayerPositionRight]];
    }
    
    [self turnCardForPlayer:[self activePlayer]];
    
    if ([self isSinglePlayerGame]) {
        if ([_matchingPlayers count] > 0 || RANDOM_INT(50) == 0) {
            for (PlayerPosition p = PlayerPositionLeft; p <= PlayerPositionRight; ++p) {
                Player *computerPlayer = [self playerAtPosition:p];
                if ([computerPlayer totalCardCount] > 0) {
                    NSTimeInterval delay = 0.5f + RANDOM_FLOAT()*2.0f;
                    [self performSelector:@selector(playerCalledSnap:) withObject:computerPlayer afterDelay:delay];
                }
            }
        }
    }
    
    if (self.isServer) {
        [self performSelector:@selector(activateNextPlayer) withObject:nil afterDelay:0.5f];
    }
}

- (void)activateNextPlayer
{
    NSAssert(self.isServer, @"Must be server");
    
    while (true) {
        _activePlayerPosition++;
        if (_activePlayerPosition > PlayerPositionRight) {
            _activePlayerPosition = PlayerPositionBottom;
        }
        Player *nextPlayer = [self activePlayer];
        if (nextPlayer != nil) {
            if ([nextPlayer.closedCards cardCount] > 0) {
                [self activatePlayerAtPosition:_activePlayerPosition];
                return;
            }
            
            if ([nextPlayer shouldRecycle]) {
                [self activatePlayerAtPosition:_activePlayerPosition];
                [self recycleCardsForActivePlayer];
                return;
            }
        }
    }
}

- (void)recycleCardsForActivePlayer
{
    Player *player = [self activePlayer];
    
    NSArray *recycledCards = [player recycleCards];
    NSAssert([recycledCards count] > 0, @"Should have cards to recycle");
    
    [self checkMatch];
    
    [self.delegate game:self didRecycleCards:recycledCards forPlayer:player];
}

- (void)resumeAfterRecyclingCardsForPlayer:(Player *)player
{
    if (_mustPayCards) {
        for (PlayerPosition p = player.position; p < player.position + 4; ++p) {
            Player *otherPlayer = [self playerAtPosition:p % 4];
            if (otherPlayer != nil && otherPlayer != player && [otherPlayer totalCardCount] > 0) {
                Card *card = [player giveTopmostClosedCardToPlayer:otherPlayer];
                if (card != nil) {
                    [self.delegate game:self player:player paysCard:card toPlayer:otherPlayer];
                }
            }
        }
    }
}

#pragma mark - Networking

- (void)sendPacketToAllClients:(Packet *)packet
{
    if ([self isSinglePlayerGame])
        return;
    
    if (packet.packetNumber != -1) {
        packet.packetNumber = _sendPacketNumber;
        _sendPacketNumber++;
    }
    
    [_players enumerateKeysAndObjectsUsingBlock:^(id key, Player *obj, BOOL *stop)
     {
         obj.receivedResponse = [_session.peerID isEqualToString:obj.peerID];
     }];
    
    GKSendDataMode dataMode = packet.sendReliably ? GKSendDataReliable : GKSendDataUnreliable;
    NSData *data = [packet data];
    NSError *error;
    if (![_session sendDataToAllPeers:data withDataMode:dataMode error:&error]) {
        NSLog(@"Error sending data to clients %@", error);
    }
}

- (void)sendPacketToServer:(Packet *)packet
{
    NSAssert(![self isSinglePlayerGame], @"Should not send packets in single player mode");
    
    if (packet.packetNumber != -1) {
        packet.packetNumber = _sendPacketNumber;
        _sendPacketNumber++;
    }
    
    GKSendDataMode dataMode = GKSendDataReliable;
    NSData *data = [packet data];
    NSError *error;
    if (![_session sendData:data toPeers:[NSArray arrayWithObject:_serverPeerID] withDataMode:dataMode error:&error]) {
        NSLog(@"Error sending data to server: %@", error);
    }
}

- (void)clientReceivedPacket:(Packet *)packet
{
    switch (packet.packetType) {
        case PacketTypeSignInRequest:
            if (_state == GameStateWaitingForSignIn) {
                _state = GameStateWaitingForReady;
                
                Packet *packet = [PacketSignInResponse packetWithPlayerName:_localPlayerName];
                [self sendPacketToServer:packet];
                
                start = CACurrentMediaTime();
            }
            break;
            
        case PacketTypeServerReady:
            if (_state == GameStateWaitingForReady) {
                _players = ((PacketServerReady *)packet).players;
                [self changeRelativePositionsOfPlayers];
                
                Packet *packet = [Packet packetWithType:PacketTypeClientReady];
                [self sendPacketToServer:packet];
                
                [self beginGame];
                
                _ping = CACurrentMediaTime() - start;
                
            }
            break;
            
        case PacketTypeOtherClientQuit:
            if (_state != GameStateQuitting) {
                PacketOtherClientQuit *quitPacket = ((PacketOtherClientQuit *) packet);
                [self clientDidDisconnect:quitPacket.peerID redistributedCards:quitPacket.cards];
            }
            break;
            
        case PacketTypeServerQuit:
            [self quitGameWithReason:QuitReasonServerQuit];
            break;
            
        case PacketTypeDealCards:
            if (_state == GameStateGameOver) {
                [self nextRound];
            }
            if (_state == GameStateDealing) {
                [self handleDealCardsPacket:(PacketDealCards *)packet];
            }
            break;
            
        case PacketTypeActivatePlayer:
            if (_state == GameStatePlaying) {
                [self handleActivatePlayerPacket:(PacketActivePlayer *)packet];
            }
            break;
            
        case PacketTypePlayerCalledSnap:
            if (_state == GameStatePlaying) {
                [self handlePlayerCalledSnapPacket:(PacketPlayerCalledSnap *)packet];
            }
            break;
            
        default:
            NSLog(@"Client received unexpected packet: %@", packet);
            break;
    }
}

- (void)handleDealCardsPacket:(PacketDealCards *)packet
{
    [packet.cards enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        Player *player = [self playerWithPeerID:key];
        [player.closedCards addCardsFromArray:obj];
    }];
    
    Player *startingPlayer = [self playerWithPeerID:packet.startingPeerID];
    _activePlayerPosition = startingPlayer.position;
    
    Packet *responsePacket = [Packet packetWithType:PacketTypeClientDealtCards];
    [self sendPacketToServer:responsePacket];
    
    _state = GameStatePlaying;
    
    [self.delegate gameShouldDealCards:self startingWithPlayer:startingPlayer];
}

- (void)handleActivatePlayerPacket:(PacketActivePlayer *)packet
{
	if (_firstTime)
	{
		_firstTime = NO;
		return;
	}
    
	NSString *peerID = packet.peerID;
    
	Player* newPlayer = [self playerWithPeerID:peerID];
	if (newPlayer == nil)
		return;
    
	PlayerPosition minPosition = _activePlayerPosition;
	if (minPosition == PlayerPositionBottom)
		minPosition = PlayerPositionLeft;
    
	PlayerPosition maxPosition = newPlayer.position;
	if (maxPosition < minPosition)
		maxPosition = PlayerPositionRight + 1;
    
	// Special situation for when there is only one player (that is not the
	// local user) who has more than one card.
	if (_activePlayerPosition == newPlayer.position && _activePlayerPosition != PlayerPositionBottom)
		maxPosition = minPosition + 1;
    
	for (PlayerPosition p = minPosition; p < maxPosition; ++p)
	{
		Player *player = [self playerAtPosition:p];
        
		// Skip players that have no cards or only one open card.
		if (player != nil && [player.closedCards cardCount] > 0)
		{
			[self turnCardForPlayer:player];
		}
	}
    
	[self performSelector:@selector(activatePlayerWithPeerID:) withObject:peerID afterDelay:0.5f];
}

- (void)handlePlayerCalledSnapPacket:(PacketPlayerCalledSnap *)packet
{
    NSString *peerID = packet.peerID;
    SnapType snapType = packet.snapType;
    
    Player *player = [self playerWithPeerID:peerID];
    if (player != nil) {
        if (snapType == SnapTypeTooLate) {
            [self.delegate game:self playerCalledSnapTooLate:player];
        } else if (snapType == SnapTypeWrong ) {
            [self.delegate game:self playerCalledSnapWithNoMatch:player];
        } else {
            NSMutableSet *matchingPlayers = [NSMutableSet setWithCapacity:4];
            [packet.matchingPeerIDs enumerateObjectsUsingBlock:^(NSString *obj, BOOL *stop) {
                Player *player = [self playerWithPeerID:obj];
                if (player != nil) {
                    [matchingPlayers addObject:player];
                }
            }];
            
            [self.delegate game:self player:player calledSnapWithMatchingPlayers:matchingPlayers];
        }
    }
}

- (void)activatePlayerWithPeerID:(NSString *)peerID
{
    NSAssert(!self.isServer, @"Must be client");
    
    Player *player = [self playerWithPeerID:peerID];
    _activePlayerPosition = player.position;
    [self activatePlayerAtPosition:player.position];
    
    if ([player shouldRecycle]) {
        [self recycleCardsForActivePlayer];
    }
}

- (void)serverReceivedPacket:(Packet *)packet fromPlayer:(Player *)player
{
    switch (packet.packetType) {
        case PacketTypeSignInResponse:
            if (_state == GameStateWaitingForSignIn) {
                player.name = ((PacketSignInResponse *)packet).playerName;
                if ([self receivedResponsesFromAllPlayers]) {
                    _state = GameStateWaitingForReady;
                    
                    Packet *packet = [PacketServerReady packetWithPlayers:_players];
                    [self sendPacketToAllClients:packet];
                    
                    start = CACurrentMediaTime();
                }
            }
            break;
            
        case PacketTypeClientReady:
            if (_state == GameStateWaitingForReady && [self receivedResponsesFromAllPlayers]) {
                [self beginGame];
                _ping = CACurrentMediaTime() - start;
            }
            break;
            
        case PacketTypeClientQuit:
            [self clientDidDisconnect:player.peerID redistributedCards:nil];
            break;
        
        case PacketTypeClientDealtCards:
            if (_state == GameStateDealing && [self receivedResponsesFromAllPlayers]) {
                _state = GameStatePlaying;
            }
            break;
            
        case PacketTypeClientTurnedCard:
            if (_state == GameStatePlaying && player == [self activePlayer]) {
                [self turnCardForActivePlayer];
            }
            break;
            
        case PacketTypePlayerShouldSnap:
            if (_state == GameStatePlaying) {
                NSString *peerID = ((PacketPlayerShouldSnap *) packet).peerID;
                Player *player = [self playerWithPeerID:peerID];
                if (player != nil) 
                    [self playerCalledSnap:player];
            }
            break;
            
        default:
            NSLog(@"Server received unexpected packet: %@", packet);
            break;
    }
}

- (BOOL)receivedResponsesFromAllPlayers
{
    for (NSString *peerID in _players)
    {
        Player *player = [self playerWithPeerID:peerID];
        if (!player.receivedResponse) {
            return NO;
        }
    }
    return YES;
}

- (void)beginGame
{
    _firstTime = YES;
    _state = GameStateDealing;
    _busyDealing = YES;
    [self.delegate gameDidBegin:self];
    
    if (self.isServer) {
        [self pickRandomStartingPlayer];
        [self dealCards];
    }
}

- (void)pickRandomStartingPlayer
{
    do
    {
        _startingPlayerPosition = arc4random() % 4;
    }
    while ([self playerAtPosition:_startingPlayerPosition] == nil);
    
    _activePlayerPosition = _startingPlayerPosition;
}

- (void)dealCards
{
    NSAssert(self.isServer, @"Must be server");
    NSAssert(_state == GameStateDealing, @"Wrong state");
    
    Deck *deck = [[Deck alloc] init];
    [deck shuffle];
    
    while ([deck cardsRemaining] > 0) {
        for (PlayerPosition p = _startingPlayerPosition; p < _startingPlayerPosition + 4; ++p) {
            Player *player = [self playerAtPosition:(p % 4)];
            if (player != nil && [deck cardsRemaining] > 0) {
                Card *card = [deck draw];
                [player.closedCards addCardToTop:card];
            }
        }
    }
    
    Player *startingPlayer = [self activePlayer];
    
    NSMutableDictionary *playerCards = [NSMutableDictionary dictionaryWithCapacity:4];
    [_players enumerateKeysAndObjectsUsingBlock:^(id key, Player *obj, BOOL *stop) {
        NSArray *array = [obj.closedCards array];
        [playerCards setObject:array forKey:obj.peerID];
    }];
    
    PacketDealCards *packet = [PacketDealCards packetWithCards:playerCards startingWithPlayerPeerID:startingPlayer.peerID];
    [self sendPacketToAllClients:packet];
    
    [self.delegate gameShouldDealCards:self startingWithPlayer:startingPlayer];
}

- (void)changeRelativePositionsOfPlayers
{
    NSAssert(!self.isServer, @"Must be client");
    
    Player *myPlayer = [self playerWithPeerID:_session.peerID];
    int diff = myPlayer.position;
    myPlayer.position = PlayerPositionBottom;
    
    [_players enumerateKeysAndObjectsUsingBlock:^(id key, Player *obj, BOOL *stop) {
        if (obj != myPlayer) {
            obj.position = (obj.position - diff) % 4;
        }
    }];
    
}

- (Player *)activePlayer
{
    return [self playerAtPosition:_activePlayerPosition];
}

#pragma mark - GKSessionDelegate

- (void)session:(GKSession *)session peer:(NSString *)peerID didChangeState:(GKPeerConnectionState)state
{
#ifdef DEBUG
    NSLog(@"Game: peer %@ changed state %d", peerID, state);
#endif
    
    if (state == GKPeerStateDisconnected) {
        if (self.isServer) {
            [self clientDidDisconnect:peerID redistributedCards:nil];
        }
        else if ([peerID isEqualToString:_serverPeerID]) {
            [self quitGameWithReason:QuitReasonConnectionDropped];
        }
    }
}

- (void)session:(GKSession *)session didReceiveConnectionRequestFromPeer:(NSString *)peerID
{
    #ifdef DEBUG
    NSLog(@"Game: connection request from peer %@", peerID);
    #endif
}

- (void)session:(GKSession *)session connectionWithPeerFailed:(NSString *)peerID withError:(NSError *)error
{
    #ifdef DEBUG
    NSLog(@"Game: connection with peer %@ failed %@", peerID, error);
    #endif
}

- (void)session:(GKSession *)session didFailWithError:(NSError *)error
{
    #ifdef DEBUG
    NSLog(@"Game: session failed %@", error);
    #endif
    
    if ([[error domain] isEqualToString:GKSessionErrorDomain]) {
        if (_state != GameStateQuitting) {
            [self quitGameWithReason:QuitReasonConnectionDropped];
        }
    }
}


#pragma mark - GKSession Data Receive Handler

- (void)receiveData:(NSData *)data fromPeer:(NSString *)peerID inSession:(GKSession *)session context:(void *)context
{
    #ifdef DEBUG
    NSLog(@"Game: recieve data from peer: %@, data: %@, length %d", peerID, data, [data length]);
    #endif
    
    Packet *packet = [Packet packetWithData:data];
    if (packet == nil) {
        NSLog(@"Invalid packet: %@", data);
        return;
    }
    
    Player *player = [self playerWithPeerID:peerID];
    
    if (player != nil) {
        if (packet.packetNumber != -1 && packet.packetNumber < player.lastPacketNumberReceived) {
            NSLog(@"Out-of-order packet!");
            return;
        }
        
        player.lastPacketNumberReceived = packet.packetNumber;
        player.receivedResponse = YES;
    }
    
    if (self.isServer)
        [self serverReceivedPacket:packet fromPlayer:player];
    else
        [self clientReceivedPacket:packet];
}

- (Player *)playerWithPeerID:(NSString *)peerID
{
    return [_players objectForKey:peerID];
}

- (Player *)playerAtPosition:(PlayerPosition)position
{
    NSAssert(position >= PlayerPositionBottom && position <= PlayerPositionRight, @"Invalid player position");
    
    __block Player *player;
    [_players enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        player = obj;
        if (player.position == position)
            *stop = YES;
        else
            player = nil;
    }];
    
    return player;
}

- (void)clientDidDisconnect:(NSString *)peerID redistributedCards:(NSDictionary *)redistributedCards
{
    if (_state != GameStateQuitting) {
        Player *player = [self playerWithPeerID:peerID];
        if (player != nil) {
            [_players removeObjectForKey:peerID];
            
            if (_state != GameStateWaitingForSignIn) {
                // Tell the other clients that this one is now disconnected.
                // Give the cards of the disconnected player to the others.
                if (self.isServer) {
                    redistributedCards = [self redistributeCardsOfDisconnectedPlayer:player];
                    PacketOtherClientQuit *packet = [PacketOtherClientQuit packetWithPeerID:peerID cards:redistributedCards];
                    [self sendPacketToAllClients:packet];
                }
                
                // Add the new cards to the bottom of the closed piles.
                [redistributedCards enumerateKeysAndObjectsUsingBlock:^(id key, NSArray *array, BOOL *stop) {
                    Player *player = [self playerWithPeerID:key];
                    if (player != nil) {
                        [array enumerateObjectsUsingBlock:^(Card *card, NSUInteger idx, BOOL *stop) {
                            card.isTurnedOver = NO;
                            [player.closedCards addCardToBottom:card];
                        }];
                    }
                }];
                
                [self.delegate game:self playerDidDisconnect:player redistributedCards:redistributedCards];
                
                if (self.isServer && player.position == _activePlayerPosition) 
                    [self activateNextPlayer];
            }
        }
    }
}

- (NSDictionary *) redistributeCardsOfDisconnectedPlayer:(Player *)disconnectedPlayer
{
    NSMutableDictionary *playerCards = [NSMutableDictionary dictionaryWithCapacity:4];
    
    [_players enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (obj != disconnectedPlayer && [obj totalCardCount] > 0) {
            NSMutableArray *array = [NSMutableArray arrayWithCapacity:26];
            [playerCards setObject:array forKey:key];
        }
    }];
    
    NSMutableArray *oldCards = [NSMutableArray arrayWithCapacity:52];
    [oldCards addObjectsFromArray:[disconnectedPlayer.closedCards array]];
    [oldCards addObjectsFromArray:[disconnectedPlayer.openCards array]];
    
    while ([oldCards count] > 0) {
        [playerCards enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if ([oldCards count] > 0) {
                [obj addObject:[oldCards lastObject]];
                [oldCards removeLastObject];
            } else {
                *stop = YES;
            }
        }];
    }
    
    return playerCards;
}

- (void)playerCalledSnap:(Player *)player
{
    if (self.isServer) {
        if (_haveSnap) {
            Packet *packet = [PacketPlayerCalledSnap packetWithPeerID:player.peerID snapType:SnapTypeTooLate matchingPeerIDs:nil];
            [self sendPacketToAllClients:packet];
            [self.delegate game:self playerCalledSnapTooLate:player];
        } else {
            
            if ([self isSinglePlayerGame]) {
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(turnCardForActivePlayer) object:nil];
            }
            
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activateNextPlayer) object:nil];
            _haveSnap = YES;
            
            if ([_matchingPlayers count] == 0) {
                Packet *packet = [PacketPlayerCalledSnap packetWithPeerID:player.peerID snapType:SnapTypeWrong matchingPeerIDs:nil];
                [self sendPacketToAllClients:packet];
                [self.delegate game:self playerCalledSnapWithNoMatch:player];
            } else {
                NSMutableSet *matchingPeerIDs = [NSMutableSet setWithCapacity:4];
                [_matchingPlayers enumerateObjectsUsingBlock:^(Player *obj, BOOL *stop) {
                    [matchingPeerIDs addObject:obj.peerID];
                }];
                
                Packet *packet = [PacketPlayerCalledSnap packetWithPeerID:player.peerID snapType:SnapTypeCorrect matchingPeerIDs:matchingPeerIDs];
                [self sendPacketToAllClients:packet];
                [self.delegate game:self player:player calledSnapWithMatchingPlayers:_matchingPlayers];
            }
            
        }
    } else {
        Packet *packet = [PacketPlayerShouldSnap packetWithPeerID:_session.peerID];
        [self sendPacketToServer:packet];
    }
}

- (void)playerMustPayCards:(Player *)player
{
    _mustPayCards = YES;
    
    int cardsNeeded = 0;
    for (PlayerPosition p = player.position; p < player.position + 4; ++p) {
        Player *otherPlayer = [self playerAtPosition:p % 4];
        if (otherPlayer != nil && otherPlayer != player && [otherPlayer totalCardCount] > 0) 
            ++cardsNeeded;
    }
    
    if (cardsNeeded > [player.closedCards cardCount]) {
        NSArray *recycledCards = [player recycleCards];
        if ([recycledCards count] > 0) {
            [self.delegate game:self didRecycleCards:recycledCards forPlayer:player];
            return;
        }
    }
    
    [self resumeAfterRecyclingCardsForPlayer:player];
}

- (BOOL)resumeAfterMovingCardsForPlayer:(Player *)player
{
    _mustPayCards = NO;
    
    Player *winner = [self checkWinner];
    if (winner != nil) {
        [self endRoundWithWinner:winner];
        return YES;
    }
    
    if ([[self activePlayer] totalCardCount] == 0
        || _hasTurnedCard
        || ([[self activePlayer].closedCards cardCount] == 0 && [[self activePlayer].openCards cardCount] == 1))
    {
        if (self.isServer)
            [self activateNextPlayer];
        
        return YES;
    } else if ([[self activePlayer] shouldRecycle]) {
        [self recycleCardsForActivePlayer];
        return NO;
    } else if ([self isSinglePlayerGame] && _activePlayerPosition !=  PlayerPositionBottom) {
        [self scheduleTurningCardForComputerPlayer];
        return NO;
    }
    
    return NO;
}

- (void)checkMatch
{
    [_matchingPlayers removeAllObjects];
    
    for (PlayerPosition p = PlayerPositionBottom; p <= PlayerPositionRight; ++p) {
        Player *player1 = [self playerAtPosition:p];
        if (player1 != nil) {
            for (PlayerPosition q = PlayerPositionBottom; q <= PlayerPositionRight; ++q) {
                Player *player2 = [self playerAtPosition:q];
                if (p != q && player2 != nil) {
                    Card *card1 = [player1.openCards topmostCard];
                    Card *card2 = [player2.openCards topmostCard];
                    if (card1 != nil && card2 != nil && [card1 matchesCard:card2]) {
                        [_matchingPlayers addObject:player1];
                        break;
                    }
                }
            }
        }
    }
    
#ifdef DEBUG
    NSLog(@"Matching players: %@", _matchingPlayers);
#endif
}

- (Player *)checkWinner
{
    __block Player *winner;
    
    [_players enumerateKeysAndObjectsUsingBlock:^(id key, Player *obj, BOOL *stop) {
        if ([obj totalCardCount] == 52) {
            winner = obj;
            *stop = YES;
        }
    }];
    
    return winner;
}

- (void)endRoundWithWinner:(Player *)winner
{
#ifdef DEBUG
    NSLog(@"End of round, winner is %@", winner);
#endif
    
    _state = GameStateGameOver;
    
    winner.gamesWon++;
    [self.delegate game:self roundDidEndWithWinner:winner];
}

- (void)nextRound
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    _state = GameStateDealing;
    _firstTime = YES;
    _busyDealing = YES;
    
    [self.delegate gameDidBeginNewRound:self];
    
    [_players enumerateKeysAndObjectsUsingBlock:^(id key, Player *player, BOOL *stop) {
        [player.closedCards removeAllCards];
        [player.openCards removeAllCards];
    }];
    
    if (self.isServer) {
        [self pickNextStartingPlayer];
        [self dealCards];
    }
}

- (void)pickNextStartingPlayer
{
    do {
        _startingPlayerPosition++;
        if (_startingPlayerPosition > PlayerPositionRight) {
            _startingPlayerPosition = PlayerPositionBottom;
        }
    } while ([self playerAtPosition:_startingPlayerPosition] == nil);
    
    _activePlayerPosition = _startingPlayerPosition;
}

- (void)startSinglePlayerGame
{
    self.isServer = YES;
    
    Player *player = [[Player alloc] init];
    player.name = NSLocalizedString(@"You", @"Single player mode, name of user (bottom player)");
    player.peerID = @"1";
    player.position = PlayerPositionBottom;
    [_players setObject:player forKey:player.peerID];
    
    player = [[Player alloc] init];
    player.name = NSLocalizedString(@"Ray", @"Single player mode, name of left player");
    player.peerID = @"2";
    player.position = PlayerPositionLeft;
    [_players setObject:player forKey:player.peerID];
    
    player = [[Player alloc] init];
    player.name = NSLocalizedString(@"Lucy", @"Single player mode, name of top player");
    player.peerID = @"3";
    player.position = PlayerPositionTop;
    [_players setObject:player forKey:player.peerID];
    
    player = [[Player alloc] init];
    player.name = NSLocalizedString(@"Steve", @"Single player mode, name of right player");
    player.peerID = @"4";
    player.position = PlayerPositionRight;
    [_players setObject:player forKey:player.peerID];
    
    [self beginGame];
}

- (BOOL)isSinglePlayerGame
{
    return (_session == nil);
}

@end
