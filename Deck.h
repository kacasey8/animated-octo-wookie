//
//  Deck.h
//  Snap
//
//  Created by Kevin Casey on 8/21/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

@class Card;

@interface Deck : NSObject

- (void)shuffle;
- (Card *)draw;
- (int)cardsRemaining;

@end
