//
//  NSData+DataInput.h
//  LuaTouch
//
//  Created by 廖正凯 on 14-7-14.
//  Copyright (c) 2014年 ___MTX___. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DataInput : NSObject {
    const char *_data;
    int _length;
    int index;
}

-(id) init: (const char *) data length: (int) length;

-(int) read;
-(int) readShort;
-(int) readInt;
-(NSString *) readUTF;

@end
