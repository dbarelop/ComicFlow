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

#import "NetworkFileViewController.h"
#import "KxSMBProvider.h"
#import "MiniZip.h"
#import "ImageDecompression.h"

#define DEFAULT_BLOCKSIZE 1024 * 1024

@implementation NetworkFileViewController {
  UIBarButtonItem* _downloadButton;
  NSString* _filePath;
  NSDate* _timestamp;
}
- (id) init {
  return self;
}

- (void) viewDidLoad {
  [super viewDidLoad];

  _downloadLabel.text = @"Download the file to preview it";
  _navigationBar.topItem.title = _smbFile.path.lastPathComponent;
  _downloadProgress.progress = 0;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  UINavigationItem* item = [_navigationBar.items objectAtIndex:0];
  UIBarButtonItem* backButton = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self action:@selector(back)];
  _downloadButton = [[UIBarButtonItem alloc] initWithTitle:@"Download" style:UIBarButtonItemStylePlain target:self action:@selector(downloadAction)];
  item.leftBarButtonItem = backButton;
  item.rightBarButtonItem = _downloadButton;
}

- (void) updateDownloadStatus :(float)percentage :(long)downloadedBytes {
  NSTimeInterval time = -[_timestamp timeIntervalSinceNow];
  CGFloat value;
  NSString* unit;
  if (downloadedBytes < 1024) {
    value = downloadedBytes;
    unit = @"B";
  } else if (downloadedBytes < 1024*1024) {
    value = downloadedBytes / 1024.f;
    unit = @"KB";
  } else {
    value = downloadedBytes / (1024.f*1024.f);
    unit = @"MB";
  }
  _downloadLabel.text = [NSString stringWithFormat:@"Downloaded %.1f%@ (%.1f%%) at %.2f%@/s", value, unit, percentage * 100.f, value / time, unit];
  [_downloadProgress setProgress:percentage animated:YES];
}

- (void) displayCover {
  // Display cover image for CBZ files
  NSString* extension = [_filePath pathExtension];
  if ([extension caseInsensitiveCompare:@"zip"] || [extension caseInsensitiveCompare:@"cbz"]) {
    MiniZip *contents = [[MiniZip alloc] initWithArchiveAtPath:_filePath];
    NSArray *pages = [contents retrieveFileList];
    if ([pages count] > 0) {
      NSString *firstPage = pages[0];
      NSString *temp = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
      if ([contents extractFile:firstPage toPath:temp]) {
        NSData *coverData = [[NSData alloc] initWithContentsOfFile:temp];
        NSString *coverExtension = [firstPage pathExtension];
        // TODO: adjust size
        CGImageRef cover = CreateCGImageFromFileData(coverData, coverExtension, CGSizeMake(800, 800), NO);
        UIImage* image = [[UIImage alloc] initWithCGImage:cover];
        UIImageView* imageView = [[UIImageView alloc] initWithImage:image];
        [_contentView addSubview:imageView];
      }
      [[NSFileManager defaultManager] removeItemAtPath:temp error:NULL];
    }
  }
}

@end

@implementation NetworkFileViewController (IBActions)
- (IBAction) back {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction) downloadAction {
  NSString* folder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
  NSString* filename = _smbFile.path.lastPathComponent;
  _filePath = [folder stringByAppendingPathComponent:filename];

  [_downloadButton setTitle:@"Cancel"];
  _downloadProgress.progress = 0;
  _timestamp = [NSDate date];
  dispatch_async(dispatch_queue_create("file_download_queue", NULL), ^{
    [NetworkFileDownloaderController downloadFileAtPath:_smbFile destination:_filePath blocksize:1024 * 1024 handler:^(float percentage, long downloadedBytes) {
      dispatch_async(dispatch_get_main_queue(), ^{
        [self updateDownloadStatus:percentage :downloadedBytes];
      });
    }];
    dispatch_async(dispatch_get_main_queue(), ^{
      [_downloadButton setTitle:@"Done"];
      [_downloadButton setAction:@selector(back)];
      [self displayCover];
    });
  });
}

@end

@implementation NetworkFileDownloaderController

+ (void)downloadFileAtPath:(KxSMBItemFile *)file destination:(NSString *)destination {
  [NetworkFileDownloaderController downloadFileAtPath:file destination:destination blocksize:DEFAULT_BLOCKSIZE handler:nil onlyAtEnd:YES];
}

+ (void)downloadFileAtPath:(KxSMBItemFile *)file destination:(NSString *)destination finalHandler:(void (^)(float percentage, long downloadedBytes))finalHandler {
  [NetworkFileDownloaderController downloadFileAtPath:file destination:destination blocksize:DEFAULT_BLOCKSIZE handler:finalHandler onlyAtEnd:YES];
}

+ (void)downloadFileAtPath:(KxSMBItemFile *)file destination:(NSString *)destination blocksize:(NSUInteger)blocksize handler:(void (^)(float percentage, long downloadedBytes))handler {
  [NetworkFileDownloaderController downloadFileAtPath:file destination:destination blocksize:DEFAULT_BLOCKSIZE handler:handler onlyAtEnd:NO];
}

+ (void) downloadFileAtPath:(KxSMBItemFile *)file destination:(NSString *)destination blocksize:(NSUInteger)blocksize handler:(void (^)(float percentage, long downloadedBytes))handler onlyAtEnd:(BOOL)onlyAtEnd {
  NSFileManager *fileManager = [[NSFileManager alloc] init];
  // Create destination file
  if ([fileManager fileExistsAtPath:destination]) {
    [fileManager removeItemAtPath:destination error:nil];
  }
  [fileManager createFileAtPath:destination contents:nil attributes:nil];
  NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingToURL:[NSURL fileURLWithPath:destination] error:nil];
  // Start download
  long downloadedBytes = 0;
  float percentage = 0.0;
  NSData *buf;
  while (downloadedBytes < file.stat.size) {
    if (!onlyAtEnd) {
      handler(percentage, downloadedBytes);
    }
    buf = [file readDataOfLength:blocksize];
    [fileHandle writeData:buf];
    downloadedBytes += buf.length;
    percentage += (float) buf.length / (float) file.stat.size;
  }
  handler(percentage, downloadedBytes);
  [file close];
  [fileHandle closeFile];
}


@end
