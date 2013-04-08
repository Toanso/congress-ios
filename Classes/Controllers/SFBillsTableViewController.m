//
//  SFBillsTableViewController.m
//  Congress
//
//  Created by Daniel Cloud on 2/15/13.
//  Copyright (c) 2013 Sunlight Foundation. All rights reserved.
//

#import "SFBillsTableViewController.h"
#import "SFBill.h"
#import "SFBillSegmentedViewController.h"
#import "SFBillCell.h"
#import "GAI.h"

@interface SFBillsTableViewController () <UIDataSourceModelAssociation>

@end

@implementation SFBillsTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.tableView registerClass:SFBillCell.class forCellReuseIdentifier:@"SFBillCell"];

    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    [tracker sendView:@"Bill List Screen"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

// SFDataTableViewController doesn't handle this method currently
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SFBillCell *cell;
    if (self.cellForIndexPathHandler) {
        cell = self.cellForIndexPathHandler(indexPath);
    }
    else
    {
        static NSString *CellIdentifier = @"SFBillCell";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

        // Configure the cell...
        if(!cell) {
            cell = [[SFBillCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }

        SFBill *bill  = nil;
        if ([self.sections count] == 0) {
            bill = (SFBill *)[self.items objectAtIndex:indexPath.row];
        }
        else
        {
            bill = (SFBill *)[[self.sections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        }
        cell.bill = bill;
    }

    [cell setFrame:CGRectMake(0, 0, cell.width, cell.cellHeight)];

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SFBillSegmentedViewController *detailViewController = [[SFBillSegmentedViewController alloc] initWithNibName:nil bundle:nil];
    SFBill *bill  = nil;
    if ([self.sections count] == 0) {
        bill = (SFBill *)[self.items objectAtIndex:indexPath.row];
    }
    else
    {
        bill = (SFBill *)[[self.sections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    }
    detailViewController.bill = bill;

    [self.navigationController pushViewController:detailViewController animated:YES];
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self tableView:self.tableView cellForRowAtIndexPath:indexPath];
    return ((SFBillCell *)cell).cellHeight;
}

#pragma mark - UIDataSourceModelAssociation protocol

- (NSString *)modelIdentifierForElementAtIndexPath:(NSIndexPath *)idx inView:(UIView *)view
{
    SFBill *bill;
    if ([self.sections count] == 0) {
        bill = (SFBill *)[self.items objectAtIndex:idx.row];
    }
    else
    {
        bill = (SFBill *)[[self.sections objectAtIndex:idx.section] objectAtIndex:idx.row];
    }
    return bill.remoteID;
}

- (NSIndexPath *)indexPathForElementWithModelIdentifier:(NSString *)identifier inView:(UIView *)view
{
    __block NSIndexPath* path = nil;
//    SFBill *bill = [SFBill existingObjectWithRemoteID:identifier];
    return path;
}

@end
