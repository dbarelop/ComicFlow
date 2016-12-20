//  Copyright (C) 2010-2016 Pierre-Olivier Latour <info@pol-online.net>
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

#import "AppDelegate.h"
#import "Defaults.h"

#define kDisconnectLatency 1.0

@interface WebsiteServer : GCDWebUploader
@end

@interface WebDAVServer : GCDWebDAVServer
@end

@implementation WebsiteServer

- (BOOL) shouldUploadFileAtPath:(NSString*)path withTemporaryFile:(NSString*)tempPath {
  return YES;
}

@end

@implementation WebDAVServer

- (BOOL) shouldUploadFileAtPath:(NSString*)path withTemporaryFile:(NSString*)tempPath {
  return YES;
}

@end

@implementation WebServer

@synthesize delegate=_delegate, type=_type;

+ (void) initialize {
  NSMutableDictionary* defaults = [[NSMutableDictionary alloc] init];
  defaults[kDefaultKey_ServerType] = @(kWebServerType_Website);
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
  [defaults release];
}

+ (WebServer*) sharedWebServer {
  XLOG_DEBUG_CHECK([NSThread isMainThread]);
  static WebServer* server = nil;
  if (server == nil) {
    server = [[WebServer alloc] init];
    server.type = (WebServerType)[[NSUserDefaults standardUserDefaults] integerForKey:kDefaultKey_ServerType];
  }
  return server;
}

- (void) setType:(WebServerType)type {
  if (type != _type) {
    if (_type != kWebServerType_Off) {
      [_webServer stop];
      [_webServer release];
      _webServer = nil;
      _type = kWebServerType_Off;
    }
    if (type != kWebServerType_Off) {
      NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
      NSArray* fileExtensions = @[@"pdf", @"zip", @"cbz", @"rar", @"cbr"];
      if (type == kWebServerType_Website) {
        _webServer = [[WebsiteServer alloc] initWithUploadDirectory:documentsPath];
        [(WebsiteServer*)_webServer setAllowedFileExtensions:fileExtensions];
        [(WebsiteServer*)_webServer setTitle:NSLocalizedString(@"SERVER_TITLE", nil)];
        [(WebsiteServer*)_webServer setPrologue:[NSString stringWithFormat:NSLocalizedString(@"SERVER_CONTENT", nil), [fileExtensions componentsJoinedByString:@", "]]];
        [(WebsiteServer*)_webServer setFooter:[NSString stringWithFormat:NSLocalizedString(@"SERVER_FOOTER_FORMAT", nil),
                                                [[UIDevice currentDevice] name],
                                                [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]]];
      } else if (type == kWebServerType_WebDAV) {
        _webServer = [[WebDAVServer alloc] initWithUploadDirectory:documentsPath];
        [(WebDAVServer*)_webServer setAllowedFileExtensions:fileExtensions];
      }
      
      if (_webServer) {
        _webServer.delegate = self;
        NSMutableDictionary* options = [NSMutableDictionary dictionary];
#if TARGET_IPHONE_SIMULATOR
        [options setObject:[NSNumber numberWithInteger:8080] forKey:GCDWebServerOption_Port];
#else
        options[GCDWebServerOption_Port] = @80;
#endif
        options[GCDWebServerOption_BonjourName] = @"";
        NSString* name = [NSString stringWithFormat:NSLocalizedString(@"SERVER_NAME_FORMAT", nil),
                          [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                          [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
        options[GCDWebServerOption_ServerName] = name;
        options[GCDWebServerOption_ConnectedStateCoalescingInterval] = @kDisconnectLatency;
        NSError* error = nil;
        BOOL success = [_webServer startWithOptions:options error:&error];
#if !TARGET_IPHONE_SIMULATOR
        if (!success && [error.domain isEqualToString:NSPOSIXErrorDomain] && (error.code == 48)) {
          XLOG_WARNING(@"Server port 80 is busy, trying alternate port 8080");
          options[GCDWebServerOption_Port] = @8080;
          success = [_webServer startWithOptions:options error:&error];
        }
#endif
        if (success) {
          _type = type;
        } else {
          [_webServer release];
          _webServer = nil;
        }
      }
    }
    [[NSUserDefaults standardUserDefaults] setInteger:_type forKey:kDefaultKey_ServerType];
  }
}

- (NSString*) addressLabel {
  NSURL* serverURL = _webServer.serverURL;
  NSURL* bonjourServerURL = _webServer.bonjourServerURL;
  switch (_type) {
    
    case kWebServerType_Off:
      break;
    
    case kWebServerType_Website:
      if (serverURL) {
        if (bonjourServerURL) {
          return [NSString stringWithFormat:NSLocalizedString(@"ADDRESS_WEBSITE_BONJOUR", nil), [bonjourServerURL absoluteString], [serverURL absoluteString]];
        } else {
          return [NSString stringWithFormat:NSLocalizedString(@"ADDRESS_WEBSITE_IP", nil), [serverURL absoluteString]];
        }
      }
      break;
    
    case kWebServerType_WebDAV:
      if (serverURL) {
        if (bonjourServerURL) {
          return [NSString stringWithFormat:NSLocalizedString(@"ADDRESS_WEBDAV_BONJOUR", nil), [bonjourServerURL absoluteString], [serverURL absoluteString]];
        } else {
          return [NSString stringWithFormat:NSLocalizedString(@"ADDRESS_WEBDAV_IP", nil), [serverURL absoluteString]];
        }
      }
      break;
    
  }
  return NSLocalizedString(@"ADDRESS_UNAVAILABLE", nil);
}

- (void) webServerDidConnect:(GCDWebServer*)server {
  [_delegate webServerDidConnect:self];
}

- (void) webServerDidDisconnect:(GCDWebServer*)server {
  [_delegate webServerDidDisconnect:self];
}

- (void) webUploader:(GCDWebUploader*)uploader didDownloadFileAtPath:(NSString*)path {
  [_delegate webServerDidDownloadComic:self];
}

- (void) webUploader:(GCDWebUploader*)uploader didUploadFileAtPath:(NSString*)path {
  [_delegate webServerDidUploadComic:self];
}

- (void) webUploader:(GCDWebUploader*)uploader didMoveItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath {
  [_delegate webServerDidUpdate:self];
}

- (void) webUploader:(GCDWebUploader*)uploader didDeleteItemAtPath:(NSString*)path {
  [_delegate webServerDidUpdate:self];
}

- (void) webUploader:(GCDWebUploader*)uploader didCreateDirectoryAtPath:(NSString*)path {
  [_delegate webServerDidUpdate:self];
}

- (void) davServer:(GCDWebDAVServer*)server didDownloadFileAtPath:(NSString*)path {
  [_delegate webServerDidDownloadComic:self];
}

- (void) davServer:(GCDWebDAVServer*)server didUploadFileAtPath:(NSString*)path {
  [_delegate webServerDidUploadComic:self];
}

- (void) davServer:(GCDWebDAVServer*)server didMoveItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath {
  [_delegate webServerDidUpdate:self];
}

- (void) davServer:(GCDWebDAVServer*)server didCopyItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath {
  [_delegate webServerDidUpdate:self];
}

- (void) davServer:(GCDWebDAVServer*)server didDeleteItemAtPath:(NSString*)path {
  [_delegate webServerDidUpdate:self];
}

- (void) davServer:(GCDWebDAVServer*)server didCreateDirectoryAtPath:(NSString*)path {
  [_delegate webServerDidUpdate:self];
}

@end
