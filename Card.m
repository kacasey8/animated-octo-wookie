//
//  Card.m
//  Snap
//
//  Created by Kevin Casey on 8/21/13.
//  Copyright (c) 2013 Hollance. All rights reserved.
//

#import "Card.h"

@implementation Card

@synthesize suit = _suit;
@synthesize value = _value;
@synthesize isTurnedOver = _isTurnedOver;

- (id)initWithSuit:(Suit)suit value:(int)value
{
    NSAssert(value >= CardAce && value <= CardKing, @"Invalid card value");
    self = [super init];
    if (self) {
        _suit = suit;
        _value = value;
    }
    
    return self;
}

- (BOOL)isEqualToCard:(Card *)otherCard
{
    return (otherCard.suit == self.suit && otherCard.value == self.value);
}

- (BOOL)matchesCard:(Card *)otherCard
{
    NSParameterAssert(otherCard != nil);
    return self.value == otherCard.value;
}

@end
