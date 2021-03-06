// PKMultipartInputStream.m
// py.kerembellec@gmail.com

#import <UIKit/UIKit.h>
#import <MobileCoreServices/UTType.h>
#import "PKMultipartInputStream.h"
#define kHeaderStringFormat @"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n"
#define kHeaderDataFormat @"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\nContent-Type: %@\r\n\r\n"
#define kHeaderPathFormat @"--%@\r\nContent-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\nContent-Type: %@\r\n\r\n"
#define kFooterFormat @"--%@--\r\n"

static NSString * MIMETypeForExtension(NSString * extension) {

    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)extension, NULL);
    if (uti != NULL)
    {
        CFStringRef mime = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType);
        CFRelease(uti);
        if (mime != NULL)
        {
            NSString *type = [NSString stringWithString:(__bridge NSString *)mime];
            CFRelease(mime);
            return type;
        }
    }
    return @"application/octet-stream";
}

@interface PKMultipartElement : NSObject
@property (nonatomic, strong) NSData *headers;
@property (nonatomic, strong) NSInputStream *body;
@property (nonatomic) NSUInteger headersLength, bodyLength, length, delivered;
@end

@implementation PKMultipartElement
- (void)updateLength
{
    self.length = self.headersLength + self.bodyLength + 2;
    [self.body open];
}
- (id)initWithName:(NSString *)name boundary:(NSString *)boundary string:(NSString *)string
{
    self               = [super init];
    self.headers       = [[NSString stringWithFormat:kHeaderStringFormat, boundary, name] dataUsingEncoding:NSUTF8StringEncoding];
    self.headersLength = [self.headers length];
    NSData *stringData = [string dataUsingEncoding:NSUTF8StringEncoding];
    self.body          = [NSInputStream inputStreamWithData:stringData];
    self.bodyLength    = stringData.length;
    [self updateLength];
    return self;
}
- (id)initWithName:(NSString *)name boundary:(NSString *)boundary data:(NSData *)data contentType:(NSString *)contentType
{
    self               = [super init];
    self.headers       = [[NSString stringWithFormat:kHeaderDataFormat, boundary, name, contentType] dataUsingEncoding:NSUTF8StringEncoding];
    self.headersLength = [self.headers length];
    self.body          = [NSInputStream inputStreamWithData:data];
    self.bodyLength    = [data length];
    [self updateLength];
    return self;
}
- (id)initWithName:(NSString *)name boundary:(NSString *)boundary data:(NSData *)data contentType:(NSString *)contentType filename:(NSString*)filename
{
    self               = [super init];
    self.headers       = [[NSString stringWithFormat:kHeaderPathFormat, boundary, name, filename, contentType] dataUsingEncoding:NSUTF8StringEncoding];
    self.headersLength = [self.headers length];
    self.body          = [NSInputStream inputStreamWithData:data];
    self.bodyLength    = [data length];
    [self updateLength];
    return self;
}
- (id)initWithName:(NSString *)name filename:(NSString *)filename boundary:(NSString *)boundary path:(NSString *)path
{
    return [self initWithName:name filename:filename boundary:boundary path:path contentType:MIMETypeForExtension(path.pathExtension)];
}
- (id)initWithName:(NSString *)name filename:(NSString *)filename boundary:(NSString *)boundary path:(NSString *)path contentType:(NSString *)contentType
{
    self = [super init];
    if (self) {
        if (!filename)
        {
            filename = path.lastPathComponent;
        }
        self.headers       = [[NSString stringWithFormat:kHeaderPathFormat, boundary, name, filename, contentType] dataUsingEncoding:NSUTF8StringEncoding];
        self.headersLength = [self.headers length];
        self.body          = [NSInputStream inputStreamWithFileAtPath:path];
        self.bodyLength    = [[[[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL] objectForKey:NSFileSize] unsignedIntegerValue];
        [self updateLength];
    }
    return self;
}
- (id)initWithName:(NSString *)name filename:(NSString *)filename boundary:(NSString *)boundary stream:(NSInputStream *)stream streamLength:(NSUInteger)streamLength
{
    self = [super init];
    if (self) {
        self.headers       = [[NSString stringWithFormat:kHeaderPathFormat, boundary, name, filename, MIMETypeForExtension(filename.pathExtension)] dataUsingEncoding:NSUTF8StringEncoding];
        self.headersLength = [self.headers length];
        self.body          = stream;
        self.bodyLength    = streamLength;
        [self updateLength];
    }
    return self;
}
- (id)initWithHeaders:(NSDictionary *)headers string:(NSString *)string boundary:(NSString *)boundary
{
    self = [super init];
    if (self) {
        
        _headers = [self makeHeadersDataFromHeadersDict:headers boundary:boundary];
        _headersLength = _headers.length;
        NSData *stringData = [string dataUsingEncoding:NSUTF8StringEncoding];
        _body = [NSInputStream inputStreamWithData:stringData];
        _bodyLength = stringData.length;
        [self updateLength];
    }
    return self;
}

- (id)initWithHeaders:(NSDictionary *)headers path:(NSString *)path boundary:(NSString *)boundary
{
    self = [super init];
    if (self) {
        
        _headers = [self makeHeadersDataFromHeadersDict:headers boundary:boundary];
        _headersLength = _headers.length;
        _body = [NSInputStream inputStreamWithFileAtPath:path];
        _bodyLength = [[[[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL] objectForKey:NSFileSize] unsignedIntegerValue];
        [self updateLength];
    }
    return self;
}

- (NSData *)makeHeadersDataFromHeadersDict:(NSDictionary *)headers boundary:(NSString *)boundary
{
    NSMutableString *headersString = [[NSMutableString alloc] initWithFormat:@"--%@", boundary];
    [self appendNewLine:headersString];
    
    for (NSString *key in headers.allKeys) {
        
        [headersString appendString:[[NSString alloc] initWithFormat:@"%@: %@", key, headers[key]]];
        [self appendNewLine:headersString];
    }
    
    [self appendNewLine:headersString];
    
    NSData *result = [headersString dataUsingEncoding:NSUTF8StringEncoding];
    return result;
}

- (void)appendNewLine:(NSMutableString *)string {
    
    [string appendString:@"\r\n"];
}

- (NSUInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len
{
    NSUInteger sent = 0, read;

    if (self.delivered >= self.length)
    {
        return 0;
    }
    if (self.delivered < self.headersLength && sent < len)
    {
        read            = MIN(self.headersLength - self.delivered, len - sent);
        [self.headers getBytes:buffer + sent range:NSMakeRange(self.delivered, read)];
        sent           += read;
        self.delivered += sent;
    }
    while (self.delivered >= self.headersLength && self.delivered < (self.length - 2) && sent < len)
    {
        if ((read = [self.body read:buffer + sent maxLength:len - sent]) == 0)
        {
            break;
        }
        sent           += read;
        self.delivered += read;
    }
    if (self.delivered >= (self.length - 2) && sent < len)
    {
        if (self.delivered == (self.length - 2))
        {
            *(buffer + sent) = '\r';
            sent ++; self.delivered ++;
        }
        *(buffer + sent) = '\n';
        sent ++; self.delivered ++;
    }
    return sent;
}
@end

@interface PKMultipartInputStream()
@property (nonatomic, strong) NSMutableArray *parts;
@property (nonatomic, strong, nonnull) NSString *boundary;
@property (nonatomic, strong) NSData *footer;
@property (nonatomic) NSUInteger currentPart, delivered, length;
@property (nonatomic) NSStreamStatus status;
@end

@implementation PKMultipartInputStream
@synthesize delegate;
- (void)updateLength
{
    self.length = self.footer.length + [[self.parts valueForKeyPath:@"@sum.length"] unsignedIntegerValue];
}
- (id)init
{
    self = [super init];
    if (self)
    {
        self.parts    = [NSMutableArray array];
        self.boundary = [[NSProcessInfo processInfo] globallyUniqueString];
        self.footer   = [[NSString stringWithFormat:kFooterFormat, self.boundary] dataUsingEncoding:NSUTF8StringEncoding];
        [self updateLength];
    }
    return self;
}
- (void)addPartWithName:(NSString *)name string:(NSString *)string
{
    [self.parts addObject:[[PKMultipartElement alloc] initWithName:name boundary:self.boundary string:string]];
    [self updateLength];
}
- (void)addPartWithName:(NSString *)name data:(NSData *)data
{
    [self.parts addObject:[[PKMultipartElement alloc] initWithName:name boundary:self.boundary data:data contentType:@"application/octet-stream"]];
    [self updateLength];
}
- (void)addPartWithName:(NSString *)name data:(NSData *)data contentType:(NSString *)type
{
    [self.parts addObject:[[PKMultipartElement alloc] initWithName:name boundary:self.boundary data:data contentType:type]];
    [self updateLength];
}
- (void)addPartWithName:(NSString *)name filename:(NSString*)filename data:(NSData *)data contentType:(NSString *)type
{
    [self.parts addObject:[[PKMultipartElement alloc] initWithName:name boundary:self.boundary data:data contentType:type filename:filename]];
    [self updateLength];
}
- (void)addPartWithName:(NSString *)name path:(NSString *)path
{
    [self.parts addObject:[[PKMultipartElement alloc] initWithName:name filename:nil boundary:self.boundary path:path]];
    [self updateLength];
}
- (void)addPartWithName:(NSString *)name filename:(NSString *)filename path:(NSString *)path
{
    [self.parts addObject:[[PKMultipartElement alloc] initWithName:name filename:filename boundary:self.boundary path:path]];
    [self updateLength];
}
- (void)addPartWithName:(NSString *)name filename:(NSString *)filename path:(NSString *)path contentType:(NSString *)type
{
    [self.parts addObject:[[PKMultipartElement alloc] initWithName:name filename:filename boundary:self.boundary path:path contentType:type]];
    [self updateLength];
}
- (void)addPartWithName:(NSString *)name filename:(NSString *)filename stream:(NSInputStream *)stream streamLength:(NSUInteger)streamLength
{
    [self.parts addObject:[[PKMultipartElement alloc] initWithName:name filename:filename boundary:self.boundary stream:stream streamLength:streamLength]];
    [self updateLength];
}

- (void)addPartWithHeaders:(NSDictionary *)headers string:(NSString *)string
{
    [self.parts addObject:[[PKMultipartElement alloc] initWithHeaders:headers string:string boundary:self.boundary]];
    [self updateLength];
}

- (void)addPartWithHeaders:(NSDictionary *)headers path:(NSString *)path
{
    [self.parts addObject:[[PKMultipartElement alloc] initWithHeaders:headers path:path boundary:self.boundary]];
    [self updateLength];
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len
{
    NSUInteger sent = 0, read;

    self.status = NSStreamStatusReading;
    while (self.delivered < self.length && sent < len && self.currentPart < self.parts.count)
    {
        if ((read = [[self.parts objectAtIndex:self.currentPart] read:(buffer + sent) maxLength:(len - sent)]) == 0)
        {
            self.currentPart ++;
            continue;
        }
        sent            += read;
        self.delivered  += read;
    }
    if (self.delivered >= (self.length - self.footer.length) && sent < len)
    {
        read            = MIN(self.footer.length - (self.delivered - (self.length - self.footer.length)), len - sent);
        [self.footer getBytes:buffer + sent range:NSMakeRange(self.delivered - (self.length - self.footer.length), read)];
        sent           += read;
        self.delivered += read;
    }
    return sent;
}
- (BOOL)hasBytesAvailable
{
    return self.delivered < self.length;
}
- (void)open
{
    self.status = NSStreamStatusOpen;
}
- (void)close
{
    self.status = NSStreamStatusClosed;
}
- (NSStreamStatus)streamStatus
{
    if (self.status != NSStreamStatusClosed && self.delivered >= self.length)
    {
        self.status = NSStreamStatusAtEnd;
    }
    return self.status;
}
- (void)_scheduleInCFRunLoop:(NSRunLoop *)runLoop forMode:(id)mode {}
- (void)_setCFClientFlags:(CFOptionFlags)flags callback:(CFReadStreamClientCallBack)callback context:(CFStreamClientContext)context {}
- (void)removeFromRunLoop:(__unused NSRunLoop *)aRunLoop forMode:(__unused NSString *)mode {}
- (id)propertyForKey:(NSStreamPropertyKey)key {
    return nil;
}

- (BOOL)setProperty:(id)property forKey:(NSStreamPropertyKey)key {
    return NO;
}
@end
