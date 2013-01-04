//
//  SFLegislator.m
//  Congress
//
//  Created by Daniel Cloud on 11/16/12.
//  Copyright (c) 2012 Sunlight Foundation. All rights reserved.
//

#import "SFLegislator.h"
#import <SSToolkit/NSDictionary+SSToolkitAdditions.h>

@implementation SFLegislator

@synthesize bioguide_id, govtrack_id;
@synthesize first_name, middle_name, last_name, name_suffix, nickname;
@synthesize title, party, state_abbr, state_name, district, chamber;
@synthesize gender, congress_office, website, phone, twitter_id, youtube_url;
@synthesize in_office;

+(id)initWithDictionary:(NSDictionary *)dictionary
{
    if (!dictionary) {
        return nil;
    }
    SFLegislator *_object = [[SFLegislator alloc] init];
    
    _object.bioguide_id = (NSString *)[dictionary safeObjectForKey:@"bioguide_id"];
    _object.govtrack_id = (NSString *)[dictionary safeObjectForKey:@"govtrack_id"];
    
    _object.first_name = (NSString *)[dictionary safeObjectForKey:@"first_name"];
    _object.middle_name = (NSString *)[dictionary safeObjectForKey:@"middle_name"];
    _object.last_name = (NSString *)[dictionary safeObjectForKey:@"last_name"];
    _object.name_suffix = (NSString *)[dictionary safeObjectForKey:@"name_suffix"];
    _object.nickname = (NSString *)[dictionary safeObjectForKey:@"nickname"];
    _object.gender = (NSString *)[dictionary safeObjectForKey:@"gender"];

    _object.title = [dictionary safeObjectForKey:@"title"];
    _object.party = [dictionary safeObjectForKey:@"party"];
    _object.state_abbr = [dictionary safeObjectForKey:@"state"];
    _object.state_name = [dictionary safeObjectForKey:@"state_name"];
    _object.district = [dictionary safeObjectForKey:@"district"];
    _object.chamber = [dictionary safeObjectForKey:@"chamber"];

    _object.phone = [dictionary safeObjectForKey:@"phone"];
    _object.congress_office = [dictionary safeObjectForKey:@"office"];
    _object.website = [dictionary safeObjectForKey:@"website"];
    
    return _object;
}

-(NSString *)name {
    NSString *fullName = [NSString stringWithFormat:@"%@ %@", self.first_name, self.last_name];
    if (self.name_suffix && ![self.name_suffix isEqualToString:@""]) {
        fullName = [fullName stringByAppendingFormat:@", %@", self.name_suffix];
    }
    return fullName;
}

-(NSString *)titled_name{
    NSString *name_str = [NSString stringWithFormat:@"%@. %@", self.title, self.name];
    return name_str;
    
}

-(NSString *)party_name
{
    if ([[self.party uppercaseString] isEqualToString:@"D"])
    {
        return @"Democrat";
    }
    else if ([[self.party uppercaseString] isEqualToString:@"R"])
    {
        return @"Republican";
    }
    else if ([[self.party uppercaseString] isEqualToString:@"I"])
    {
        return @"Independent";
    }

    return nil;
}

-(NSString *)full_title
{
    if ([self.title isEqualToString:@"Del"])
    {
        return @"Delegate";
    }
    else if ([self.title isEqualToString:@"Com"])
    {
        return @"Resident Commissioner";
    }
    else if ([self.title isEqualToString:@"Sen"])
    {
        return @"Senator";
    }
    else // "Rep"
    {
        return @"Representative";
    }
}

@end
