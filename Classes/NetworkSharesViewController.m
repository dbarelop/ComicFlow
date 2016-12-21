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

@implementation NetworkSharesViewController

NSMutableArray* values;

- (id) init:(UIWindow *)window {
  return self;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  UINavigationItem* item = [_navigationBar.items objectAtIndex:0];
  UIBarButtonItem* backButton = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self action:@selector(back)];
  UIBarButtonItem* refreshButton = [[UIBarButtonItem alloc] initWithTitle:@"Refresh" style:UIBarButtonItemStylePlain target:self action:@selector(refresh)];
  item.leftBarButtonItem = backButton;
  item.rightBarButtonItem = refreshButton;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  values = [[NSMutableArray alloc] initWithArray:@[@"one", @"two", @"three"]];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [values count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString* identifier = @"SimpleTableCell";
  UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:identifier];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
  }
  cell.textLabel.text = values[(NSUInteger) indexPath.row];
  return cell;
}


@end

@implementation NetworkSharesViewController (IBActions)

- (IBAction) back {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction) refresh {
  //[values removeAllObjects];
  [values addObjectsFromArray:@[@"four", @"five", @"six"]];
  [_tableView reloadData];
}

@end
