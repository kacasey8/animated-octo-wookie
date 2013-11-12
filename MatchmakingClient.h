//
//  MatchmakingClient.h
//  Snap
//
//  Created by Kevin Casey on 8/18/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

@class MatchmakingClient;

@protocol MatchmakingClientDelegate <NSObject>

- (void)matchmakingClient:(MatchmakingClient *)client serverBecameAvailable:(NSString *)peerID;
- (void)matchmakingClient:(MatchmakingClient *)client serverBecameUnavailable:(NSString *)peerID;
- (void)matchmakingClient:(MatchmakingClient *)client didDisconnectFromServer:(NSString *)peerID;
- (void)matchmakingClientNoNetwork:(MatchmakingClient *)client;
- (void)matchmakingClient:(MatchmakingClient *)client didConnectToServer:(NSString *)peerID;

@end

@interface MatchmakingClient : NSObject <GKSessionDelegate>

@property (nonatomic, strong, readonly) NSArray *availableServers;
@property (nonatomic, strong, readonly) GKSession *session;

@property (nonatomic, weak) id <MatchmakingClientDelegate> delegate;

- (void)startSearchingForServersWithSessionID:(NSString *)sessionID;
- (NSUInteger)availableServerCount;
- (NSString *)peerIDForAvailableServerAtIndex:(NSUInteger) index;
- (NSString *)displayNameForPeerID:(NSString *)peerID;

- (void)connectToServerWithPeerID:(NSString *)peerID;

- (void)disconnectFromServer;

@end
