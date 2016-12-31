//  Copyright (C) 2016-2017 Daniel Barea López <dbarelop@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import "NavigationControl.h"

@class KxSMBItemFile;

@interface NetworkFileViewController : UIViewController <UINavigationBarDelegate>
@property(nonatomic, retain) IBOutlet UINavigationBar* navigationBar;
@property(nonatomic, retain) IBOutlet UIProgressView* downloadProgress;
@property(nonatomic, retain) IBOutlet UILabel* downloadLabel;
@property(nonatomic, retain) IBOutlet UIImageView* contentView;
@property (readwrite, nonatomic, strong) KxSMBItemFile* smbFile;
@end

@interface NetworkFileDownloaderController
+ (void) downloadFileAtPath:(KxSMBItemFile * _Nonnull)file destination:(NSString * _Nonnull)destination;
+ (void) downloadFileAtPath:(KxSMBItemFile * _Nonnull)file destination:(NSString * _Nonnull)destination finalHandler:(void (^ _Nullable)(float percentage, long downloadedBytes))finalHandler;
+ (void) downloadFileAtPath:(KxSMBItemFile * _Nonnull)file destination:(NSString * _Nonnull)destination blocksize:(NSUInteger)blocksize handler:(void (^ _Nullable)(float percentage, long downloadedBytes))handler;
@end
