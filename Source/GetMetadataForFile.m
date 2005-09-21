#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <Foundation/Foundation.h>


/* -----------------------------------------------------------------------------
    Get metadata attributes from file
   
   This function's job is to extract useful information your file format supports
   and return it as a dictionary
----------------------------------------------------------------------------- */


void DImp_ProcessInventoryFile(NSString *path, NSMutableString *log, NSMutableSet *authors);


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
			// We're dealing with a _darcs directory, so far so good!
			NSMutableDictionary *attrs = (NSMutableDictionary *)attributes;
			NSMutableString *log = [[NSMutableString alloc] init];
			NSMutableSet *authors = [[NSMutableSet alloc] init];
			
			// Process top-level 'inventory' file
			DImp_ProcessInventoryFile([rootPath stringByAppendingPathComponent:@"inventory"], log, authors);
			
			// Process files in 'inventories' directory
			NSArray *invFiles = [[NSFileManager defaultManager] directoryContentsAtPath:[rootPath stringByAppendingPathComponent:@"inventories"]];
			NSEnumerator *invFilesEnum = [invFiles objectEnumerator];
			NSString *currInvFile;
			while (currInvFile = [invFilesEnum nextObject])
				if ([[currInvFile pathExtension] isEqualToString:@"gz"])
					DImp_ProcessInventoryFile(currInvFile, log, authors);
			
			[attrs setObject:log forKey:(NSString *)kMDItemTextContent];
			[attrs setObject:[authors allObjects] forKey:(NSString *)kMDItemAuthors];
			
			[log release];
			[authors release];
			
			success = TRUE;
		}
	}
	
	[pool release];
    return success;
}


void DImp_ProcessInventoryFile(NSString *path, NSMutableString *log, NSMutableSet *authors)
{
	if ([[NSFileManager defaultManager] isReadableFileAtPath:path])
	{
		NSString *inventory = [NSString stringWithContentsOfFile:path
														encoding:NSUTF8StringEncoding
														   error:nil];
		if (inventory)
		{
			BOOL authorIsNext = NO;
			NSArray *lines = [inventory componentsSeparatedByString:@"\n"];
			NSEnumerator *linesEnum = [lines objectEnumerator];
			NSString *currLine;
			while (currLine = [linesEnum nextObject])
			{
				if ([currLine length] == 0)
					continue;
				
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
					
					// Get rid of timestamp
					[scanner scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
					
					// Get rid of closing bracket and space, if any
					[scanner scanString:@"] " intoString:nil];
					
					if (![scanner isAtEnd])
						// Put the rest of the line back into currLine
						currLine = [currLine substringFromIndex:[scanner scanLocation]];
				}
				
				if ([currLine characterAtIndex:0] == '[')
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
