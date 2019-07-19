/*
 Copyright (c) 2013, OpenEmu Team

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Cocoa/Cocoa.h>
#import <OpenEmuXPCCommunicator/OpenEmuXPCCommunicator.h>
#import "OEXPCCTestBackgroundService.h"

@interface TestTransfomer : NSObject <OEXPCTransformer>
- (void)instanceID:(void(^)(NSUInteger i))reply;
- (void)upper:(NSString *)message completionHandler:(void(^)(NSString *result))handle;
@end

@interface ServiceProvider : NSObject <OEXPCCTestBackgroundService, NSXPCListenerDelegate, NSApplicationDelegate>
- (void)resumeConnection;
@end

int main(int argc, const char * argv[])
{
#if 0
    [OEXPCCAgent waitForDebuggerUntil:5 * NSEC_PER_SEC];
#endif

    @autoreleasepool
    {
        NSApplication *app = [NSApplication sharedApplication];
        ServiceProvider *provider = [[ServiceProvider alloc] init];
        [app setDelegate:provider];
        [provider resumeConnection];
        [app run];
    }
    return 0;
}

@implementation TestTransfomer
{
    NSUInteger _id;
    NSString   *_name;
}

- (instancetype)init
{
    if ((self = [super init])) {
        static NSUInteger count = 0;
        
        @synchronized (TestTransfomer.class) {
            count++;
            _id = count;
        }
        
        _name = [NSString stringWithFormat:@"TestTransformer#%lu", _id];
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"dealloc: %@", self.description);
}

- (NSString *)description {
    return _name;
}

- (void)instanceID:(void(^)(NSUInteger i))reply
{
    reply(_id);
}

- (void)upper:(NSString *)message completionHandler:(void(^)(NSString *result))handler
{
    handler([NSString stringWithFormat:@"<%@> %@: %@", [OEXPCCAgent defaultProcessIdentifier], self.description, message.uppercaseString]);
}

@end

@implementation ServiceProvider
{
    NSXPCListener *_listener;
    NSXPCConnection *_mainAppConnection;
}

- (void)resumeConnection
{
    _listener = [NSXPCListener anonymousListener];
    [_listener setDelegate:self];
    [_listener resume];

    NSXPCListenerEndpoint *endpoint = [_listener endpoint];
    [[OEXPCCAgent defaultAgent] registerListenerEndpoint:endpoint forIdentifier:[OEXPCCAgent defaultProcessIdentifier] completionHandler:^(BOOL success){ }];
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    _mainAppConnection = newConnection;
    
    NSXPCInterface *service = [NSXPCInterface interfaceWithProtocol:@protocol(OEXPCCTestBackgroundService)];
    
    [_mainAppConnection setExportedInterface:service];
    [_mainAppConnection setExportedObject:self];
    [_mainAppConnection resume];
    
    // Register OEXPCTransformer interface as argument 0 of the reply
    [service setInterface:[NSXPCInterface interfaceWithProtocol:@protocol(OEXPCTransformer)]
              forSelector:@selector(getTransformer:)
            argumentIndex:0
                  ofReply:YES];

    return YES;
}

- (void)transformString:(NSString *)string completionHandler:(void (^)(NSString *))handler
{
    handler([NSString stringWithFormat:@"<%@>: %@", [OEXPCCAgent defaultProcessIdentifier], string]);
}

- (void)getTransformer:(void (^)(id<OEXPCTransformer>))reply
{
    reply([TestTransfomer new]);
}


@end
