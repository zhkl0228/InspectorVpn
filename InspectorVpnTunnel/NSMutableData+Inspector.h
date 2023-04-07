//
//  NSMutableData+Inspector.h
//  FZInspector
//
//  Created by 廖正凯 on 14-7-1.
//  Copyright (c) 2014年 ___MTX___. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableData (Inspector)

-(void) writeShort: (int) value;
-(void) writeInt: (int) value;
-(void) writeUTF: (NSString *) value;
-(void) writeUTF: (const char *) value length: (int) length;
-(void) writeByte: (int) value;

@end
