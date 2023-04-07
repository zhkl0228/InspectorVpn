//
//  NSMutableData+Inspector.m
//  FZInspector
//
//  Created by 廖正凯 on 14-7-1.
//  Copyright (c) 2014年 ___MTX___. All rights reserved.
//

#import "NSMutableData+Inspector.h"

@implementation NSMutableData (Inspector)

-(void) writeByte: (int) value {
    char c = value & 0xFF;
    [self appendBytes: &c length:1];
}

-(void) writeShort:(int)value {
    [self writeByte: value >> 8];
    [self writeByte: value];
}

-(void) writeInt:(int)value {
    [self writeByte: value >> 24];
    [self writeByte: value >> 16];
    [self writeByte: value >> 8];
    [self writeByte: value];
}

-(void) writeUTF:(NSString *)value {
    [self writeUTF:[value cStringUsingEncoding:NSUTF8StringEncoding] length:(int) [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
}

-(void) writeUTF:(const char *)value length:(int)length {
    [self writeShort:length];
    [self appendBytes:value length:length];
}

@end
