//
//  SFCongressAppStyle.h
//  Congress
//
//  Created by Daniel Cloud on 3/6/13.
//  Copyright (c) 2013 Sunlight Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UIBarButtonItem+SFCongressAppStyle.h"
#import "UIImage+SFCongressAppStyle.h"

@interface UIColor (SFCongressAppStyle)

+ (UIColor *)primaryBackgroundColor;
+ (UIColor *)secondaryBackgroundColor;
+ (UIColor *)selectedCellBackgroundColor;
+ (UIColor *)menuBackgroundColor;
+ (UIColor *)menuSelectionBackgroundColor;
+ (UIColor *)menuTextColor;
+ (UIColor *)primaryTextColor;
+ (UIColor *)secondaryTextColor;
+ (UIColor *)linkTextColor;
+ (UIColor *)linkHighlightedTextColor;
+ (UIColor *)menuDividerBottomInsetColor;
+ (UIColor *)menuDividerBottomColor;
+ (UIColor *)navigationBarBackgroundColor;
+ (UIColor *)navigationBarTextColor;
+ (UIColor *)navigationBarTextShadowColor;
+ (UIColor *)tableSeparatorColor;
+ (UIColor *)tableHeaderTextColor;
+ (UIColor *)tableHeaderBackgroundColor;
+ (UIColor *)titleColor;
+ (UIColor *)subtitleColor;
+ (UIColor *)selectedSegmentedTextColor;
+ (UIColor *)unselectedSegmentedTextColor;
+ (UIColor *)detailLineColor;
+ (UIColor *)searchTextColor;
+ (UIColor *)mapBorderLineColor;

@end

@interface UIFont (SFCongressAppStyle)

+ (UIFont *)navigationBarFont;
+ (UIFont *)menuFont;
+ (UIFont *)menuSelectedFont;
+ (UIFont *)buttonFont;
+ (UIFont *)bodyTextFont;
+ (UIFont *)bodySmallFont;
+ (UIFont *)billTitleFont;
+ (UIFont *)subitleFont;
+ (UIFont *)subitleStrongFont;
+ (UIFont *)subitleEmFont;
+ (UIFont *)legislatorTitleFont;
+ (UIFont *)linkFont;
+ (UIFont *)cellTextFont;
+ (UIFont *)cellDetailTextFont;
+ (UIFont *)cellPanelTextFont;
+ (UIFont *)cellPanelStrongTextFont;
+ (UIFont *)tableSectionHeaderFont;
+ (UIFont *)searchBarFont;

@end

@interface NSMutableAttributedString (SFCongressAppStyle)

+ (NSMutableAttributedString *)underlinedStringFor:(NSString *)string;
+ (NSMutableAttributedString *)linkStringFor:(NSString *)string;
+ (NSMutableAttributedString *)highlightedLinkStringFor:(NSString *)string;
+ (NSMutableAttributedString *)underlinedLinkStringFor:(NSString *)string;
+ (NSMutableAttributedString *)underlinedHighlightedLinkStringFor:(NSString *)string;

@end

@interface NSParagraphStyle (SFCongressAppStyle)

+ (NSParagraphStyle *)congressParagraphStyle;
+ (CGFloat)lineSpacing;

@end

@interface SFCongressAppStyle : NSObject

+ (void)setUpGlobalStyles;

@end
