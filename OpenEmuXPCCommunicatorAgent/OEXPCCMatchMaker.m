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

#import "OEXPCCMatchMaker.h"

@interface OEXPCCMatchMakerListener : NSObject
+ (instancetype)matchMakerListenerWithEndpoint:(NSXPCListenerEndpoint *)endpoint handler:(void(^)(BOOL success))handler;
@property(readonly) NSXPCListenerEndpoint *endpoint;
@property(readonly, copy) void(^handler)(BOOL success);
@end

@interface OEXPCCMatchMaker () <OEXPCCMatchMaking, NSXPCListenerDelegate>
{
    NSString            *_serviceName;
    NSXPCListener       *_serviceListener;

    dispatch_queue_t     _listenerQueue;
    NSMutableDictionary *_pendingListeners;
    NSMutableDictionary *_pendingClients;
}

@end

@implementation OEXPCCMatchMaker

- (id)initWithServiceName:(NSString *)serviceName
{
    if((self = [super init]))
    {
        _serviceName      = [serviceName copy];
        _serviceListener  = [[NSXPCListener alloc] initWithMachServiceName:_serviceName];
        [_serviceListener setDelegate:self];

        _listenerQueue    = dispatch_queue_create("com.psychoinc.MatchMaker.ListenerQueue", DISPATCH_QUEUE_SERIAL);
        _pendingClients   = [NSMutableDictionary dictionary];
        _pendingListeners = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)resumeConnection
{
    [_serviceListener resume];

    __block BOOL continueRunning = NO;
    do {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:10]];

        dispatch_sync(_listenerQueue, ^{
            continueRunning = [_pendingClients count] > 0 || [_pendingListeners count] > 0;
        });
    } while(continueRunning);
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    [newConnection setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(OEXPCCMatchMaking)]];
    [newConnection setExportedObject:self];
    [newConnection resume];

    return YES;
}

- (void)registerListenerEndpoint:(NSXPCListenerEndpoint *)endpoint forIdentifier:(NSString *)identifier completionHandler:(void (^)(BOOL))handler
{
    dispatch_async(_listenerQueue, ^{
        void (^clientBlock)(NSXPCListenerEndpoint *) = self->_pendingClients[identifier];

        if(clientBlock == nil)
        {
            self->_pendingListeners[identifier] = [OEXPCCMatchMakerListener matchMakerListenerWithEndpoint:endpoint handler:handler];
            return;
        }

        clientBlock(endpoint);
        handler(YES);
        [self->_pendingClients removeObjectForKey:identifier];
    });
}

- (void)retrieveListenerEndpointForIdentifier:(NSString *)identifier completionHandler:(void (^)(NSXPCListenerEndpoint *))handler
{
    dispatch_async(_listenerQueue, ^{
        OEXPCCMatchMakerListener *listener = self->_pendingListeners[identifier];

        if(listener == nil)
        {
            self->_pendingClients[identifier] = [handler copy];
            return;
        }

        handler([listener endpoint]);

        [listener handler](YES);
        [self->_pendingListeners removeObjectForKey:identifier];
    });
}

@end

@implementation OEXPCCMatchMakerListener

+ (instancetype)matchMakerListenerWithEndpoint:(NSXPCListenerEndpoint *)endpoint handler:(void(^)(BOOL success))handler
{
    OEXPCCMatchMakerListener *listener = [[OEXPCCMatchMakerListener alloc] init];
    listener->_endpoint = endpoint;
    listener->_handler = [handler copy];
    return listener;
}

@end
