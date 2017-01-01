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

#import "NetworkSharesViewController.h"
#import "KxSMBProvider.h"
#import "NetworkFileViewController.h"
#import "Library.h"

@interface NetworkSharesViewController ()
@property(readwrite, nonatomic, strong) KxSMBItemTree* currentDir;
@end

@implementation NetworkSharesViewController {
  NSArray* _items;
}

- (id) init:(UIWindow *)window {
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  if (_smbAuth == nil) {
    _smbAuth = [[KxSMBAuth alloc] init];
    _path = @"smb://";
    _smbAuth.workgroup = @"WORKGROUP";
    _smbAuth.username = @"guest";
    _smbAuth.password = @"";
  }

  [self reloadPath];
}

- (void) viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  UINavigationItem* item = [_navigationBar.items objectAtIndex:0];
  UIBarButtonItem* closeButton = [[UIBarButtonItem alloc] initWithTitle:@"Close" style:UIBarButtonItemStylePlain target:self action:@selector(close)];
  UIBarButtonItem* backButton = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self action:@selector(back)];
  UIBarButtonItem* refreshButton = [[UIBarButtonItem alloc] initWithTitle:@"Refresh" style:UIBarButtonItemStylePlain target:self action:@selector(refresh)];
  UIBarButtonItem* connectButton = [[UIBarButtonItem alloc] initWithTitle:@"Connect" style:UIBarButtonItemStylePlain target:self action:@selector(connect)];
  UIBarButtonItem* downloadButton = [[UIBarButtonItem alloc] initWithTitle:@"Download folder" style:UIBarButtonItemStylePlain target:self action:@selector(downloadFolder)];
  item.leftBarButtonItems = @[backButton, closeButton];
  item.rightBarButtonItems = @[refreshButton, connectButton, downloadButton];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [_items count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString* cellIdentifier = @"Cell";
  UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
  }

  KxSMBItem* item = _items[(NSUInteger) indexPath.row];
  cell.textLabel.text = item.path.lastPathComponent;

  if ([item isKindOfClass:[KxSMBItemTree class]]) {
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.detailTextLabel.text = @"";
  } else {
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%lld", item.stat.size];
  }

  return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [_tableView deselectRowAtIndexPath:indexPath animated:YES];

  KxSMBItem* item = _items[(NSUInteger) indexPath.row];
  if ([item isKindOfClass:[KxSMBItemTree class]]) {
    NetworkSharesViewController* viewController = [[NetworkSharesViewController alloc] init];
    viewController.smbAuth = _smbAuth;
    viewController.path = item.path;
    viewController.currentDir = (KxSMBItemTree *) item;
    [self presentViewController:viewController animated:NO completion:nil];
  } else if ([item isKindOfClass:[KxSMBItemFile class]]) {
    NetworkFileViewController* viewController = [[NetworkFileViewController alloc] init];
    viewController.smbFile = (KxSMBItemFile*) item;
    [self presentViewController:viewController animated:NO completion:nil];
  }
}

- (void) reloadPath {
  NSString* path;
  if (_path.length) {
    path = _path;
    _navigationBar.topItem.title = [NSString stringWithFormat:@"%@@%@", _smbAuth.username, path.lastPathComponent];
    [[[_navigationBar.items objectAtIndex:0].rightBarButtonItems objectAtIndex:0] setEnabled:YES];

    _items = nil;
    [_tableView reloadData];

    KxSMBBlock updateItems = ^(id result) {
      if ([result isKindOfClass:[NSError class]]) {
        _navigationBar.topItem.title = ((NSError*) result).localizedDescription;
      } else if ([result isKindOfClass:[NSArray class]]) {
        _items = [result sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"path" ascending:YES]]];
        [_tableView reloadData];
      } else if ([result isKindOfClass:[KxSMBItem class]]) {
        _items = @[result];
        [_tableView reloadData];
      }
    };
    if (_currentDir) {
      [_currentDir fetchItems:updateItems];
    } else {
      KxSMBProvider* provider = [KxSMBProvider sharedSmbProvider];
      [provider fetchAtPath:path auth:_smbAuth block:updateItems];
    }
  } else {
    [[[_navigationBar.items objectAtIndex:0].rightBarButtonItems objectAtIndex:0] setEnabled:NO];
  }
}

@end

@implementation NetworkSharesViewController (IBActions)

- (IBAction) close {
  [self.view.window.rootViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction) back {
  [self dismissViewControllerAnimated:![[self presentingViewController] isKindOfClass:[NetworkSharesViewController class]] completion:nil];
}

- (IBAction) refresh {
  [self reloadPath];
}

- (IBAction) connect {
  UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Connect to host" message:nil preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
    textField.text = _path;
    textField.placeholder = @"smb://";
    textField.clearButtonMode = UITextFieldViewModeAlways;
  }];
  [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
    textField.text = _smbAuth.workgroup;
    textField.placeholder = @"Domain";
    textField.clearButtonMode = UITextFieldViewModeAlways;
  }];
  [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
    textField.text = _smbAuth.username;
    textField.placeholder = @"Username";
    textField.clearButtonMode = UITextFieldViewModeAlways;
  }];
  [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
    textField.placeholder = @"Password";
    textField.secureTextEntry = YES;
    textField.clearButtonMode = UITextFieldViewModeAlways;
  }];
  [alert addAction:[UIAlertAction actionWithTitle:@"Go" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
    self.path = alert.textFields[0].text;
    self.smbAuth.workgroup = alert.textFields[1].text;
    self.smbAuth.username = alert.textFields[2].text;
    self.smbAuth.password = alert.textFields[3].text;
    [self reloadPath];
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction) downloadFolder {
  // Build the alert
  UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Downloading" message:@"\n\n" preferredStyle:UIAlertControllerStyleAlert];
  // TODO: add two progress bars; one for current file and another one for all files (count before)
  // TODO: add cancel button
  UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
  spinner.center = CGPointMake(alert.view.frame.size.width / 2, (CGFloat) (alert.view.frame.size.height - spinner.frame.size.height - 160.0));
  spinner.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
  spinner.color = [UIColor blackColor];
  [spinner startAnimating];
  [alert.view addSubview:spinner];
  [self presentViewController:alert animated:YES completion:nil];
  // Download the folder
  dispatch_async(dispatch_queue_create("download_queue", NULL), ^{
    NSString* destination = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    [NetworkFileDownloaderController downloadDirectory:_currentDir destination:destination];
    [[LibraryUpdater sharedUpdater] update:NO];
    dispatch_async(dispatch_get_main_queue(), ^{
      [alert dismissViewControllerAnimated:YES completion:nil];
    });
  });
}

@end
