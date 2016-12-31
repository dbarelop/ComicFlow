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
  NSFileHandle* _fileHandle;
  NSString* _filePath;
  long _downloadedBytes;
  NSDate* _timestamp;
}
- (id) init {
  return self;
}

- (void) dealloc {
  [self closeFiles];
}

- (void) viewDidLoad {
  [super viewDidLoad];

  _downloadLabel.text = @"Waiting...";
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

- (void) closeFiles {
  if (_fileHandle) {
    [_fileHandle closeFile];
    _fileHandle = nil;
  }
  [_smbFile close];
}

- (void) updateDownloadStatus: (id) result {
  if ([result isKindOfClass:[NSError class]]) {
    NSError* error = result;

    [_downloadButton setTitle:@"Download"];
    _downloadLabel.text = [NSString stringWithFormat:@"Failed: %@", error.localizedDescription];
    [self closeFiles];
  } else if ([result isKindOfClass:[NSData class]]) {
    NSData* data = result;

    if (data.length == 0) {
      [_downloadButton setTitle:@"Download"];
      [self closeFiles];
    } else {
      NSTimeInterval time = -[_timestamp timeIntervalSinceNow];
      _downloadedBytes += data.length;
      _downloadProgress.progress = (float) _downloadedBytes / (float) _smbFile.stat.size;
      CGFloat value;
      NSString* unit;
      if (_downloadedBytes < 1024) {
        value = _downloadedBytes;
        unit = @"B";
      } else if (_downloadedBytes < 1024*1024) {
        value = _downloadedBytes / 1024.f;
        unit = @"KB";
      } else {
        value = _downloadedBytes / (1024.f*1024.f);
        unit = @"MB";
      }
      _downloadLabel.text = [NSString stringWithFormat:@"Downloaded %.1f%@ (%.1f%%) %.2f%@/s", value, unit, _downloadProgress.progress * 100.f, value / time, unit];

      if (_fileHandle) {
        [_fileHandle writeData:data];
        if (_downloadedBytes == _smbFile.stat.size) {
          [self closeFiles];
          [_downloadButton setTitle:@"Done"];
          [_downloadButton setEnabled:NO];
          [self displayCover];
        } else {
          [self download];
        }
      }
    }
  }
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

- (void) download {
  __weak __typeof(self) weakSelf = self;
  [_smbFile readDataOfLength:1024*1024 block:^(id result) {
    NetworkFileViewController* p = weakSelf;
    if (p) {
      [p updateDownloadStatus:result];
    }
  }];
}
@end

@implementation NetworkFileViewController (IBActions)
- (IBAction) back {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction) downloadAction {
  if (!_fileHandle) {
    NSString* folder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString* filename = _smbFile.path.lastPathComponent;
    _filePath = [folder stringByAppendingPathComponent:filename];

    NSFileManager* fileManager = [[NSFileManager alloc] init];
    if ([fileManager fileExistsAtPath:_filePath]) {
      [fileManager removeItemAtPath:_filePath error:nil];
    }
    [fileManager createFileAtPath:_filePath contents:nil attributes:nil];

    NSError* error;
    _fileHandle = [NSFileHandle fileHandleForWritingToURL:[NSURL fileURLWithPath:_filePath] error:&error];
    if (_fileHandle) {
      [_downloadButton setTitle:@"Cancel"];
      _downloadedBytes = 0;
      _downloadProgress.progress = 0;
      _timestamp = [NSDate date];
      [self download];
    } else {
      _downloadLabel.text = [NSString stringWithFormat:@"Failed: %@", error.localizedDescription];
    }
  } else {
    [_downloadButton setTitle:@"Download"];
    [self closeFiles];
  }
}

@end

@implementation NetworkFileDownloaderController

+ (void)downloadFileAtPath:(KxSMBItemFile *)file destination:(NSString *)destination {
  [NetworkFileDownloaderController downloadFileAtPath:file destination:destination blocksize:DEFAULT_BLOCKSIZE handler:nil onlyAtEnd:YES];
}

+ (void)downloadFileAtPath:(KxSMBItemFile *)file destination:(NSString *)destination finalHandler:(void (^)(float percentage))finalHandler {
  [NetworkFileDownloaderController downloadFileAtPath:file destination:destination blocksize:DEFAULT_BLOCKSIZE handler:finalHandler onlyAtEnd:YES];
}

+ (void)downloadFileAtPath:(KxSMBItemFile *)file destination:(NSString *)destination blocksize:(NSUInteger)blocksize handler:(void (^)(float percentage))handler {
  [NetworkFileDownloaderController downloadFileAtPath:file destination:destination blocksize:DEFAULT_BLOCKSIZE handler:handler onlyAtEnd:NO];
}

+ (void) downloadFileAtPath:(KxSMBItemFile *)file destination:(NSString *)destination blocksize:(NSUInteger)blocksize handler:(void (^)(float percentage))handler onlyAtEnd:(BOOL)onlyAtEnd {
  NSFileManager *fileManager = [[NSFileManager alloc] init];
  // Create destination file
  [fileManager createFileAtPath:destination contents:nil attributes:nil];
  NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingToURL:[NSURL fileURLWithPath:destination] error:nil];
  // Start download
  long downloadedBytes = 0;
  float percentage = 0.0;
  NSData *buf;
  while (downloadedBytes < file.stat.size) {
    if (!onlyAtEnd) {
      handler(percentage);
    }
    buf = [file readDataOfLength:blocksize];
    [fileHandle writeData:buf];
    percentage += (float) buf.length / (float) file.stat.size;
  }
  handler(percentage);
  [file close];
  [fileHandle closeFile];
}


@end
