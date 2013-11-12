//
//  Stack.m
//  Snap
//
//  Created by Kevin Casey on 8/21/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "Stack.h"
#import "Card.h"

@implementation Stack
{
    NSMutableArray *_cards;
}

- (id)init
{
    self = [super init];
    if (self) {
        _cards = [NSMutableArray arrayWithCapacity:26];
    }
    return self;
}

- (void)addCardToTop:(Card *)card
{
    NSAssert(card != nil, @"Card cannot be nil");
    NSAssert([_cards indexOfObject:card] == NSNotFound, @"Already have this Card");
    [_cards addObject:card];
}

- (NSUInteger)cardCount
{
    return [_cards count];
}

- (NSArray *)array
{
    return [_cards copy];
}

- (Card *)cardAtIndex:(NSUInteger)index
{
    return [_cards objectAtIndex:index];
}

- (void)addCardsFromArray:(NSArray *)array
{
    _cards = [array mutableCopy];
}

- (Card *)topmostCard
{
    return [_cards lastObject];
}

- (void)removeTopmostCard
{
    [_cards removeLastObject];
}

- (void)addCardToBottom:(Card *)card
{
    NSAssert(card != nil, @"Card cannot be nil");
    NSAssert([_cards indexOfObject:card] == NSNotFound, @"Already have this card");
    [_cards insertObject:card atIndex:0];
}

- (void)removeAllCards
{
    [_cards removeAllObjects];
}
@end
