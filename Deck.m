//
//  Deck.m
//  Snap
//
//  Created by Kevin Casey on 8/21/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "Deck.h"
#import "Card.h"

@implementation Deck
{
    NSMutableArray *_cards;
}

- (void)setUpCards
{
    for (Suit suit = SuitClubs; suit <= SuitSpades; ++suit) {
        for (int value = CardAce; value <= CardKing; ++value) {
            Card *card = [[Card alloc] initWithSuit:suit value:value];
            [_cards addObject:card];
        }
    }
}

- (id)init
{
    self = [super init];
    if (self) {
        _cards = [NSMutableArray arrayWithCapacity:52];
        [self setUpCards];
    }
    return self;
}

- (int)cardsRemaining
{
    return [_cards count];
}

- (void)shuffle
{
    NSUInteger count = [_cards count];
    NSMutableArray *shuffled = [NSMutableArray arrayWithCapacity:count];
    
    for (int t = 0; t < count; ++t) {
        int i = arc4random() % [self cardsRemaining];
        Card *card = [_cards objectAtIndex:i];
        [shuffled addObject:card];
        [_cards removeObjectAtIndex:i];
    }
    
    NSAssert([self cardsRemaining] == 0, @"Original deck should now be empty");
    
    _cards = shuffled;
}

- (Card *)draw
{
    NSAssert([self cardsRemaining] > 0, @"No more cards in the deck");
    Card *card = [_cards lastObject];
    [_cards removeLastObject];
    return card;
}
@end
