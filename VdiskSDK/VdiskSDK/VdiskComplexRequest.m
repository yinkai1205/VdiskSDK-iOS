//
//  VdiskSDK
//  Based on OAuth 2.0
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  Created by Bruce Chen (weibo: @一个开发者) on 12-6-15.
//
//  Copyright (c) 2012 Sina Vdisk. All rights reserved.
//

#import "VdiskComplexRequest.h"
#import "VdiskJSON.h"
#import "VdiskError.h"
#import "VdiskLog.h"
#import "DDLog.h"
#import "CLog.h"
#import "CLogReport.h"
#import "VdiskSDKGlobal.h"

id<VdiskNetworkRequestDelegate> kVdiskNetworkRequestDelegate = nil;

@interface VdiskComplexRequest () {

    CLog *_clog;
    CLog *_downloadClog;
}

- (void)setError:(NSError *)error;
- (NSUInteger)parseErrorCode;

@end

@implementation VdiskComplexRequest

@synthesize failureSelector = _failureSelector;
@synthesize downloadProgressSelector = _downloadProgressSelector;
@synthesize uploadProgressSelector = _uploadProgressSelector;
@synthesize requestDidReceiveResponseSelector = _requestDidReceiveResponseSelector;
@synthesize requestWillRedirectSelector = _requestWillRedirectSelector;
@synthesize userInfo = _userInfo;
@synthesize request = _request;
@synthesize xVdiskMetadataJSON = _xVdiskMetadataJSON;
@synthesize downloadProgress = _downloadProgress;
@synthesize uploadProgress = _uploadProgress;

@synthesize resultFilename = _resultFilename;
@synthesize error = _error;



+ (void)setNetworkRequestDelegate:(id<VdiskNetworkRequestDelegate>)delegate {
    
    kVdiskNetworkRequestDelegate = delegate;
}

- (id)initWithRequest:(ASIFormDataRequest *)aRequest andInformTarget:(id)aTarget selector:(SEL)aSelector {
    
    if ((self = [super init])) {
    
        _request = [aRequest retain];
        [_request setDelegate:self];
        [_request setUploadProgressDelegate:self];
        
        _target = aTarget;
        _selector = aSelector;
        
        /* CLog */
        _clog = nil;
        _downloadClog = nil;

    }
    
    return self;
}

- (void)dealloc {
    
    /* CLog */
    
    if (_clog) {
        
        if (self.userInfo && [[self.userInfo objectForKey:@"action"] isEqualToString:@"upload"]) {
            
            NSString *value1 = [self.userInfo objectForKey:@"upload_type"] ? [self.userInfo objectForKey:@"upload_type"] : @"-";
            NSString *value2 = [self.userInfo objectForKey:@"uploadId"] ? [self.userInfo objectForKey:@"uploadId"] : @"-";
            NSString *value3 = [self.userInfo objectForKey:@"destinationPath"] ? [self.userInfo objectForKey:@"destinationPath"] : @"-";
            
            NSString *key1 = [value1 isEqualToString:@"-"] ? @"-" : @"upload_type";
            NSString *key2 = [value2 isEqualToString:@"-"] ? @"-" : @"upload_id";
            NSString *key3 = [value3 isEqualToString:@"-"] ? @"-" : @"upload_path";
            
            [_clog setCustomType:@"upload"];
            [_clog setCustomKeys:@[key1, key2, key3] andValues:@[value1, value2, value3]];
        }
        
        if (self.userInfo && [self.userInfo objectForKey:@"error"] && [[self.userInfo objectForKey:@"error"] isKindOfClass:[NSError class]]) {
            
            NSError *error = [self.userInfo objectForKey:@"error"];
            
            NSInteger errorCode = VdiskErrorParseErrorCode(error);
            kVdiskErrorLevel errorLevel = VdiskErrorParseErrorLevel(error);
            
            if (errorLevel == kVdiskErrorLevelLocal || errorLevel == kVdiskErrorLevelNetwork) {
                
                [_clog setClientErrorCode:[NSString stringWithFormat:@"%d", errorCode]];
            
            } else if (errorLevel == kVdiskErrorLevelAPI) {
                
                [_clog setApiErroeCode:[NSString stringWithFormat:@"%d", errorCode]];
            
            } else if (errorLevel == kVdiskErrorLevelHTTP) {
            
                [_clog setHttpResponseStatusCode:[NSString stringWithFormat:@"%d", errorCode]];
            }
        }
        
        DDLogInfo(@"%@", _clog);
    }

    /* CLog */

    if (_downloadClog) {
        
        DDLogInfo(@"%@", _downloadClog);
    }
    
    
    [_request clearDelegatesAndCancel];
    [_request release], _request = nil;
    
    [_userInfo release];

    [_xVdiskMetadataJSON release];
    [_resultFilename release];
    [_tempFilename release];

    [_error release];
    
    /* CLog */
    [_clog release], _clog = nil;
    [_downloadClog release], _downloadClog = nil;
    
    [super dealloc];
}

- (void)start {
    
    /* CLog */
    
    _clog = [[CLog alloc] init];
    [_clog startRecordTime];
    [_clog setHttpMethod:[_request requestMethod] andUrl:[[_request url] absoluteString]];
    //[_clog setHttpBytesUp:[NSString stringWithFormat:@"%llu", [_request postLength]]];
    
    /*
    
    if (self.userInfo && [[self.userInfo objectForKey:@"action"] isEqualToString:@"upload"]) {
                
        NSString *value1 = [self.userInfo objectForKey:@"upload_type"] ? [self.userInfo objectForKey:@"upload_type"] : @"-";
        NSString *value2 = [self.userInfo objectForKey:@"uploadId"] ? [self.userInfo objectForKey:@"uploadId"] : @"-";
        NSString *value3 = [self.userInfo objectForKey:@"destinationPath"] ? [self.userInfo objectForKey:@"destinationPath"] : @"-";
        
        NSString *key1 = [value1 isEqualToString:@"-"] ? @"-" : @"upload_type";
        NSString *key2 = [value2 isEqualToString:@"-"] ? @"-" : @"upload_id";
        NSString *key3 = [value3 isEqualToString:@"-"] ? @"-" : @"upload_path";
        
        [_clog setCustomType:@"upload"];
        [_clog setCustomKeys:@[key1, key2, key3] andValues:@[value1, value2, value3]];
    }
     
     */

    if (_request.url == nil && _request.error) {
    
        [self performSelectorOnMainThread:@selector(requestFailed:) withObject:_request waitUntilDone:NO];
        
    } else {
    
        [_request start];
    }
    
    [kVdiskNetworkRequestDelegate networkRequestStarted];
}

- (NSString *)resultString {
    
    return [_request responseString];
}

- (NSObject *)resultJSON {
    
    return [[self resultString] JSONValue];
} 

- (NSInteger)statusCode {
    
    return (NSInteger)[_request responseStatusCode];
}

- (unsigned long long)responseBodySize {
    
    // Use the content-length header, if available.
    
    //unsigned long long contentLength = [[[_request responseHeaders] objectForKey:@"Content-Length"] longLongValue];
    
    unsigned long long contentLength = [_request contentLength];
    
    if (contentLength > 0) return contentLength;
    
    // Fall back on the bytes field in the metadata x-header, if available.
    
    if (_xVdiskMetadataJSON != nil) {
        
        id bytes = [_xVdiskMetadataJSON objectForKey:@"bytes"];
        
        if (bytes != nil) {
        
            return [bytes longLongValue];
        }
    }
    
    return 0;
}

- (void)cancel {
    
    //[_request cancel];
    [_request clearDelegatesAndCancel];
    _target = nil;
    
    /* CLog */
    
    if (_tempFilename) {
        
        [_downloadClog setClientErrorCode:[NSString stringWithFormat:@"%d", ASIRequestCancelledErrorType]];
        
    } else {
        
        [_clog setClientErrorCode:[NSString stringWithFormat:@"%d", ASIRequestCancelledErrorType]];
    }
    
    
    [kVdiskNetworkRequestDelegate networkRequestStopped];
}

- (id)parseResponseAsType:(Class)cls {
    
    if (_error) return nil;
    
    NSObject *res = [self resultJSON];
    
    if (![res isKindOfClass:cls]) {
    
        NSMutableDictionary *errorUserInfo = [NSMutableDictionary dictionaryWithDictionary:_userInfo];
        [errorUserInfo setObject:[self resultString] forKey:@"errorMessage"];
        
        [self setError:[NSError errorWithDomain:kVdiskErrorDomain code:kVdiskErrorInvalidResponse userInfo:errorUserInfo]];
        
        /* CLog */

        if (_clog) {
            
            [_clog setClientErrorCode:[NSString stringWithFormat:@"%d", kVdiskErrorInvalidResponse]];
        }
        
        return nil;
    }
    
    return res;
}

- (void)startDownloadWithMetadata:(VdiskMetadata *)metadata {
    
    /*
    if (_clog != nil) {
        
        [_clog release], _clog = nil;
    }
     */

    if (_xVdiskMetadataJSON != nil) {
        
        [_xVdiskMetadataJSON release], _xVdiskMetadataJSON = nil;
    }
    
    _xVdiskMetadataJSON = [[metadata dictionaryValue] retain];
    
    [self startDownload:_request.url];
}


- (void)startDownload:(NSURL *)url {

    /*
     
     判断文件大小
     
     {
     bytes = 5455872;
     icon = "page_white";
     "is_dir" = 0;
     md5 = 547661926661b0ae5d332a6cee4ba4f7;
     "mime_type" = "application/vnd.ms-powerpoint";
     modified = "Sat, 29 Sep 2012 01:43:40 +0000";
     path = "/123";
     rev = 75222309;
     revision = 235796532;
     root = basic;
     sha1 = fb658b7ff4dfb645d72f9d539e2f2c7b0556dbf4;
     size = "5.2 MB";
     "thumb_exists" = 0;
     }
     
     */
    
    if (!_tempFilename) {
        
        _tempFilename = [[_resultFilename stringByAppendingString:@".download"] retain];
    }
    
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:_resultFilename] ) {
        
        
        if (_xVdiskMetadataJSON && [_xVdiskMetadataJSON objectForKey:@"bytes"]) {
            
            long long fileLength = [[_xVdiskMetadataJSON objectForKey:@"bytes"] longLongValue];
            
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:_resultFilename error:nil];
            
            if (attributes && [attributes isKindOfClass:[NSDictionary class]] && [attributes objectForKey:@"NSFileSize"] && [(NSNumber *)[attributes objectForKey:@"NSFileSize"] unsignedLongLongValue] == fileLength) {
                
                if (_selector) {
                    
                    [_target performSelectorOnMainThread:_selector withObject:self waitUntilDone:YES];
                }
                
                [kVdiskNetworkRequestDelegate networkRequestStopped];
                
                return;
                
            } else {
                
                [[NSFileManager defaultManager] removeItemAtPath:_tempFilename error:nil];
                [[NSFileManager defaultManager] removeItemAtPath:_resultFilename error:nil];
            }
        }
    }
    

    [self.request clearDelegatesAndCancel];
    [_request release], _request = nil;
        
    _request = [[ASIFormDataRequest requestWithURL:url] retain];

    [_request setValidatesSecureCertificate:NO];
    [_request setDownloadDestinationPath:_resultFilename];
    [_request setTemporaryFileDownloadPath:_tempFilename];
    [_request setAllowResumeForFileDownloads:YES];
    [_request setUserInfo:_userInfo];
    [_request setDelegate:self];
    [_request setDownloadProgressDelegate:self];
    [_request setShouldRedirect:NO];
    [_request setRequestMethod:@"GET"];
    
    if (_xVdiskMetadataJSON && [_xVdiskMetadataJSON objectForKey:@"md5"]) {
    
        [_request addRequestHeader:@"If-Range" value:[NSString stringWithFormat:@"\"%@\"", [_xVdiskMetadataJSON objectForKey:@"md5"]]];
    }
    
    [_request setNumberOfTimesToRetryOnTimeout:3];
    [_request start];
    
    /* CLog */
    [_downloadClog release], _downloadClog = nil;
    _downloadClog = [[CLog alloc] init];
    [_downloadClog startRecordTime];
    [_downloadClog setHttpMethod:[_request requestMethod] andUrl:[[_request url] absoluteString]];
    //[_downloadClog setHttpBytesUp:[NSString stringWithFormat:@"%llu", [_request postLength]]];
    [_downloadClog setCustomType:@"download"];
    //[_downloadClog setCustomActions:(NSMutableDictionary *)@{@"download_session" : @"s3"}];
    
}

#pragma mark NSURLConnection delegate methods

/*
- (void)request:(ASIHTTPRequest *)request willRedirectToURL:(NSURL *)newURL {
    
    
    if ([[request responseHeaders] objectForKey:@"X-Vdisk-Metadata"]) {
        
        _xVdiskMetadataJSON = [[[[request responseHeaders] objectForKey:@"X-Vdisk-Metadata"] JSONValue] retain];
    }
    
    if (_requestWillRedirectSelector) {
        
        id returnObject = [_target performSelector:_requestWillRedirectSelector withObject:self];
        
        if ([returnObject isKindOfClass:[NSNumber class]]) {
            
            if (![(NSNumber *)returnObject boolValue]) {
                
                
            }
        }
    }
    
}
 */

/*
- (void)requestRedirected:(ASIHTTPRequest *)request {


}

- (void)requestStarted:(ASIHTTPRequest *)request {
    
    
}
 */

- (void)request:(ASIHTTPRequest *)request didReceiveResponseHeaders:(NSDictionary *)responseHeaders {
    
    if ([responseHeaders objectForKey:@"x-vdisk-cip"]) {
        
        /* CLog */
        [CLog setSharedClientIp:[responseHeaders objectForKey:@"x-vdisk-cip"]];
    }
    
    // Parse out the x-response-metadata as JSON.
    
    if ([responseHeaders objectForKey:@"X-Vdisk-Metadata"]) {
        
        _xVdiskMetadataJSON = [[[responseHeaders objectForKey:@"X-Vdisk-Metadata"] JSONValue] retain];
    }
    
    
    if (_requestDidReceiveResponseSelector) {
        
        [_target performSelector:_requestDidReceiveResponseSelector withObject:self];
    }
    
    /*
    if ([self statusCode] / 100 == 2) {
        
        NSLog(@"%@", responseHeaders);
    }
    */
    
    if ([self statusCode] == 302) {
        
        if (_requestWillRedirectSelector) {
            
            id returnObject = [_target performSelector:_requestWillRedirectSelector withObject:self];
            
            if ([returnObject isKindOfClass:[NSNumber class]]) {
                
                if (![(NSNumber *)returnObject boolValue]) {
                    
                    return;
                }
            }
        }
        
        if (_resultFilename && [responseHeaders objectForKey:@"Location"]) {
            
            // Create the file here so it's created in case it's zero length
            // File is downloaded into a temporary file and then moved over when completed successfully
            
            _tempFilename = [[_resultFilename stringByAppendingString:@".download"] retain];
            
            [_request setDelegate:nil];
            
            /* CLog */
            [_clog stopRecordTime];
            [_clog setHttpBytesDown:@"0"];
            [_clog setHttpBytesUp:[NSString stringWithFormat:@"%llu", [_request postLength]]];
            [_clog setHttpResponseStatusCode:[NSString stringWithFormat:@"%d", self.statusCode]];
            //NSLog(@"%@", _clog);
            
            [self startDownload:[NSURL URLWithString:[responseHeaders objectForKey:@"Location"]]];

        }
    }
}

- (void)requestFinished:(ASIHTTPRequest *)request {
    
    /* CLog */
    
    BOOL isDownload = NO;
    
    if (!_tempFilename) {
        
        [_clog stopRecordTime];
        [_clog setHttpBytesDown:[NSString stringWithFormat:@"%llu", [self responseBodySize]]];
        [_clog setHttpBytesUp:[NSString stringWithFormat:@"%llu", [_request postLength]]];
        [_clog setHttpResponseStatusCode:[NSString stringWithFormat:@"%d", self.statusCode]];
    
    } else {
    
        isDownload = YES;
        
        [_downloadClog stopRecordTime];
        [_downloadClog setHttpBytesDown:[NSString stringWithFormat:@"%llu", [self responseBodySize]]];
        [_downloadClog setHttpBytesUp:[NSString stringWithFormat:@"%llu", [_request postLength]]];
        [_downloadClog setHttpResponseStatusCode:[NSString stringWithFormat:@"%d", self.statusCode]];
    }
    
    
    if (self.statusCode / 100 != 2) {
        
        if (self.statusCode == 302 && _resultFilename) {
            
            return;
        }
        
        NSMutableDictionary *errorUserInfo = [NSMutableDictionary dictionaryWithDictionary:_userInfo];
        
        
        // To get error userInfo, first try and make sense of the response as JSON, if that
        // fails then send back the string as an error message

        
        NSString *resultString = [self resultString];
        
        if ([resultString length] > 0) {
            
            @try {
                
                VdiskJsonParser *jsonParser = [VdiskJsonParser new];
                NSObject *resultJSON = [jsonParser objectWithString:resultString];
                [jsonParser release];
                
                if ([resultJSON isKindOfClass:[NSDictionary class]]) {
                    
                    [errorUserInfo addEntriesFromDictionary:(NSDictionary *)resultJSON];
                }
                
            } @catch (NSException *e) {
                
                [errorUserInfo setObject:resultString forKey:@"errorMessage"];
            }
        }
        
        [self setError:[NSError errorWithDomain:kVdiskErrorDomain code:self.statusCode userInfo:errorUserInfo]];
        
    } else if (_tempFilename && self.statusCode / 100 == 2) {
        
        unsigned long long totalSize = [request contentLength] + [request partialDownloadSize];
        
        /*
        
        if (_xVdiskMetadataJSON != nil) {
            
            id bytes = [_xVdiskMetadataJSON objectForKey:@"bytes"];
            
            if (bytes != nil) {
                
                totalSize = [bytes longLongValue];
            }
        }
         
         */
        
        NSFileManager *fileManager = [[NSFileManager new] autorelease];
        NSError *moveError;
        
        // Check that the file size is the same as the Content-Length
        NSDictionary *fileAttrs = [fileManager attributesOfItemAtPath:_resultFilename error:&moveError];
        
        if (!fileAttrs) {
            
            VdiskLogError(@"VdiskRequest#connectionDidFinishLoading: error getting file attrs: %@", moveError);
            [fileManager removeItemAtPath:_resultFilename error:nil];
            [fileManager removeItemAtPath:_tempFilename error:nil];
            //[self setError:[NSError errorWithDomain:moveError.domain code:moveError.code userInfo:self.userInfo]];
            [self setError:[NSError errorWithDomain:kVdiskErrorDomain code:kVdiskErrorGetFileAttributesFailure userInfo:self.userInfo]];
            
            
        } else if (totalSize != 0 && totalSize != [fileAttrs fileSize]) {
            
            // This happens in iOS 4.0 when the network connection changes while loading
            
            [fileManager removeItemAtPath:_resultFilename error:nil];
            [fileManager removeItemAtPath:_tempFilename error:nil];
            
            [self setError:[NSError errorWithDomain:kVdiskErrorDomain code:kVdiskErrorFileContentLengthNotMatch userInfo:self.userInfo]];
            
        } else {
            
            // Everything's OK, move temp file over to desired file
        }
        
        [_tempFilename release];
        
        _tempFilename = nil;
    
    }

    /* CLog */
    
    if (!isDownload) {
        
        if (_error) {
            
            /* CLog */
            NSInteger errorCode = [self parseErrorCode];
            
            kVdiskErrorLevel errorLevel = VdiskErrorParseErrorLevel(_error);
            
            if (errorLevel == kVdiskErrorLevelAPI) {
                
                [_clog setApiErroeCode:[NSString stringWithFormat:@"%d", errorCode]];
            }
        }
        
        /* CLog */
        //NSLog(@"%@", _clog);
    
    } else {
    
        if (_error) {
            
            /* CLog */
            NSInteger errorCode = [self parseErrorCode];
            kVdiskErrorLevel errorLevel = VdiskErrorParseErrorLevel(_error);
            
            if (errorLevel == kVdiskErrorLevelLocal) {
                
                [_downloadClog setClientErrorCode:[NSString stringWithFormat:@"%d", errorCode]];
            }
        }
        
        /* CLog */
        //NSLog(@"%@", _downloadClog);
    }
    

    SEL sel = (_error && _failureSelector) ? _failureSelector : _selector;
    [_target performSelector:sel withObject:self];
    
    [kVdiskNetworkRequestDelegate networkRequestStopped];
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    
    /* CLog */
    
    kVdiskErrorLevel errorLevel = VdiskErrorParseErrorLevel(request.error);
    
    if (!_tempFilename) {
        
        [_clog stopRecordTime];
        
        if (errorLevel == kVdiskErrorLevelNetwork || errorLevel == kVdiskErrorLevelLocal) {
            
            [_clog setClientErrorCode:[NSString stringWithFormat:@"%d", request.error.code]];
            
            if (ASIAuthenticationErrorType == request.error.code) {
                
                [_clog setHttpResponseStatusCode:@"401"];
            }
        
        } else if (errorLevel == kVdiskErrorLevelHTTP) {
            
            [_clog setHttpResponseStatusCode:[NSString stringWithFormat:@"%d", request.error.code]];
        }
        
        //NSLog(@"%@", _clog);
    
    } else {
    
        [_downloadClog stopRecordTime];
        
        if (errorLevel == kVdiskErrorLevelNetwork || errorLevel == kVdiskErrorLevelLocal) {
            
            [_downloadClog setClientErrorCode:[NSString stringWithFormat:@"%d", request.error.code]];
            
            if (ASIAuthenticationErrorType == request.error.code) {
                
                [_downloadClog setHttpResponseStatusCode:@"401"];
            }
            
        } else if (errorLevel == kVdiskErrorLevelHTTP) {
            
            [_downloadClog setHttpResponseStatusCode:[NSString stringWithFormat:@"%d", request.error.code]];
        }
        
        //NSLog(@"%@", _downloadClog);
    }
    
    [self setError:[NSError errorWithDomain:request.error.domain code:request.error.code userInfo:self.userInfo]];
    
    _bytesDownloaded = 0;
    _downloadProgress = 0;
    _uploadProgress = 0;
    
    if (_tempFilename) {
        
        /*
        NSFileManager *fileManager = [[NSFileManager new] autorelease];
        NSError *removeError;
        BOOL success = [fileManager removeItemAtPath:_tempFilename error:&removeError];
        
        if (!success) {
            
            VdiskLogError(@"VdiskRequest#connection:didFailWithError: error removing temporary file: %@", [removeError localizedDescription]);
        }
         */
        
        [_tempFilename release];
        _tempFilename = nil;
    }
    
    SEL sel = _failureSelector ? _failureSelector : _selector;
    [_target performSelector:sel withObject:self];
    
    [kVdiskNetworkRequestDelegate networkRequestStopped];
    
}

- (void)request:(ASIHTTPRequest *)request didReceiveBytes:(long long)bytes {

    _bytesDownloaded += bytes;
    
    if (_downloadProgressSelector) {
        
        unsigned long long totalSize = [request contentLength] + [request partialDownloadSize];
                
        if (totalSize > 0) {
            
            _downloadProgress = (CGFloat)_bytesDownloaded / (CGFloat)totalSize;
            
            if (_downloadProgressSelector) {
                
                [_target performSelector:_downloadProgressSelector withObject:self];
            }
        }
    }
}

/*
- (void)request:(ASIHTTPRequest *)request didSendBytes:(long long)bytes {

    _uploadProgress = (CGFloat)bytes / (CGFloat)totalBytesExpectedToWrite;
    
    if (_uploadProgressSelector) {
        
        [_target performSelector:_uploadProgressSelector withObject:self];
    }
}
 */

- (void)setProgress:(float)newProgress {

    _uploadProgress = newProgress;
    
    if (_uploadProgressSelector) {
        
        [_target performSelector:_uploadProgressSelector withObject:self];
    }
}




#pragma mark private methods

- (NSUInteger)parseErrorCode {

    return VdiskErrorParseErrorCode(_error);
}

- (void)setError:(NSError *)theError {
    
    if (theError == _error) return;
    
    [_error release];
    _error = [theError retain];
    
	NSString *errorStr = [_error.userInfo objectForKey:@"error"];
	
    if (!errorStr) {
		
        errorStr = [_error description];
	}
    
	if (!([_error.domain isEqual:kVdiskErrorDomain] && _error.code == 304)) {
		// Log errors unless they're 304's
		VdiskLogWarning(@"VdiskSDK: error making request to %@ - %@", [[_request url] path], errorStr);
	}
}


@end
