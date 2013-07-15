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

@implementation ProcessWrapper
{
    NSTask *_processTask;
    NSXPCConnection *_processConnection;
    id<OEXPCCTestBackgroundService> _remoteObjectProxy;
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

    [[OEXPCCAgent defaultAgent] retrieveListenerEndpointForIdentifier:_identifier completionHandler:
     ^(NSXPCListenerEndpoint *endpoint)
     {
         _processConnection = [[NSXPCConnection alloc] initWithListenerEndpoint:endpoint];
         [_processConnection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(OEXPCCTestBackgroundService)]];
         [_processConnection resume];

         _remoteObjectProxy = [_processConnection remoteObjectProxy];
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
