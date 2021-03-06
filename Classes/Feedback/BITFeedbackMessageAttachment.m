/*
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */


#import "BITFeedbackMessageAttachment.h"
#import "BITHockeyHelper.h"
#import "HockeySDKPrivate.h"


#define kCacheFolderName @"attachments"

@interface BITFeedbackMessageAttachment()

@property (nonatomic, strong) NSMutableDictionary *thumbnailRepresentations;
@property (nonatomic, strong) NSData *internalData;
@property (nonatomic, copy) NSString *filename;


@end

@implementation BITFeedbackMessageAttachment {
  NSString *_tempFilename;
  
  NSString *_cachePath;
  
  NSFileManager *_fm;
}


+ (BITFeedbackMessageAttachment *)attachmentWithData:(NSData *)data contentType:(NSString *)contentType {
  
  static NSDateFormatter *formatter;
  
  if(!formatter) {
    formatter = [NSDateFormatter new];
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
  }
  
  BITFeedbackMessageAttachment *newAttachment = [[BITFeedbackMessageAttachment alloc] init];
  newAttachment.contentType = contentType;
  newAttachment.data = data;
  newAttachment.originalFilename = [NSString stringWithFormat:@"Attachment: %@", [formatter stringFromDate:[NSDate date]]];

  return newAttachment;
}

- (instancetype)init {
  if ((self = [super init])) {
    self.isLoading = NO;
    self.thumbnailRepresentations = [[NSMutableDictionary alloc] init];
    
    _fm = [[NSFileManager alloc] init];
    _cachePath = [bit_settingsDir() stringByAppendingPathComponent:kCacheFolderName];
    
    BOOL isDirectory;
    
    if (![_fm fileExistsAtPath:_cachePath isDirectory:&isDirectory]){
      [_fm createDirectoryAtPath:_cachePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
  }
  return self;
}

- (void)setData:(NSData *)data {
  self->_internalData = data;
  self.filename = [self possibleFilename];
  [self->_internalData writeToFile:self.filename atomically:NO];
}

- (NSData *)data {
  if (!self->_internalData && self.filename) {
    self.internalData = [NSData dataWithContentsOfFile:self.filename];
  }
  
  if (self.internalData) {
    return self.internalData;
  }
  
  return nil;
}

- (void)replaceData:(NSData *)data {
  self.data = data;
  self.thumbnailRepresentations = [[NSMutableDictionary alloc] init];
}

- (BOOL)needsLoadingFromURL {
  return (self.sourceURL && ![_fm fileExistsAtPath:[self.localURL path]]);
}

- (BOOL)isImage {
  return ([self.contentType rangeOfString:@"image"].location != NSNotFound);
}

- (NSURL *)localURL {
  if (self.filename && [_fm fileExistsAtPath:self.filename]) {
    return [NSURL fileURLWithPath:self.filename];
  }
  
  return nil;
}


#pragma mark NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.contentType forKey:@"contentType"];
  [aCoder encodeObject:self.filename forKey:@"filename"];
  [aCoder encodeObject:self.originalFilename forKey:@"originalFilename"];
  [aCoder encodeObject:self.sourceURL forKey:@"url"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  if ((self = [self init])) {
    self.contentType = [aDecoder decodeObjectForKey:@"contentType"];
    self.filename = [aDecoder decodeObjectForKey:@"filename"];
    self.thumbnailRepresentations = [NSMutableDictionary new];
    self.originalFilename = [aDecoder decodeObjectForKey:@"originalFilename"];
    self.sourceURL = [aDecoder decodeObjectForKey:@"url"];
  }
  
  return self;
}


#pragma mark - Thubmnails / Image Representation

- (NSImage *)imageRepresentationWithSize:(NSSize)size {
  NSImage *thumbnailImage = nil;
  
  NSDictionary *dict = @{ ((NSString *)kQLThumbnailOptionIconModeKey): @NO };
  
  CGImageRef ref = QLThumbnailImageCreate(kCFAllocatorDefault,
                                          (__bridge CFURLRef)self.localURL,
                                          size,
                                          (__bridge CFDictionaryRef)dict);
  
  if (ref != NULL) {
    thumbnailImage = [[NSImage alloc] initWithCGImage:ref size:size];
    CFRelease(ref);
  }
  
  if (!thumbnailImage) {
    thumbnailImage = [[NSWorkspace sharedWorkspace] iconForFile:self.filename];
    if (thumbnailImage) {
      [thumbnailImage setSize:size];
    }
  }
  
  return thumbnailImage;
}

- (NSImage *)thumbnailWithSize:(NSSize)size {
  if (self.needsLoadingFromURL) {
    NSImage *thumbnailImage = [[NSWorkspace sharedWorkspace] iconForFileType:[self.originalFilename pathExtension]];
    if (thumbnailImage) {
      [thumbnailImage setSize:size];
    }
    return thumbnailImage;
  }
  
  id<NSCopying> cacheKey = [NSValue valueWithSize:size];
  
  if (!self.thumbnailRepresentations[cacheKey]) {
    NSImage *image = [self imageRepresentationWithSize:size];
    
    if (!image) {
      return nil;
    }
    
    [self.thumbnailRepresentations setObject:image forKey:cacheKey];
  }
  
  return self.thumbnailRepresentations[cacheKey];
}

- (NSImage *)thumbnailRepresentation {
  return [self thumbnailWithSize:NSMakeSize(BIT_ATTACHMENT_THUMBNAIL_LENGTH, BIT_ATTACHMENT_THUMBNAIL_LENGTH)];
}

#pragma mark - Persistence Helpers

- (NSString *)possibleFilename {
  if (_tempFilename) {
    return _tempFilename;
  }
  
  NSString *uniqueString = bit_UUID();
  _tempFilename = [_cachePath stringByAppendingPathComponent:uniqueString];
  
  // File extension that suits the Content type.
  
  CFStringRef mimeType = (__bridge CFStringRef)self.contentType;
  CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType, NULL);
  CFStringRef extension = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension);
  if (extension) {
    _tempFilename = [_tempFilename stringByAppendingPathExtension:(__bridge NSString *)(extension)];
    CFRelease(extension);
  }
  
  CFRelease(uti);
  
  return _tempFilename;
}

- (void)deleteContents {
  if (self.filename) {
    [_fm removeItemAtPath:self.filename error:nil];
    self.filename = nil;
  }
}


#pragma mark - QLPreviewItem

- (NSString *)previewItemTitle {
  return self.originalFilename;
}

- (NSURL *)previewItemURL {
  if (self.localURL){
    return self.localURL;
  } else if (self.sourceURL) {
    NSString *filename = self.possibleFilename;
    if (filename) {
      return [NSURL fileURLWithPath:filename];
    }
  }
  
  return nil;
}


@end
