//
//  NSData+DataInput.m
//  LuaTouch
//
//  Created by 廖正凯 on 14-7-14.
//  Copyright (c) 2014年 ___MTX___. All rights reserved.
//

#import "DataInput.h"

@implementation DataInput

-(id) init: (const char *) data length: (int) length {
    if(self = [super init]) {
        _data = data;
        _length = length;
        index = 0;
    }
    return self;
}

-(int) read {
    if(index >= _length) {
        return -1;
    }
    
    return _data[index++] & 0xFF;
}
-(int) readShort {
    return ([self read] << 8) + [self read];
}
-(int) readInt {
    return ([self read] << 24) + ([self read] << 16) + ([self read] << 8) + [self read];
}
-(NSString *) readUTF {
    int size = [self readShort];
    char str[size + 1];
    for(int i = 0; i < size; i++) {
        str[i] = (char) [self read];
    }
    str[size] = 0;
    return [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
}

@end
