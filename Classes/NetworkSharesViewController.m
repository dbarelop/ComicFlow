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

@implementation NetworkSharesViewController {
  NSArray* _items;
}

- (id) init:(UIWindow *)window {
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  if (_path.length) {
    [self reloadPath];
  }
  if (_smbAuth == nil) {
    _smbAuth = [[KxSMBAuth alloc] init];
  }
}

- (void) viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  UINavigationItem* item = [_navigationBar.items objectAtIndex:0];
  UIBarButtonItem* backButton = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self action:@selector(back)];
  UIBarButtonItem* refreshButton = [[UIBarButtonItem alloc] initWithTitle:@"Refresh" style:UIBarButtonItemStylePlain target:self action:@selector(refresh)];
  UIBarButtonItem* connectButton = [[UIBarButtonItem alloc] initWithTitle:@"Connect" style:UIBarButtonItemStylePlain target:self action:@selector(connect)];
  item.leftBarButtonItem = backButton;
  item.rightBarButtonItems = @[refreshButton, connectButton];
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
    [self presentViewController:viewController animated:NO completion:nil];
  } else if ([item isKindOfClass:[KxSMBItemFile class]]) {
    // TODO: implement
  }
}

- (void) reloadPath {
  NSString* path;
  if (_path.length) {
    path = _path;
    _navigationBar.topItem.title = path.lastPathComponent;

    _items = nil;
    [_tableView reloadData];

    KxSMBProvider* provider = [KxSMBProvider sharedSmbProvider];
    [provider fetchAtPath:path auth:_smbAuth block:^(id result) {
      if ([result isKindOfClass:[NSError class]]) {
        _navigationBar.topItem.title = ((NSError*) result).localizedDescription;
      } else if ([result isKindOfClass:[NSArray class]]) {
        _items = [result copy];
        [_tableView reloadData];
      } else if ([result isKindOfClass:[KxSMBItem class]]) {
        _items = @[result];
        [_tableView reloadData];
      }
    }];
  }
}


@end

@implementation NetworkSharesViewController (IBActions)

- (IBAction) back {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction) refresh {
  // TODO: implement
}

- (IBAction) connect {
  UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Connect to host" message:nil preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
    textField.text = @"smb://";
    textField.placeholder = @"smb://";
    textField.clearButtonMode = UITextFieldViewModeAlways;
  }];
  [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
    textField.text = @"WORKGROUP";
    textField.placeholder = @"Domain";
    textField.clearButtonMode = UITextFieldViewModeAlways;
  }];
  [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
    textField.text = @"guest";
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

@end
