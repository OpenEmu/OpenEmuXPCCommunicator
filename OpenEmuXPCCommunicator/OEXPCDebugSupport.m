// Copyright (c) 2019, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "OEXPCDebugSupport.h"

#import <AppKit/AppKit.h>

#import <assert.h>
#import <stdbool.h>
#import <sys/types.h>
#import <unistd.h>
#import <sys/sysctl.h>
#import <stdatomic.h>


@implementation OEXPCCDebugSupport

+ (BOOL)debuggerAttached
{
    int                 junk;
    int                 mib[4];
    struct kinfo_proc   info;
    size_t              size;
    
    // Initialize the flags so that, if sysctl fails for some bizarre
    // reason, we get a predictable result.
    
    info.kp_proc.p_flag = 0;
    
    // Initialize mib, which tells sysctl the info we want, in this case
    // we're looking for information about a specific process ID.
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = getpid();
    
    // Call sysctl.
    
    size = sizeof(info);
    junk = sysctl(mib, sizeof(mib) / sizeof(*mib), &info, &size, NULL, 0);
    assert(junk == 0);
    
    // We're being debugged if the P_TRACED flag is set.
    
    return ( (info.kp_proc.p_flag & P_TRACED) != 0 );
}

+ (BOOL)OE_waitForDebuggerUntilTime:(dispatch_time_t)t
{
    dispatch_queue_global_t      queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);

    __block dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block atomic_bool          done;
    atomic_init(&done, false);
    
    dispatch_async(queue, ^{
        while (!self.debuggerAttached && atomic_load(&done) == false)
        {
            usleep(100);
        }
        dispatch_semaphore_signal(sem);
    });
    
    BOOL ok = dispatch_semaphore_wait(sem, t) == 0;
    atomic_store(&done, true);
    
    return ok;
}

+ (BOOL)waitForDebuggerUntil:(NSUInteger)nanoseconds
{
    return [self OE_waitForDebuggerUntilTime:dispatch_time(DISPATCH_TIME_NOW, nanoseconds)];
}

+ (void)waitForDebugger
{
    [self OE_waitForDebuggerUntilTime:DISPATCH_TIME_FOREVER];
}

@end
