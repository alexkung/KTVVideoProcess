//
//  KTVVPMessageLoop.m
//  KTVVideoProcessDemo
//
//  Created by Single on 2018/3/15.
//  Copyright © 2018年 Single. All rights reserved.
//

#import "KTVVPMessageLoop.h"
#import "KTVVPObjectQueue.h"

@interface KTVVPMessageLoop ()

@property (nonatomic, strong) NSThread * thread;
@property (nonatomic, strong) NSCondition * waitThreadCondition;
@property (nonatomic, strong) KTVVPObjectQueue * messageQueue;
@property (nonatomic, assign) BOOL didClosed;

@end

@implementation KTVVPMessageLoop

- (instancetype)initWithIdentify:(NSString *)identify
{
    if (self = [super init])
    {
        _identify = identify;
        _waitThreadCondition = [[NSCondition alloc] init];
        _messageQueue = [[KTVVPObjectQueue alloc] init];
        _thread = [[NSThread alloc] initWithTarget:self selector:@selector(messageLoopThread) object:nil];
        _thread.qualityOfService = NSQualityOfServiceDefault;
        _thread.name = [NSString stringWithFormat:@"KTVVPMessageLoop-thread-%@", _identify];
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"%s", __func__);
}

- (void)run
{
    if (_didClosed)
    {
        return;
    }
    if (!_running)
    {
        _running = YES;
        [_thread start];
    }
}

- (void)stop
{
    if (_didClosed)
    {
        return;
    }
    _didClosed = YES;
    if (!_running)
    {
        _running = YES;
        [_thread start];
    }
    else
    {
        [_messageQueue broadcastAllSyncRequest];
    }
}

- (void)waitUntilThreadDidFinished
{
    [_waitThreadCondition lock];
    while (_running)
    {
        [_waitThreadCondition wait];
    }
    [_waitThreadCondition unlock];
}

- (void)putMessage:(KTVVPMessage *)message
{
    [_messageQueue putObject:message];
}

- (void)putMessage:(KTVVPMessage *)message delay:(NSTimeInterval)delay
{
    if (delay > 0)
    {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [_messageQueue putObject:message];
        });
    }
    else
    {
         [_messageQueue putObject:message];
    }
}

- (void)messageLoopThread
{
    if (_threadDidStartedCallback)
    {
        _threadDidStartedCallback(self);
    }
    while (YES)
    {
        if (_didClosed)
        {
            while (YES)
            {
                KTVVPMessage * message = [_messageQueue getObjectAsync];
                if (message)
                {
                    [message drop];
                }
                else
                {
                    break;
                }
            }
            [_messageQueue destory];
            break;
        }
        KTVVPMessage * message = [_messageQueue getObjectSync];
        if (!message)
        {
            continue;
        }
        if ([self.delegate respondsToSelector:@selector(messageLoop:processingMessage:)])
        {
            [self.delegate messageLoop:self processingMessage:message];
        }
        else
        {
            [message drop];
        }
    }
    if (_threadDidFiniahedCallback)
    {
        _threadDidFiniahedCallback(self);
    }
    _running = NO;
    [_waitThreadCondition broadcast];
}

@end
