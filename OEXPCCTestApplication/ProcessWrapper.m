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

#import "ProcessWrapper.h"
#import <OpenEmuXPCCommunicator/OpenEmuXPCCommunicator.h>
#import "OEXPCCTestBackgroundService.h"

@interface NSView (Custom)
    -(void) setEnabled:(BOOL) isEnabled;
@end

@implementation ProcessWrapper
{
    NSTask *_processTask;
    NSXPCConnection *_processConnection;
    id<OEXPCCTestBackgroundService> _remoteObjectProxy;
    id<OEXPCTransformer> _transformer;
}

- (void)setUpWithProcessIdentifier:(NSString *)identifier;
{
    if(identifier == nil) identifier = [[NSUUID UUID] UUIDString];
    
    _identifier = [identifier copy];
    
    OEXPCCAgentConfiguration *configuration = [OEXPCCAgentConfiguration defaultConfiguration];
    
    _processTask = [[NSTask alloc] init];
    [_processTask setLaunchPath:[[NSBundle mainBundle] pathForResource:@"OEXPCBackgroundProcessTest" ofType:nil]];
    [_processTask setArguments:@[ [configuration agentServiceNameProcessArgument], [configuration processIdentifierArgumentForIdentifier:_identifier] ]];
    
    [_processTask launch];
    
    self.serviceConnectButton.enabled = NO;
    [self.serviceControlsGroup setEnabled:NO];
    
    [[OEXPCCAgent defaultAgent] retrieveListenerEndpointForIdentifier:_identifier completionHandler:
     ^(NSXPCListenerEndpoint *endpoint)
     {
        self->_processConnection = [[NSXPCConnection alloc] initWithListenerEndpoint:endpoint];
        NSXPCInterface *service = [NSXPCInterface interfaceWithProtocol:@protocol(OEXPCCTestBackgroundService)];
        [self->_processConnection setRemoteObjectInterface:service];
        [self->_processConnection resume];
        
        // Register OEXPCTransformer interface as argument 0 of the reply
        [service setInterface:[NSXPCInterface interfaceWithProtocol:@protocol(OEXPCTransformer)]
                  forSelector:@selector(getTransformer:)
                argumentIndex:0
                      ofReply:YES];
        
        self->_remoteObjectProxy = [self->_processConnection remoteObjectProxy];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.serviceConnectButton.enabled = YES;
        });
    }];
}

- (IBAction)serviceConnectToggle:(id)sender
{
    __block NSButton *btn = sender;
    [btn setEnabled:NO];
    [self.serviceControlsGroup setEnabled:NO];
    
    if (_transformer == nil)
    {
        [_remoteObjectProxy getTransformer:^(id<OEXPCTransformer> obj) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_transformer = obj;
                btn.title = @"Disconnect";
                [btn setEnabled:YES];
                [self.serviceControlsGroup setEnabled:YES];
            });
        }];
    }
    else
    {
        _transformer = nil;
        btn.title = @"Connect";
        [btn setEnabled:YES];
    }
}

- (IBAction)serviceTransformOrigin:(id)sender
{
    [_transformer upper:self.serviceOriginTextField.stringValue completionHandler:^(NSString *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.serviceResultTextField.stringValue = result;
        });
    }];
}

- (IBAction)transformOrigin:(id)sender
{
    [_remoteObjectProxy transformString:[[self originTextField] stringValue] completionHandler:
     ^(NSString *result)
     {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self resultTextField] setStringValue:result];
        });
    }];
}

- (void)terminate
{
    [_processTask terminate];
}

@end

@implementation NSView (Custom)

-(void) setEnabled:(BOOL) isEnabled{

    for (NSView* subView in self.subviews) {

        if ([subView isKindOfClass:[NSControl class]]) {

            [(NSControl*)subView setEnabled:isEnabled];
        }else  if ([subView isKindOfClass:[NSView class]]) {

            [subView setEnabled:isEnabled];
        }
    }
}

@end
