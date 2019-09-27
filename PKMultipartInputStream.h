// PKMultipartInputStream.h
// py.kerembellec@gmail.com

#import <Foundation/Foundation.h>

@interface PKMultipartInputStream : NSInputStream
- (void)addPartWithName:(NSString *_Nonnull)name string:(NSString *_Nonnull)string;
- (void)addPartWithName:(NSString *_Nonnull)name data:(NSData *_Nonnull)data;
- (void)addPartWithName:(NSString *_Nonnull)name data:(NSData *_Nonnull)data contentType:(NSString *_Nonnull)type;
- (void)addPartWithName:(NSString *_Nonnull)name filename:(NSString*_Nonnull)filename data:(NSData *_Nonnull)data contentType:(NSString *_Nonnull)type;
- (void)addPartWithName:(NSString *_Nonnull)name path:(NSString *_Nonnull)path;
- (void)addPartWithName:(NSString *_Nonnull)name filename:(NSString *_Nonnull)filename path:(NSString *_Nonnull)path;
- (void)addPartWithName:(NSString *_Nonnull)name filename:(NSString *_Nonnull)filename path:(NSString *_Nonnull)path contentType:(NSString *_Nonnull)type;
- (void)addPartWithName:(NSString *_Nonnull)name filename:(NSString *_Nonnull)filename stream:(NSInputStream *_Nonnull)stream streamLength:(NSUInteger)streamLength;
- (void)addPartWithHeaders:(NSDictionary *_Nonnull)headers string:(NSString *_Nonnull)string;
- (void)addPartWithHeaders:(NSDictionary *_Nonnull)headers path:(NSString *_Nonnull)path;

@property (nonatomic, readonly, nonnull) NSString *boundary;
@property (nonatomic, readonly) NSUInteger length;

@end
