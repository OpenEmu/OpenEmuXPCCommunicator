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

#import "OEXPCCAgentConfiguration.h"
#import "OEXPCCAgentConfiguration_Internal.h"

NSString *const _OEXPCCAgentServiceNameArgumentPrefix = @"--org.openemu.OEXPCCAgent.ServiceName=";
NSString *const _OEXPCCAgentProcessIdentifierArgumentPrefix = @"--org.openemu.OEXPCCAgent.ProcessIdentifier=";
NSString *const _OEXPCCAgentServiceNamePrefix = @"org.openemu.OEXPCCAgent.";

@implementation OEXPCCAgentConfiguration
{
    NSString *_serviceNameArgument;
    NSString *_agentPlistPath;
    NSString *_agentProcessPath;
}

+ (OEXPCCAgentConfiguration *)defaultConfiguration
{
    return [self OEXPCC_defaultConfigurationCreateIfNeeded:YES];
}

+ (OEXPCCAgentConfiguration *)OEXPCC_defaultConfigurationCreateIfNeeded:(BOOL)createIfNeeded
{
    static OEXPCCAgentConfiguration *sharedInstance = nil;

    if(createIfNeeded)
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            sharedInstance = [[OEXPCCAgentConfiguration alloc] init];
        });
    }

    return sharedInstance;
}

- (id)init
{
    if((self = [super init]))
    {
        _serviceName = [@[ _OEXPCCAgentServiceNamePrefix, [[NSUUID UUID] UUIDString] ] componentsJoinedByString:@""];
        _serviceNameArgument = [@[ _OEXPCCAgentServiceNameArgumentPrefix, _serviceName ] componentsJoinedByString:@""];

        _agentProcessPath = [[self OEXPCC_agentsApplicationSupportFolderPath] stringByAppendingPathComponent:_serviceName];
        _agentPlistPath = [_agentProcessPath stringByAppendingPathExtension:@"plist"];

        [self OEXPCC_setUpAgent];
    }
    return self;
}

- (void)OEXPCC_setUpAgent
{
    [[self OEXPCC_propertyListForAgent] writeToFile:_agentPlistPath atomically:YES];
    [[NSFileManager defaultManager] copyItemAtPath:[self OEXPCC_originalAgentProgramPath] toPath:_agentProcessPath error:NULL];

    NSTask *launchctlTask = [[NSTask alloc] init];

    [launchctlTask setLaunchPath:@"/bin/launchctl"];
    [launchctlTask setArguments:@[ @"load", _agentPlistPath ]];

    [launchctlTask setStandardOutput:[NSFileHandle fileHandleWithStandardOutput]];

    [launchctlTask launch];
    [launchctlTask waitUntilExit];
}

- (void)tearDownAgent
{
    NSTask *launchctlTask = [[NSTask alloc] init];

    [launchctlTask setLaunchPath:@"/bin/launchctl"];
    [launchctlTask setArguments:@[ @"unload", _agentPlistPath ]];

    [launchctlTask setStandardOutput:[NSFileHandle fileHandleWithStandardOutput]];

    [launchctlTask launch];
    [launchctlTask waitUntilExit];

    [[NSFileManager defaultManager] removeItemAtPath:_agentPlistPath error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:_agentProcessPath error:NULL];
}

- (NSString *)agentServiceNameProcessArgument
{
    return _serviceNameArgument;
}

- (NSString *)processIdentifierArgumentForIdentifier:(NSString *)identifier
{
    return [@[ _OEXPCCAgentProcessIdentifierArgumentPrefix, identifier ] componentsJoinedByString:@""];
}

- (NSString *)OEXPCC_originalAgentProgramPath
{
    static NSString *originalAgentProgramPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        originalAgentProgramPath = [[NSBundle bundleForClass:[OEXPCCAgentConfiguration class]] pathForResource:@"OpenEmuXPCCommunicatorAgent" ofType:nil];
    });

    return originalAgentProgramPath;
}

- (NSDictionary *)OEXPCC_propertyListForAgent
{
    return @{
        @"Label" : _serviceName,
        @"Program" : _agentProcessPath,
        @"MachServices" : @{ _serviceName : @{ } }
    };
}

+ (NSString *)OEXPCC_agentsApplicationSupportFolderPath
{
    static NSString *agentsApplicationSupportFolderPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        if([paths count] == 0) @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Could not find Application Support directory." userInfo:nil];

        agentsApplicationSupportFolderPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"org.openemu.OEXPCCAgent.Agents"];

        [[NSFileManager defaultManager] createDirectoryAtPath:agentsApplicationSupportFolderPath withIntermediateDirectories:YES attributes:nil error:NULL];
    });

    return agentsApplicationSupportFolderPath;
}

+ (NSString *)agentsDirectory
{
    return [self OEXPCC_agentsApplicationSupportFolderPath];
}

@end
