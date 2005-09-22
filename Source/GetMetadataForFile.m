#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <Foundation/Foundation.h>


void DImp_ProcessInventoryFile(NSString *path, NSMutableString *log, NSMutableSet *authors, NSString **latestModDate);


/* -----------------------------------------------------------------------------
	Get metadata attributes from file
	
	This function's job is to extract useful information your file format supports
	and return it as a dictionary
----------------------------------------------------------------------------- */


// A string that all date codes will be greater than, YYYYmmddHHMMSS
#define ZERO_MOD_DATE @"00000000000000"

Boolean GetMetadataForFile(void* thisInterface,
                           CFMutableDictionaryRef attributes,
                           CFStringRef contentTypeUTI,
                           CFStringRef pathToFile)
{
	/* Pull any available metadata from the file at the specified path */
	/* Return the attribute keys and attribute values in the dict */
	/* Return TRUE if successful, FALSE if there was no data provided */
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	Boolean success = FALSE;
	
	// Basic checking
	if ([(NSString *)contentTypeUTI isEqualToString:@"net.darcs.repository"])
	{
		NSString *rootPath = (NSString *)pathToFile;
		NSArray *rootPathComponents = [rootPath pathComponents];
		
		if ([[rootPathComponents lastObject] isEqualToString:@"_darcs"])
		{
			// We're dealing with a _darcs directory; so far so good!
			NSMutableDictionary *attrs = (NSMutableDictionary *)attributes;
			NSMutableString *log = [[NSMutableString alloc] init];
			NSMutableSet *authors = [[NSMutableSet alloc] init];
			NSString *latestModificationDate = ZERO_MOD_DATE; 
			
			// Process top-level 'inventory' file
			DImp_ProcessInventoryFile([rootPath stringByAppendingPathComponent:@"inventory"], log, authors, &latestModificationDate);
			
			// Process files in 'inventories' directory
			NSArray *invFiles = [[NSFileManager defaultManager] directoryContentsAtPath:[rootPath stringByAppendingPathComponent:@"inventories"]];
			NSEnumerator *invFilesEnum = [invFiles objectEnumerator];
			NSString *currInvFile;
			while (currInvFile = [invFilesEnum nextObject])
				if ([[currInvFile pathExtension] isEqualToString:@"gz"])
					DImp_ProcessInventoryFile(currInvFile, log, authors, &latestModificationDate);
			
			// Set source location
			NSMutableArray *sourcePaths = nil;
			NSString *reposPath = [rootPath stringByAppendingPathComponent:@"prefs/repos"];
			if ([[NSFileManager defaultManager] isReadableFileAtPath:reposPath])
			{
				NSString *reposContents = [NSString stringWithContentsOfFile:reposPath
				                                                    encoding:NSUTF8StringEncoding
				                                                       error:NULL];
				if (reposContents)
				{
					sourcePaths = [NSMutableArray arrayWithArray:[reposContents componentsSeparatedByString:@"\n"]];
					if ([[sourcePaths lastObject] isEqualToString:@""])
						[sourcePaths removeLastObject];
				}
			}
			
			
			// Set display name
			NSString *displayName = [NSString stringWithFormat:@"%@ (Darcs)", [rootPathComponents objectAtIndex:([rootPathComponents count] - 2u)]];
			
			// Set attributes
			[attrs setObject:log
			          forKey:(NSString *)kMDItemTextContent];
			[attrs setObject:[authors allObjects]
			          forKey:(NSString *)kMDItemAuthors];
			[attrs setObject:displayName
			          forKey:(NSString *)kMDItemDisplayName];
			if (sourcePaths)
				[attrs setObject:sourcePaths
				          forKey:(NSString *)kMDItemWhereFroms];
			if (![latestModificationDate isEqualToString:ZERO_MOD_DATE])
			{
				// Get date of last record
				NSCalendarDate *lastChangeDate = [NSCalendarDate dateWithString:latestModificationDate calendarFormat:@"%Y%m%d%H%M%S"];
				[lastChangeDate setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
				NSCalendarDate *localDate = [lastChangeDate addTimeInterval:[[NSTimeZone localTimeZone] secondsFromGMTForDate:lastChangeDate]];
				[localDate setTimeZone:[NSTimeZone localTimeZone]];
				
				[attrs setObject:localDate
				          forKey:(NSString *)kMDItemContentModificationDate];
				[attrs setObject:localDate
				          forKey:(NSString *)kMDItemLastUsedDate];
			}
			
			[log release];
			[authors release];
			
			success = TRUE;
		}
	}
	
	[pool release];
	return success;
}


void DImp_ProcessInventoryFile(NSString *path, NSMutableString *log, NSMutableSet *authors, NSString **latestModDate)
{
	if ([[NSFileManager defaultManager] isReadableFileAtPath:path])
	{
		NSString *inventory = [NSString stringWithContentsOfFile:path
		                                                encoding:NSUTF8StringEncoding
		                                                   error:NULL];
		if (inventory)
		{
			BOOL authorIsNext = NO;
			NSArray *lines = [inventory componentsSeparatedByString:@"\n"];
			NSEnumerator *linesEnum = [lines objectEnumerator];
			NSString *currLine;
			while (currLine = [linesEnum nextObject])
			{
				if (authorIsNext)
				{
					authorIsNext = NO;
					
					// We're scanning an author e-mail, in one of the following formats:
					// 1) If there was no long message, and darcs isn't being screwy:
					// "user@host.com**20050922051312] " (note trailing space)
					// 2) If there was a long message:
					// "user@host.com**20050922051312"
					// 3) If darcs is being screwy (due to characters like "]" in the patch name):
					// "user@hsot.com**20050922051312] [Other patch name"
					
					NSScanner *scanner = [NSScanner scannerWithString:currLine];
					NSString *author = nil;
					if ([scanner scanUpToString:@"**" intoString:&author])
						[authors addObject:author];
					
					// Get rid of "**"
					[scanner scanString:@"**" intoString:nil];
					
					// Scan of timestamp
					NSString *modDate;
					if ([scanner scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:&modDate])
					{
						if ([modDate compare:*latestModDate] == NSOrderedDescending)
							*latestModDate = [NSString stringWithString:modDate];
					}
					
					// Get rid of closing bracket and space, if any
					[scanner scanString:@"] " intoString:nil];
					
					// Put the rest of the line back into currLine
					currLine = [currLine substringFromIndex:[scanner scanLocation]];
				}
				
				if ([currLine length] > 0 && [currLine characterAtIndex:0] == '[')
				{
					authorIsNext = YES;
					currLine = [currLine substringFromIndex:1];
				}
				else if ([currLine isEqualToString:@"Starting with tag:"])
					currLine = @"";
				
				if ([currLine length] > 0u)
					[log appendFormat:@"%@\n", currLine];
			}
		}
	}
}
