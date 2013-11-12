//
//  GameViewController.h
//  Snap
//
//  Created by Kevin Casey on 8/19/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "Game.h"

@class GameViewController;

@protocol GameViewControllerDelegate <NSObject>

- (void)gameViewController:(GameViewController *)controller didQuitWithReason:(QuitReason)reason;

@end

@interface GameViewController : UIViewController <UIAlertViewDelegate, GameDelegate>

@property (nonatomic, weak) id <GameViewControllerDelegate> delegate;
@property (nonatomic, strong) Game *game;

- (void)game:(Game *)game playerCalledSnapWithNoMatch:(Player *)player;

@end
